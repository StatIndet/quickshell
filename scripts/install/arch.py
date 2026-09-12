#!/usr/bin/env python3
"""Install the Clavis Arch packages as the desktop user, with explicit optional access."""

from __future__ import annotations

import argparse
import json
import io
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

# Replaced with release-pinned manifest data in the generated standalone installer.
DATA = None
CHOICES = ("keyboard_access", "power_access", "enable_shell", "enable_clipboard", "start_now")
MESSAGES = {
    "keyboard_access": "Allow active local users to read whole keyboard event devices, including raw keystrokes?",
    "power_access": "Grant keytop CAP_PERFMON and CAP_DAC_READ_SEARCH (performance access and broad file-read bypass, beyond RAPL)? Ordinary CPU usage needs neither.",
    "enable_shell": "Enable Clavis Shell with the Niri user service?",
    "enable_clipboard": "Enable clipboard history capture with the Niri user service?",
    "start_now": "Start Clavis Shell and clipboard history capture in the current Niri session now? Active services will not be restarted.",
}


def run(argv, *, check=True, capture=False, cwd=None, timeout=None):
    terminal = None
    if not capture:
        try:
            terminal = open("/dev/tty", "rb", buffering=0)
        except OSError:
            pass  # Explicit non-interactive choices have already been checked.
    try:
        return subprocess.run(
            argv,
            check=check,
            text=True,
            stdin=terminal if terminal is not None else subprocess.DEVNULL,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            cwd=cwd,
            timeout=timeout,
        )
    finally:
        if terminal is not None:
            terminal.close()


def package_name(requirement):
    name = re.split(r"[<>=]", requirement, maxsplit=1)[0]
    if not re.fullmatch(r"[A-Za-z0-9@._+:-]+", name) or name.startswith("-"):
        raise ValueError(f"Invalid package name: {requirement}")
    return name


def srcinfo(text, package):
    common, packages, section = {}, {}, None
    for line in text.splitlines():
        if " = " not in line:
            continue
        key, value = line.strip().split(" = ", 1)
        if key == "pkgname":
            section = packages.setdefault(value, {})
        else:
            target = common if section is None else section
            target.setdefault(key, []).append(value)
    if package not in packages:
        raise ValueError(f"AUR metadata does not contain {package}")
    merged = {**common, **packages[package]}
    dependencies = []
    for key in (
        "depends",
        "depends_x86_64",
        "makedepends",
        "makedepends_x86_64",
        "checkdepends",
        "checkdepends_x86_64",
    ):
        dependencies.extend(merged.get(key, []))
    version = merged["pkgver"][0] + "-" + merged["pkgrel"][0]
    if merged.get("epoch", ["0"])[0] != "0":
        version = merged["epoch"][0] + ":" + version
    return dependencies, version


def open_terminal():
    # BufferedRandom (open with r+) requires seekability, which a tty does not have.
    return io.TextIOWrapper(io.FileIO("/dev/tty", "r+"), encoding="utf-8", write_through=True)


def ask(message, terminal):
    while True:
        terminal.write(message + " [Y/n] ")
        terminal.flush()
        answer = terminal.readline()
        if answer == "":
            raise ValueError("Terminal closed; installation cancelled")
        answer = answer.strip().lower()
        if answer in ("", "y", "yes"):
            return True
        if answer in ("n", "no"):
            return False
        terminal.write("Please answer Y or n.\n")


