"""Installer contracts: prompts, package choices, integrity and service boundaries."""

import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("arch_installer", ROOT / "scripts/install/arch.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
DATA = json.loads((ROOT / "packaging/dependencies.json").read_text())


def args(**changes):
    values = {"dry_run": False, "non_interactive": True, **{key: "no" for key in installer.CHOICES}}
    return argparse.Namespace(**{**values, **changes})


class Terminal:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.output = ""

    def write(self, value):
        self.output += value

    def flush(self):
        pass

    def readline(self):
        return next(self.responses, "")

    def close(self):
        pass


class InstallerContracts(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.environment = {
            **os.environ,
            "HOME": str(self.root),
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
        }
        self.patch_environment = patch.dict(os.environ, self.environment)
        self.patch_environment.start()
        self.addCleanup(self.patch_environment.stop)

    def test_prompt_defaults_rejection_and_eof(self):
        self.assertTrue(installer.ask("Grant access?", Terminal(["\n"])))
        self.assertFalse(installer.ask("Grant access?", Terminal(["n\n"])))
        self.assertTrue(installer.ask("Grant access?", Terminal(["invalid\n", "yes\n"])))
        with self.assertRaises(ValueError):
            installer.ask("Grant access?", Terminal([]))

    def test_noninteractive_requires_every_explicit_choice(self):
        operation = installer.Installer(args(power_access=None), DATA)
        with patch.object(installer, "run") as commands, self.assertRaises(ValueError):
            operation.select_choices()
        commands.assert_not_called()

    def test_previous_denials_are_retained_without_prompts(self):
        state = self.root / "state/clavis/installer/choices.json"
        state.parent.mkdir(parents=True)
        state.write_text(
            json.dumps({"schemaVersion": 1, "choices": dict.fromkeys(installer.CHOICES, False)})
        )
        operation = installer.Installer(
            args(non_interactive=False, **dict.fromkeys(installer.CHOICES)), DATA
        )
        with (
            patch.object(installer, "open_terminal", return_value=Terminal([])),
            patch.object(operation, "installed", return_value=False),
            patch.object(installer, "run", return_value=subprocess.CompletedProcess([], 1, "", "")),
        ):
            operation.select_choices()
        self.assertFalse(any(operation.choices.values()))

    def test_split_build_installs_only_selected_package(self):
        operation = installer.Installer(args(), DATA)
        path = self.root / "aur"
        path.mkdir()
        (path / ".SRCINFO").write_text(
            "pkgbase = key-cli\npkgver = 2026.9.12\npkgrel = 1\npkgname = key-cli\ndepends = python\npkgname = key-cli-keyboard-access\ndepends = systemd\n"
        )
        outputs = [
            path / f"{name}-2026.9.12-1-any.pkg.tar.zst"
            for name in ("key-cli", "key-cli-keyboard-access")
        ]
        installed, transactions = {"python"}, []

        def command(argv, **options):
            stdout, status = "", 0
            if argv[:2] == ["pacman", "-T"]:
                status = 0 if installer.package_name(argv[2]) in installed else 127
            elif argv[:2] in (["pacman", "-Si"], ["pacman", "-Q"]):
                status = 1
            elif argv[:2] == ["makepkg", "--packagelist"]:
                stdout = "\n".join(map(str, outputs)) + "\n"
            elif argv[0] == "makepkg":
                for output in outputs:
                    output.write_bytes(b"package fixture")
            elif argv[:2] == ["pacman", "-Qp"]:
                stdout = Path(argv[-1]).name.split("-2026")[0]
            elif argv[:3] == ["sudo", "pacman", "-U"]:
                name = Path(argv[-1]).name.split("-2026")[0]
                transactions.append(name)
                installed.add(name)
            else:
                self.fail(f"Unexpected command: {argv}")
            return subprocess.CompletedProcess(argv, status, stdout, "")

        with (
            patch.object(installer, "run", side_effect=command),
            patch.object(operation, "checkout", return_value=("key-cli", path)),
        ):
            operation.resolve("key-cli")
        self.assertEqual(transactions, ["key-cli"])
        self.assertNotIn("key-cli-keyboard-access", installed)

    def release_fixture(self, base="key-cli", version="2026.9.12"):
        repository = DATA["releaseSources"][base]["repository"]
        tag = "v" + version
        url = f"https://github.com/{repository}/releases/download/{tag}/"
        archive = f"{base}-{version}.tar.gz"
        files = {archive: b"release source", "PKGBUILD": b"# fixture"}
        digest = hashlib.sha256(files[archive]).hexdigest()
        metadata = (
            f"pkgbase = {base}\npkgver = {version}\npkgrel = 1\n"
            f"source = {archive}::{url}{archive}\nsha256sums = {digest}\n"
        )
        for package in DATA["releaseSources"][base]["packages"]:
            metadata += f"pkgname = {package}\n"
        if base == "keytop":
            metadata += "install = keytop-privileged-access.install\n"
            files["keytop-privileged-access.install"] = b"# install fixture"
            files["keytop-privileged-access.hook"] = b"# hook fixture"
        files[".SRCINFO"] = metadata.encode()
        sums = "".join(
            f"{hashlib.sha256(content).hexdigest()}  {name}\n" for name, content in files.items()
        )
        responses = {url + name: value for name, value in files.items()}
        responses[url + "SHA256SUMS"] = sums.encode()
        payload = json.dumps({"tag_name": tag, "draft": False, "prerelease": False}).encode()
        for endpoint in ("latest", "tags/" + tag):
            responses[f"https://api.github.com/repos/{repository}/releases/{endpoint}"] = payload
        return responses, url

    def test_release_downloads_verified_inputs_and_reuses_split_build_source(self):
        operation = installer.Installer(args(), DATA)
        operation.work = self.root
        responses, url = self.release_fixture("keytop")
        calls = []

        def download(address, **kwargs):
            calls.append(address)
            return io.BytesIO(responses[address])

        with patch.object(installer.urllib.request, "urlopen", side_effect=download):
            base, path = operation.checkout("keytop")
            self.assertEqual(operation.checkout("keytop-privileged-access"), (base, path))
        self.assertEqual(len(calls), len(set(calls)))
        self.assertEqual(
            (path / "keytop-privileged-access.install").read_bytes(), b"# install fixture"
        )
        self.assertEqual((path / "keytop-2026.9.12.tar.gz").read_bytes(), b"release source")
        self.assertIn(url + "keytop-privileged-access.hook", calls)

    def test_release_failures_stop_before_build_and_never_fall_back_to_aur(self):
        for failure in (
            "download",
            "checksum",
            "missing",
            "unsafe",
            "version",
            "prerelease",
            "install",
        ):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory(dir=self.root) as work:
                operation = installer.Installer(args(), DATA)
                operation.work = Path(work)
                responses, url = self.release_fixture()
                if failure == "checksum":
                    responses[url + "PKGBUILD"] += b"corrupt"
                elif failure == "missing":
                    responses[url + "SHA256SUMS"] = b""
                elif failure == "unsafe":
                    responses[url + "SHA256SUMS"] += ("0" * 64 + "  ../escape\n").encode()
                elif failure in ("version", "install"):
                    metadata = responses[url + ".SRCINFO"]
                    changed = (
                        metadata.replace(b"pkgver = 2026.9.12", b"pkgver = 2026.9.13")
                        if failure == "version"
                        else metadata + b"install = missing.install\n"
                    )
                    responses[url + ".SRCINFO"] = changed
                    responses[url + "SHA256SUMS"] = responses[url + "SHA256SUMS"].replace(
                        hashlib.sha256(metadata).hexdigest().encode(),
                        hashlib.sha256(changed).hexdigest().encode(),
                    )
                elif failure == "prerelease":
                    api = "https://api.github.com/repos/StatIndet/key-cli/releases/latest"
                    responses[api] = json.dumps(
                        {"tag_name": "v2026.9.12", "prerelease": True}
                    ).encode()

                def download(address, **kwargs):
                    self.assertNotIn("aur.archlinux.org", address)
                    if failure == "download" or address not in responses:
                        raise OSError("download failed")
                    return io.BytesIO(responses[address])

                with (
                    patch.object(operation, "satisfied", return_value=False),
                    patch.object(installer.urllib.request, "urlopen", side_effect=download),
                    patch.object(installer, "run") as command,
                ):
                    with self.assertRaises((ValueError, OSError)):
                        operation.resolve("key-cli")
                    command.assert_not_called()
                self.assertNotIn("key-cli", operation.checkouts)

    def test_release_minimum_version_checked_before_build(self):
        operation = installer.Installer(args(), DATA)
        operation.work = self.root
        responses, _ = self.release_fixture()
        with (
            patch.object(operation, "satisfied", return_value=False),
            patch.object(
                installer.urllib.request,
                "urlopen",
                side_effect=lambda url, **kw: io.BytesIO(responses[url]),
            ),
            patch.object(
                installer, "run", return_value=subprocess.CompletedProcess([], 0, "-1", "")
            ) as command,
        ):
            with self.assertRaisesRegex(ValueError, "does not satisfy"):
                operation.resolve("key-cli>=2026.9.13")
            command.assert_called_once_with(["vercmp", "2026.9.12-1", "2026.9.13"], capture=True)

    def test_clavis_release_is_pinned_and_third_party_still_uses_aur(self):
        operation = installer.Installer(args(), {**DATA, "installerRelease": "v2026.9.12"})
        operation.work = self.root
        responses, _ = self.release_fixture("clavis-shell")
        del responses["https://api.github.com/repos/StatIndet/quickshell/releases/latest"]
        with patch.object(
            installer.urllib.request,
            "urlopen",
            side_effect=lambda url, **kw: io.BytesIO(responses[url]),
        ):
            operation.checkout("clavis-shell")
        aur_path = self.root / "libcava"
        aur_path.mkdir()
        (aur_path / ".SRCINFO").write_text("pkgbase = libcava\n")
        with patch.object(installer, "run") as command:
            self.assertEqual(operation.checkout("libcava"), ("libcava", aur_path))
        self.assertIn("https://aur.archlinux.org/libcava.git", command.call_args.args[0])

    def test_generated_installer_embeds_its_release_version(self):
        target = self.root / "install-arch.sh"
        subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/release.py"),
                "installer",
                "--output",
                str(target),
            ],
            check=True,
        )
        result = subprocess.run(
            [
                "bash",
                str(target),
                "--dry-run",
                "--non-interactive",
                *["--" + choice.replace("_", "-") + "=no" for choice in installer.CHOICES],
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertIn("Clavis v" + (ROOT / "VERSION").read_text().strip(), result.stdout)

    def test_services_never_restart_and_require_niri(self):
        operation = installer.Installer(args(), DATA)
        operation.choices = {
            **dict.fromkeys(installer.CHOICES, False),
            "enable_shell": True,
            "start_now": True,
        }
        calls = []

        def command(argv, **options):
            calls.append(argv)
            return subprocess.CompletedProcess(argv, 0, "", "")

        with patch.object(installer, "run", side_effect=command):
            operation.services(True)
        self.assertFalse(any("restart" in call or "start" in call for call in calls))
        self.assertIn(["systemctl", "--user", "enable", "clavis-shell.service"], calls)
        calls.clear()
        with patch.object(installer, "run", side_effect=command):
            operation.services(False)
        self.assertEqual(calls, [])

    def test_immediate_start_is_independent_of_autostart(self):
        operation = installer.Installer(args(), DATA)
        operation.choices = {**dict.fromkeys(installer.CHOICES, False), "start_now": True}
        calls = []

        def command(argv, **options):
            calls.append(argv)
            inactive = "is-active" in argv and argv[-1] != "niri.service"
            return subprocess.CompletedProcess(argv, int(inactive), "", "")

        with patch.object(installer, "run", side_effect=command):
            operation.services(True)
        self.assertFalse(any("enable" in call for call in calls))
        for unit in ("clavis-shell.service", "clavis-clipboard.service"):
            self.assertIn(["systemctl", "--user", "start", unit], calls)
        calls.clear()
        with patch.object(
            installer, "run", return_value=subprocess.CompletedProcess([], 1, "", "")
        ) as commands:
            operation.services(True)
        self.assertFalse(any("start" in call.args[0] for call in commands.call_args_list))

    def test_diagnostics_preserve_overrides_and_report_invalid_protocols(self):
        existing = self.root / "config/quickshell/clavis/shell.qml"
        existing.parent.mkdir(parents=True)
        existing.write_text("user configuration")
        operation = installer.Installer(args(), DATA)

        def command(argv, **options):
            if argv[0] == "ddcutil":
                raise subprocess.TimeoutExpired(argv, options["timeout"])
            self.assertIn(
                argv[0],
                ("systemctl", "/usr/bin/key", "/usr/bin/keytop", "brightnessctl", "gsettings"),
            )
            output = "[]" if argv[0] in ("/usr/bin/key", "/usr/bin/keytop") else ""
            return subprocess.CompletedProcess(argv, 0, output, "")

        with (
            patch.object(installer, "run", side_effect=command),
            patch.object(operation, "installed", return_value=False),
            patch("sys.stdout", new_callable=io.StringIO) as output,
        ):
            self.assertFalse(operation.diagnostics())
        self.assertEqual(existing.read_text(), "user configuration")
        self.assertTrue(any("overrides preserved" in error for error in operation.conflicts))
        self.assertTrue(any("key doctor" in error for error in operation.conflicts))
        self.assertTrue(any("keytop metrics" in error for error in operation.conflicts))
        self.assertIn("DDC access: unavailable", output.getvalue())
        self.assertIn("Desktop GSettings schema: missing", output.getvalue())

    def test_dry_run_and_no_terminal_do_not_mutate(self):
        commands = self.root / "bin"
        commands.mkdir()
        log = self.root / "sudo-called"
        sudo = commands / "sudo"
        sudo.write_text(f"#!/bin/sh\ntouch '{log}'\nexit 91\n")
        sudo.chmod(0o755)
        environment = {**self.environment, "PATH": str(commands) + ":" + os.environ["PATH"]}
        flags = ["--" + key.replace("_", "-") + "=no" for key in installer.CHOICES]
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/install/arch.py"),
                "--dry-run",
                "--non-interactive",
                *flags,
            ],
            capture_output=True,
            text=True,
            env=environment,
            start_new_session=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Dry run", result.stdout)
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/install/arch.py")],
            capture_output=True,
            text=True,
            env=environment,
            start_new_session=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No terminal", result.stderr)
        self.assertFalse(log.exists())
        self.assertFalse((self.root / "state").exists())

    def test_pipe_input_uses_controlling_terminal(self):
        import fcntl
        import pty
        import select
        import termios
        import time

        commands = self.root / "bin"
        commands.mkdir()
        for name, body in (
            ("pacman", "exit 1"),
            ("sudo", 'read -r response; printf "transaction-answer:%s\\n" "$response"; exit 91'),
        ):
            target = commands / name
            target.write_text("#!/bin/sh\n" + body + "\n")
            target.chmod(0o755)
        master, slave = pty.openpty()

        def controlling_terminal():
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

        environment = {**self.environment, "PATH": str(commands) + ":" + os.environ["PATH"]}
        process = subprocess.Popen(
            [sys.executable, str(ROOT / "scripts/install/arch.py")],
            stdin=subprocess.PIPE,
            stdout=slave,
            stderr=slave,
            env=environment,
            preexec_fn=controlling_terminal,
        )
        os.close(slave)
        process.stdin.close()  # Just like the exhausted stdin of curl | bash.
        os.write(master, b"\nn\nn\nn\nn\n")
        output = b""
        answered_transaction = False
        deadline = time.monotonic() + 15
        try:
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.2)[0]:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError:
                        break
                    if not chunk:
                        break
                    output += chunk
                    if b"start_now: False" in output and not answered_transaction:
                        # The Python prompt reader must not consume pacman's later answer.
                        os.write(master, b"n\n")
                        answered_transaction = True
                elif process.poll() is not None:
                    break
            if process.poll() is None:
                process.kill()
            process.wait(timeout=5)
        finally:
            os.close(master)
        self.assertIn(b"keyboard_access: True", output)
        self.assertIn(b"power_access: False", output)
        self.assertIn(b"Arch dependency preparation", output)
        self.assertIn(b"transaction-answer:n", output)
        self.assertFalse((self.root / "state").exists())

    def test_bootstrap_checks_integrity_and_download_errors(self):
        commands = self.root / "bin"
        commands.mkdir()
        payload = b"#!/bin/bash\nprintf 'verified installer executed\\n'\n"
        (self.root / "install-arch.sh").write_bytes(payload)
        (self.root / "SHA256SUMS").write_text(
            hashlib.sha256(payload).hexdigest() + "  install-arch.sh\n"
        )
        curl = commands / "curl"
        curl.write_text("""#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
root=Path(os.environ['BOOTSTRAP_FIXTURE'])
url=next(x for x in sys.argv if x.startswith('https://'))
if os.environ.get('DOWNLOAD_FAIL')=='1':sys.exit(22)
if url.endswith('/releases/latest'):print(json.dumps({'tag_name':'v2026.9.12'}))
else:Path(sys.argv[sys.argv.index('--output')+1]).write_bytes((root/url.rsplit('/',1)[1]).read_bytes())
""")
        curl.chmod(0o755)
        environment = {
            **self.environment,
            "PATH": str(commands) + ":" + os.environ["PATH"],
            "BOOTSTRAP_FIXTURE": str(self.root),
        }
        result = subprocess.run(
            ["bash", str(ROOT / "install.sh")], capture_output=True, text=True, env=environment
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("verified installer executed", result.stdout)
        (self.root / "install-arch.sh").write_bytes(b"corrupt")
        result = subprocess.run(
            ["bash", str(ROOT / "install.sh")], capture_output=True, text=True, env=environment
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch", result.stderr)
        result = subprocess.run(
            ["bash", str(ROOT / "install.sh")],
            capture_output=True,
            text=True,
            env={**environment, "DOWNLOAD_FAIL": "1"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("executed", result.stdout)


if __name__ == "__main__":
    unittest.main()
