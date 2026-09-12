#!/usr/bin/env python3
"""Inspect actual pacman artifacts and their declared runtime contracts."""

from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(archive, path):
    return subprocess.check_output(["bsdtar", "-xOf", str(archive), path])


def metadata(payload):
    result = {}
    for line in payload.decode().splitlines():
        if " = " in line:
            key, value = line.split(" = ", 1)
            result.setdefault(key, []).append(value)
    return result


def main():
    manifest = json.loads((ROOT / "packaging/dependencies.json").read_text())
    expected_version = (ROOT / manifest["versionFile"]).read_text().strip()
    seen = set()
    for argument in sys.argv[1:]:
        path = Path(argument)
        info = metadata(read(path, ".PKGINFO"))
        name = info["pkgname"][0]
        if name.endswith("-debug"):
            continue
        if name not in manifest["packages"]:
            raise ValueError(f"Unexpected package: {name}")
        seen.add(name)
        if info["pkgver"][0].rsplit("-", 1)[0] != expected_version:
            raise ValueError(f"Wrong package version: {name}")
        expected = {d["package"] for d in manifest["packages"][name]["runtime"]}
        if set(info.get("depend", [])) != expected:
            raise ValueError(f"Wrong runtime dependencies: {name}: {info.get('depend')}")
        files = set(subprocess.check_output(["bsdtar", "-tf", str(path)], text=True).splitlines())
        if any(f.startswith(("home/", "usr/local/", "usr/etc/")) for f in files):
            raise ValueError("Package writes outside the distribution layout")
        if name == "clavis-shell":
            prefix = "etc/xdg/quickshell/clavis/"
            required = {
                prefix + "shell.qml",
                prefix + "AppShell.qml",
                prefix + "licenses/Meteocons-MIT.txt",
                "usr/lib/systemd/user/clavis-shell.service",
            }
            for module in (
                "Weather",
                "WeatherMap",
                "Cava",
                "Lyrics",
                "Runtime",
                "I18n",
                "Keyboard",
                "Niri",
                "Gamma",
                "Media",
                "DesktopCards",
            ):
                required.add("usr/lib/qt6/qml/Clavis/" + module + "/qmldir")
            for style in ("fill", "flat", "line", "monochrome"):
                required.add(
                    prefix + "assets/icons/weather/meteocons/svg/" + style + "/not-available.svg"
                )
            required.add(prefix + "assets/icons/weather/meteocons/lottie/fill/not-available.json")
            if any(
                f.startswith(prefix + "scripts/" + group)
                for f in files
                for group in ("dev/", "ci/", "install/", "release.py")
            ):
                raise ValueError("Development or release tools leaked into the installed shell")
            if not any(
                f.startswith(prefix + "assets/fonts/google-sans-flex/") and f.endswith(".ttf")
                for f in files
            ):
                raise ValueError("Missing bundled expressive font")
        elif name == "key-cli":
            required = {
                "usr/bin/key",
                "usr/lib/systemd/user/clavis-clipboard.service",
                "usr/share/fish/vendor_completions.d/key.fish",
            }
            versions = [f for f in files if f.endswith("/key_cli/VERSION")]
            if len(versions) != 1 or read(path, versions[0]).decode().strip() != expected_version:
                raise ValueError("Missing or inconsistent Python version resource")
            if any("udev/" in f for f in files):
                raise ValueError("Base CLI package unexpectedly grants keyboard access")
        elif name == "key-cli-keyboard-access":
            required = {"usr/lib/udev/rules.d/71-clavis-keyboard-leds.rules"}
            if "usr/bin/key" in files:
                raise ValueError("Access package must not contain the CLI")
        elif name == "keytop":
            required = {
                "usr/bin/keytop",
                "usr/share/keytop/defaults/config.conf",
                "usr/share/keytop/defaults/matugen.conf",
            }
            if any("libalpm/hooks/" in f for f in files):
                raise ValueError("Base keytop package unexpectedly grants capabilities")
        else:
            required = {
                "usr/lib/keytop/privileged-access",
                "usr/share/libalpm/hooks/keytop-privileged-access.hook",
                ".INSTALL",
            }
            if "usr/bin/keytop" in files:
                raise ValueError("Access package must not contain the binary")
        if not required <= files:
            raise ValueError(f"Missing package resources: {sorted(required - files)}")
        if name != "keytop-privileged-access" and ".INSTALL" in files:
            raise ValueError(f"Unexpected post-install actions in {name}")
        print(f"Package verified: {name} {info['pkgver'][0]}")
    if seen != set(manifest["packages"]):
        raise ValueError(f"Missing package outputs: {set(manifest['packages']) - seen}")


if __name__ == "__main__":
    main()