class Installer:
    def __init__(self, args, data):
        self.args, self.data = args, data
        self.stage = "preflight"
        self.state_path = (
            Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
            / "clavis/installer/choices.json"
        )
        self.previous = {}
        if self.state_path.exists():
            saved = json.loads(self.state_path.read_text())
            if (
                not isinstance(saved, dict)
                or saved.get("schemaVersion") != 1
                or not isinstance(saved.get("choices"), dict)
            ):
                raise ValueError(f"Unknown installer state preserved: {self.state_path}")
            self.previous = saved["choices"]
            if any(not isinstance(value, bool) for value in self.previous.values()):
                raise ValueError(f"Invalid installer choices preserved: {self.state_path}")
        self.choices = {}
        self.aur_bases = {}
        for values in data["packages"].values():
            for entry in values["runtime"] + values["optional"]:
                if "aur" in entry:
                    self.aur_bases[package_name(entry["package"])] = entry["aur"]
        self.aur_bases.update(
            {
                "clavis-shell": "clavis-shell",
                "key-cli-keyboard-access": "key-cli",
                "keytop-privileged-access": "keytop",
            }
        )
        self.checkouts, self.artifacts, self.visiting = {}, {}, set()
        self.pacman_options = ["--noconfirm"] if args.non_interactive else []
        self.conflicts = []

    def satisfied(self, requirement):
        return run(["pacman", "-T", requirement], capture=True, check=False).returncode == 0

    def installed(self, name):
        return run(["pacman", "-Q", name], capture=True, check=False).returncode == 0

    def select_choices(self):
        terminal = None
        if not self.args.non_interactive:
            try:
                terminal = open_terminal()
            except OSError:
                if not self.args.dry_run:
                    raise ValueError(
                        "No terminal: use --non-interactive and all five explicit choices"
                    ) from None
        try:
            for name in CHOICES:
                explicit = getattr(self.args, name)
                package = {
                    "keyboard_access": "key-cli-keyboard-access",
                    "power_access": "keytop-privileged-access",
                }.get(name)
                if explicit is not None:
                    self.choices[name] = explicit == "yes"
                elif self.args.non_interactive:
                    raise ValueError(
                        "Non-interactive installation requires all five explicit choices"
                    )
                elif package and self.installed(package):
                    self.choices[name] = True
                elif name in self.previous:
                    # Preserve manually changed service state on subsequent installations.
                    if name in ("enable_shell", "enable_clipboard"):
                        unit = (
                            "clavis-shell.service"
                            if name == "enable_shell"
                            else "clavis-clipboard.service"
                        )
                        self.choices[name] = (
                            run(
                                ["systemctl", "--user", "is-enabled", unit],
                                capture=True,
                                check=False,
                            ).returncode
                            == 0
                        )
                    else:
                        self.choices[name] = (
                            False if name == "start_now" else bool(self.previous[name])
                        )
                elif self.args.dry_run:
                    self.choices[name] = None
                else:
                    self.choices[name] = ask(MESSAGES[name], terminal)
        finally:
            if terminal:
                terminal.close()

    def requests(self):
        entries = self.data["packages"]["clavis-shell"]
        selected = entries["runtime"] + [e for e in entries["optional"] if e["defaultInstall"]]
        result = []
        for entry in selected:
            if any(self.satisfied(candidate) for candidate in entry.get("satisfiedBy", [])):
                continue
            result.append(entry["package"])
        result.append("clavis-shell")
        if self.choices["keyboard_access"]:
            result.append("key-cli-keyboard-access")
        if self.choices["power_access"]:
            result.append("keytop-privileged-access")
        return list(dict.fromkeys(result))

    def checkout(self, name):
        base = self.aur_bases.get(name)
        if base is None:
            url = "https://aur.archlinux.org/rpc/v5/info?" + urllib.parse.urlencode({"arg[]": name})
            with urllib.request.urlopen(url, timeout=30) as response:
                result = json.load(response)
            matches = [r for r in result.get("results", []) if r["Name"] == name]
            if len(matches) != 1:
                raise ValueError(
                    f"No unambiguous AUR provider for {name}; install a provider and retry"
                )
            base = matches[0]["PackageBase"]
        package_name(base)
        if base not in self.checkouts:
            path = self.work / base
            run(
                [
                    "git",
                    "clone",
                    "--depth",
                    "1",
                    "--",
                    f"https://aur.archlinux.org/{base}.git",
                    str(path),
                ]
            )
            if not (path / ".SRCINFO").is_file():
                raise ValueError(f"AUR package {base} has no .SRCINFO")
            self.checkouts[base] = path
        return base, self.checkouts[base]

    def resolve(self, requirement, refresh=False):
        name = package_name(requirement)
        if self.satisfied(requirement) and not refresh:
            return
        self.stage = f"dependency {requirement}"
        if name in self.visiting:
            raise ValueError(f"Dependency cycle at {name}")
        self.visiting.add(name)
        try:
            official = run(["pacman", "-Si", name], capture=True, check=False)
            if official.returncode == 0:
                run(["sudo", "pacman", "-S", "--needed", *self.pacman_options, name])
            else:
                base, path = self.checkout(name)
                dependencies, remote_version = srcinfo((path / ".SRCINFO").read_text(), name)
                local = run(["pacman", "-Q", name], capture=True, check=False)
                if local.returncode == 0 and self.satisfied(requirement):
                    comparison = run(
                        ["vercmp", local.stdout.strip().split()[-1], remote_version], capture=True
                    )
                    if int(comparison.stdout) >= 0:
                        return
                for dependency in dependencies:
                    self.resolve(dependency)
                if base not in self.artifacts:
                    self.stage = f"AUR build {base}"
                    print(f"Building AUR source package {base} as uid {os.geteuid()}", flush=True)
                    run(["makepkg", "--cleanbuild", "--force", *self.pacman_options], cwd=path)
                    paths = run(
                        ["makepkg", "--packagelist"], capture=True, cwd=path
                    ).stdout.splitlines()
                    packages = {}
                    for item in paths:
                        artifact = Path(item).resolve()
                        if not artifact.is_relative_to(path.resolve()) or not artifact.is_file():
                            raise ValueError(f"Missing or external package artifact: {item}")
                        meta = run(
                            ["pacman", "-Qp", "--print-format", "%n", str(artifact)], capture=True
                        ).stdout.strip()
                        packages[meta] = artifact
                    self.artifacts[base] = packages
                if name not in self.artifacts[base]:
                    raise ValueError(f"AUR build did not produce {name}")
                self.stage = f"package installation {name}"
                # Never install all outputs of a split build: access packages require opt-in.
                run(
                    [
                        "sudo",
                        "pacman",
                        "-U",
                        "--needed",
                        *self.pacman_options,
                        str(self.artifacts[base][name]),
                    ]
                )
            if not self.satisfied(requirement):
                raise ValueError(f"Installed package does not satisfy {requirement}")
        finally:
            self.visiting.remove(name)

    def keyboard_conflict(self):
        for directory in ("/etc", "/run", "/usr/local/lib", "/usr/lib"):
            if directory == "/usr/lib" and self.installed("key-cli-keyboard-access"):
                continue
            path = Path(directory) / "udev/rules.d/71-clavis-keyboard-leds.rules"
            if path.exists() or path.is_symlink():
                self.conflicts.append(
                    f"Existing keyboard authorization rule preserved: {path}. Review it before installing the access package."
                )
                return True
        return False

    def diagnostics(self):
        config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
        paths = [
            config / "quickshell/clavis",
            Path("/usr/local/bin/key"),
            Path("/usr/local/lib/systemd/user/clavis-clipboard.service"),
        ]
        for unit in ("clavis-shell.service", "clavis-clipboard.service"):
            paths.extend([config / "systemd/user" / unit, config / "systemd/user" / (unit + ".d")])
        shadows = [str(p) for p in paths if p.exists() or p.is_symlink()]
        key = shutil.which("key")
        if key and Path(key).resolve() != Path("/usr/bin/key").resolve():
            shadows.append("PATH selects " + key)
        for name in ("CLAVIS_KEY", "QML_IMPORT_PATH"):
            if os.environ.get(name):
                shadows.append(f"{name}={os.environ[name]}")
        for unit in ("clavis-shell.service", "clavis-clipboard.service"):
            info = run(
                [
                    "systemctl",
                    "--user",
                    "show",
                    unit,
                    "--property=FragmentPath,DropInPaths,ExecStart",
                ],
                capture=True,
                check=False,
            )
            print(info.stdout.strip())
            for line in info.stdout.splitlines():
                if line.startswith("DropInPaths=") and line != "DropInPaths=":
                    shadows.append(line)
                if line.startswith("FragmentPath=") and line.split("=", 1)[1].startswith(
                    ("/usr/local/", str(config))
                ):
                    shadows.append(line)
        if shadows:
            self.conflicts.append(
                "Activation skipped; existing installation overrides preserved:\n  "
                + "\n  ".join(dict.fromkeys(shadows))
            )
        doctor = run(["/usr/bin/key", "doctor", "--json"], capture=True, check=False)
        try:
            report = json.loads(doctor.stdout)
            if not isinstance(report, dict) or report.get("schemaVersion") != 1:
                raise ValueError("Unsupported key doctor schemaVersion")
            print("key doctor: " + json.dumps(report, ensure_ascii=False))
        except (ValueError, TypeError):
            self.conflicts.append(
                "Could not validate key doctor output; run /usr/bin/key doctor --json"
            )
        for unit in ("NetworkManager.service", "bluetooth.service", "upower.service"):
            result = run(["systemctl", "is-active", unit], capture=True, check=False)
            print(f"{unit}: {result.stdout.strip() or 'unavailable'} (not changed)")
        for unit in ("pipewire.service", "wireplumber.service", "pipewire-media-session.service"):
            result = run(["systemctl", "--user", "is-active", unit], capture=True, check=False)
            print(f"{unit}: {result.stdout.strip() or 'unavailable'} (not changed)")
        result = run(["gsettings", "list-schemas"], capture=True, check=False)
        schema_available = (
            result.returncode == 0 and "org.gnome.desktop.interface" in result.stdout.splitlines()
        )
        print(
            "Desktop GSettings schema: "
            + ("available" if schema_available else "missing; check gsettings-desktop-schemas")
        )
        probes = [
            (
                "CPU metrics",
                ["/usr/bin/keytop", "value", "snapshot", "--format", "json", "--modules", "cpu"],
            ),
            ("Backlight access", ["brightnessctl", "--class", "backlight", "--list"]),
            ("DDC access", ["ddcutil", "detect", "--brief"]),
        ]
        for label, argv in probes:
            try:
                result = run(argv, capture=True, check=False, timeout=15)
                print(
                    f"{label}: {(result.stdout or result.stderr).strip() or 'no devices reported'}"
                )
                if label == "CPU metrics":
                    report = json.loads(result.stdout)
                    if (
                        result.returncode != 0
                        or not isinstance(report, dict)
                        or report.get("schemaVersion") != 1
                    ):
                        raise ValueError("Unsupported keytop metrics response")
            except (OSError, ValueError, subprocess.TimeoutExpired) as error:
                print(f"{label}: unavailable ({error})")
                if label == "CPU metrics":
                    self.conflicts.append(
                        "Could not validate keytop metrics protocol; run /usr/bin/keytop value cpu --format json"
                    )
        if self.installed("keytop-privileged-access"):
            result = run(["getcap", "-n", "/usr/bin/keytop"], capture=True, check=False)
            if (
                result.returncode != 0
                or result.stdout.strip() != "/usr/bin/keytop cap_dac_read_search,cap_perfmon=ep"
            ):
                self.conflicts.append(
                    "keytop access package is installed but its capabilities need administrator review"
                )
        print(
            "i2c-dev module: "
            + (
                "loaded"
                if Path("/sys/module/i2c_dev").exists()
                else "not loaded; DDC may be unavailable"
            )
        )
        print(
            "NVIDIA NVML library: "
            + (
                "present"
                if Path("/usr/lib/libnvidia-ml.so.1").exists()
                else "absent; optional NVIDIA metrics unavailable"
            )
        )
        print(
            "Brightness/DDC/GPU use distribution access policies; no groups or extra device permissions were added."
        )
        print(
            "RAPL requires supported hardware; ordinary CPU usage does not require the access package."
        )
        return not shadows

    def services(self, safe):
        if not safe:
            return
        run(["systemctl", "--user", "daemon-reload"])
        units = ["clavis-shell.service", "clavis-clipboard.service"]
        for choice, unit in (
            ("enable_shell", "clavis-shell.service"),
            ("enable_clipboard", "clavis-clipboard.service"),
        ):
            if self.choices[choice]:
                run(["systemctl", "--user", "enable", unit])
        if not self.choices["start_now"]:
            return
        if (
            run(
                ["systemctl", "--user", "is-active", "--quiet", "niri.service"], check=False
            ).returncode
            != 0
        ):
            print(
                "Immediate start skipped: niri.service is not active. Enablement choices are retained."
            )
            return
        for unit in units:
            if (
                run(["systemctl", "--user", "is-active", "--quiet", unit], check=False).returncode
                != 0
            ):
                run(["systemctl", "--user", "start", unit])

    def execute(self):
        if os.geteuid() == 0:
            raise ValueError("Run as the desktop user, not sudo/root")
        if platform.machine() != "x86_64" or not Path("/etc/arch-release").is_file():
            raise ValueError("Only Arch-compatible x86_64 systems are supported")
        for tool in ("pacman", "sudo"):
            if not shutil.which(tool):
                raise ValueError(f"Required command: {tool}")
        self.select_choices()
        requested = self.requests()
        print("Packages: " + " ".join(requested), flush=True)
        for choice in CHOICES:
            print(
                f"{choice}: {self.choices[choice] if self.choices[choice] is not None else 'ask [Y/n]'}"
            )
        if self.args.dry_run:
            print("Dry run: no package, permission, state or service changes.")
            return 0
        self.stage = "Arch dependency preparation"
        run(
            [
                "sudo",
                "pacman",
                "-Syu",
                "--needed",
                *self.pacman_options,
                "base-devel",
                "git",
                "python",
                "curl",
            ]
        )
        official = [
            package_name(request)
            for request in requested
            if not self.satisfied(request)
            and run(["pacman", "-Si", package_name(request)], capture=True, check=False).returncode
            == 0
        ]
        if official:
            run(["sudo", "pacman", "-S", "--needed", *self.pacman_options, *official])
        with tempfile.TemporaryDirectory(prefix="clavis-aur-") as directory:
            self.work = Path(directory)
            for requirement in requested:
                name = package_name(requirement)
                if name == "key-cli-keyboard-access" and self.keyboard_conflict():
                    continue
                self.resolve(
                    requirement,
                    refresh=name
                    in (
                        "clavis-shell",
                        "key-cli",
                        "keytop",
                        "key-cli-keyboard-access",
                        "keytop-privileged-access",
                    ),
                )
        self.stage = "post-install diagnostics"
        safe = self.diagnostics()
        self.stage = "user services"
        self.services(safe)
        self.stage = "record installation choices"
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            mode="w", dir=self.state_path.parent, delete=False
        ) as stream:
            json.dump({"schemaVersion": 1, "choices": self.choices}, stream)
            temporary = Path(stream.name)
        temporary.replace(self.state_path)
        print(
            "Packages installed. Removing an access package revokes its persistent policy; reconnect/relogin may be needed for existing keyboard ACLs."
        )
        for conflict in self.conflicts:
            print(conflict, file=sys.stderr)
        return 1 if self.conflicts else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--non-interactive", action="store_true")
    for name in CHOICES:
        parser.add_argument("--" + name.replace("_", "-"), choices=("yes", "no"))
    args = parser.parse_args()
    data = (
        DATA
        if DATA is not None
        else json.loads(
            (Path(__file__).resolve().parents[2] / "packaging/dependencies.json").read_text()
        )
    )
    installer = None
    try:
        installer = Installer(args, data)
        return installer.execute()
    except KeyboardInterrupt:
        print("Installation cancelled.", file=sys.stderr)
        return 130
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        stage = installer.stage if installer else "preflight"
        print(
            f"Installation failed during {stage}: {error}. Existing packages/configuration are retained; fix the cause and retry.",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
