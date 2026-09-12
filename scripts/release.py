#!/usr/bin/env python3
"""Build reproducible release sources and Arch metadata from this repository only."""

from __future__ import annotations

import argparse
from email.parser import BytesParser
from datetime import date, datetime, timezone
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
from zoneinfo import ZoneInfo
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def manifest(root=ROOT):
    data = json.loads((root / "packaging/dependencies.json").read_text())
    for group in [
        data["build"],
        data["check"],
        data["ci"],
        *[values[kind] for values in data["packages"].values() for kind in ("runtime", "optional")],
    ]:
        for entry in group:
            if not re.fullmatch(
                r"[a-zA-Z0-9@._+:-]+(?:[<>=]+[a-zA-Z0-9._+:-]+)?", entry["package"]
            ):
                raise ValueError(f"Invalid dependency: {entry['package']}")
    return data


def validate_version(value):
    if not re.fullmatch(r"[1-9][0-9]{3}\.[1-9][0-9]?\.[1-9][0-9]?(?:\.[1-9][0-9]*)?", value):
        raise ValueError(f"Invalid date version: {value}")
    parts = list(map(int, value.split(".")))
    date(*parts[:3])
    if len(parts) == 4 and parts[3] > 65535:
        raise ValueError("Same-day revision exceeds the CMake version limit")
    return value


def next_version(tags, day):
    base = f"{day.year}.{day.month}.{day.day}"
    versions = []
    for tag in tags:
        try:
            versions.append(validate_version(tag.removeprefix("v")))
        except ValueError:
            continue
    if any(tuple(map(int, v.split(".")[:3])) > (day.year, day.month, day.day) for v in versions):
        raise ValueError("A future release exists; refusing a version downgrade")
    same_day = [v for v in versions if v == base or v.startswith(base + ".")]
    if not same_day:
        return base
    return validate_version(
        base
        + "."
        + str(max(int(v.split(".")[3]) if v.count(".") == 3 else 0 for v in same_day) + 1)
    )


def git(*args, root=ROOT):
    return subprocess.check_output(["git", "-C", str(root), *args])


def version(root=ROOT):
    return validate_version((root / manifest(root)["versionFile"]).read_text().strip())


def sha256(path):
    with path.open("rb") as stream:
        digest = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
        return digest.hexdigest()


def fetch_resource(resource, cache):
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / (resource["sha256"] + ".tgz")
    if not target.exists() or sha256(target) != resource["sha256"]:
        request = urllib.request.Request(resource["url"], headers={"User-Agent": "Clavis-release"})
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = response.read()
        if hashlib.sha256(payload).hexdigest() != resource["sha256"]:
            raise ValueError(f"Resource checksum mismatch: {resource['name']}")
        target.write_bytes(payload)
    return target


def bundle_resources(root, cache, data):
    for resource in data.get("resources", []):
        destination = root / resource["destination"]
        destination.mkdir(parents=True, exist_ok=True)
        with tarfile.open(fetch_resource(resource, cache), "r:gz") as archive:
            for member in archive.getmembers():
                name = PurePosixPath(member.name)
                if (
                    name.is_absolute()
                    or ".." in name.parts
                    or not name.parts
                    or name.parts[0] != "package"
                ):
                    raise ValueError("Invalid resource archive path")
                relative = PurePosixPath(*name.parts[1:])
                if not relative.parts or relative.parts[0] not in [
                    *resource["directories"],
                    "manifest.json",
                    "package.json",
                ]:
                    continue
                if member.isdir():
                    continue
                if not member.isfile():
                    raise ValueError("Resource links and special files are not supported")
                target = destination / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.extractfile(member).read())
                target.chmod(0o644)


def verify_resources(root, data):
    slugs = [
        "clear-day",
        "clear-night",
        "mostly-clear-day",
        "mostly-clear-night",
        "partly-cloudy-day",
        "partly-cloudy-night",
        "cloudy",
        "fog-day",
        "fog-night",
        "drizzle",
        "overcast-day-rain",
        "overcast-night-rain",
        "overcast-day-sleet",
        "overcast-night-sleet",
        "overcast-day-snow",
        "overcast-night-snow",
        "partly-cloudy-day-rain",
        "partly-cloudy-night-rain",
        "partly-cloudy-day-snow",
        "partly-cloudy-night-snow",
        "thunderstorms-day",
        "thunderstorms-night",
        "thunderstorms-day-hail",
        "thunderstorms-night-hail",
        "not-available",
    ]
    for resource in data.get("resources", []):
        extension = ".json" if resource["name"].endswith("/lottie") else ".svg"
        for style in resource["directories"]:
            for slug in slugs:
                path = root / resource["destination"] / style / (slug + extension)
                if not path.is_file() or not path.stat().st_size:
                    raise ValueError(f"Missing weather resource: {path}")
                if extension == ".json":
                    json.loads(path.read_text())
    if data.get("resources") and not (root / "licenses/Meteocons-MIT.txt").is_file():
        raise ValueError("Missing Meteocons license")


def allowed(path, roots):
    return any(path == entry or path.startswith(entry + "/") for entry in roots)


def source_archive(output, working_tree=False, root=ROOT):
    data = manifest(root)
    release_version = version(root)
    output.mkdir(parents=True, exist_ok=True)
    commit = git("rev-parse", "HEAD", root=root).decode().strip()
    epoch = int(git("show", "-s", "--format=%ct", "HEAD", root=root))
    with tempfile.TemporaryDirectory(prefix="clavis-source-") as temporary:
        tree = Path(temporary) / f"{data['name']}-{release_version}"
        tree.mkdir()
        if working_tree:
            names = (
                git("ls-files", "-z", "--cached", "--others", "--exclude-standard", root=root)
                .decode()
                .split("\0")
            )
            for name in sorted(set(names)):
                path = root / name
                if not name or not allowed(name, data["sourceRoots"]) or not path.exists():
                    continue
                if path.is_symlink():
                    raise ValueError(f"Refusing source symlink: {name}")
                if path.is_file():
                    target = tree / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target)
        else:
            with tarfile.open(
                fileobj=io.BytesIO(git("archive", "--format=tar", "HEAD", root=root))
            ) as archive:
                for member in archive.getmembers():
                    if not allowed(member.name, data["sourceRoots"]) or member.isdir():
                        continue
                    if not member.isfile():
                        raise ValueError(f"Refusing source link or special file: {member.name}")
                    target = tree / member.name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.extractfile(member).read())
                    target.chmod(member.mode)
        if (tree / data["versionFile"]).read_text().strip() != release_version:
            raise ValueError(
                "Version differs from HEAD; commit it or use --working-tree for a local build"
            )
        bundle_resources(tree, output / "resource-cache", data)
        verify_resources(tree, data)
        metadata = {
            "version": release_version,
            "commit": commit,
            "buildTime": datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "workingTree": working_tree,
        }
        (tree / "RELEASE.json").write_text(json.dumps(metadata, indent=2) + "\n")
        target = output / (tree.name + ".tar.gz")
        with (
            target.open("wb") as raw,
            gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed,
            tarfile.open(fileobj=compressed, mode="w") as archive,
        ):
            for path in [tree, *sorted(tree.rglob("*"))]:
                info = archive.gettarinfo(str(path), str(path.relative_to(tree.parent)))
                info.uid = info.gid = 0
                info.uname = info.gname = "root"
                info.mtime = epoch
                info.mode = 0o755 if path.is_dir() or path.stat().st_mode & 0o111 else 0o644
                if path.is_file():
                    with path.open("rb") as stream:
                        archive.addfile(info, stream)
                else:
                    archive.addfile(info)
        return target


def array(entries, optional=False):
    values = [(e["package"] + ": " + e["purpose"]) if optional else e["package"] for e in entries]
    return "(" + " ".join(shlex.quote(v) for v in dict.fromkeys(values)) + ")"


def render(output, archive, pkgrel=1, root=ROOT):
    data = manifest(root)
    with tarfile.open(archive) as source:
        prefix = archive.name.removesuffix(".tar.gz")
        release_version = validate_version(
            source.extractfile(prefix + "/" + data["versionFile"]).read().decode().strip()
        )
    if archive.name != f"{data['name']}-{release_version}.tar.gz":
        raise ValueError("Archive name does not match the release version")
    text = (root / "packaging/arch/PKGBUILD.in").read_text()
    replacements = {
        "PKGVER": release_version,
        "PKGREL": str(pkgrel),
        "SHA256": sha256(archive),
        "MAKEDEPENDS": array(data["build"]),
        "CHECKDEPENDS": array(data["check"]),
    }
    for package, values in data["packages"].items():
        key = package.upper().replace("-", "_")
        replacements[key + "_DEPENDS"] = array(values["runtime"])
        replacements[key + "_OPTDEPENDS"] = array(values["optional"], optional=True)
    for key, value in replacements.items():
        text = text.replace("@" + key + "@", value)
    if re.search(r"@[A-Z_0-9]+@", text):
        raise ValueError("Unresolved PKGBUILD template field")
    output.mkdir(parents=True, exist_ok=True)
    (output / "PKGBUILD").write_text(text)
    for path in (root / "packaging/arch").iterdir():
        if path.suffix in (".install", ".hook"):
            shutil.copyfile(path, output / path.name)
    srcinfo = subprocess.check_output(["makepkg", "--printsrcinfo"], cwd=output)
    (output / ".SRCINFO").write_bytes(srcinfo)


def checksums(directory):
    names = sorted(p for p in directory.iterdir() if p.is_file() and p.name != "SHA256SUMS")
    (directory / "SHA256SUMS").write_text("".join(f"{sha256(p)}  {p.name}\n" for p in names))


def verify_assets(directory, tag, commit, root=ROOT):
    data = manifest(root)
    release_version = validate_version(tag.removeprefix("v"))
    records = {}
    for line in (directory / "SHA256SUMS").read_text().splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.+-]+)", line)
        if not match or match[2] in (".", "..", "SHA256SUMS") or match[2] in records:
            raise ValueError("Invalid or duplicate release checksum entry")
        records[match[2]] = match[1]
    source_name = f"{data['name']}-{release_version}.tar.gz"
    required = {"PKGBUILD", ".SRCINFO", source_name}
    if data["name"] == "clavis-shell":
        required.add("install-arch.sh")
    wheel_name = f"key_cli-{release_version}-py3-none-any.whl"
    if data["name"] == "key-cli":
        required.add(wheel_name)
    if not required <= records.keys():
        raise ValueError("Release is missing required assets")
    for name, digest in records.items():
        path = directory / name
        if path.is_symlink() or sha256(path) != digest:
            raise ValueError(f"Release asset checksum mismatch: {name}")
    fields = {}
    for line in (directory / ".SRCINFO").read_text().splitlines():
        if " = " in line:
            key, value = line.strip().split(" = ", 1)
            fields.setdefault(key, value)
    if fields.get("pkgver") != release_version or fields.get("pkgbase") != data["name"]:
        raise ValueError("Release tag and AUR metadata disagree")
    if fields.get("sha256sums") != records[source_name]:
        raise ValueError("AUR source checksum does not match the release archive")
    if data["name"] == "key-cli":
        with zipfile.ZipFile(directory / wheel_name) as wheel:
            metadata_names = [
                name for name in wheel.namelist() if name.endswith(".dist-info/METADATA")
            ]
            if len(metadata_names) != 1:
                raise ValueError("Ambiguous wheel metadata")
            wheel_metadata = BytesParser().parsebytes(wheel.read(metadata_names[0]))
            if (
                wheel_metadata["Version"] != release_version
                or wheel.read("key_cli/VERSION").decode().strip() != release_version
            ):
                raise ValueError("Release wheel version mismatch")
    with tarfile.open(directory / source_name) as source:
        metadata = json.load(source.extractfile(f"{data['name']}-{release_version}/RELEASE.json"))
        if (
            metadata.get("version") != release_version
            or metadata.get("commit") != commit
            or metadata.get("workingTree") is not False
        ):
            raise ValueError("Release archive does not match the tested tag commit")
        bundled = (
            source.extractfile(f"{data['name']}-{release_version}/" + data["versionFile"])
            .read()
            .decode()
            .strip()
        )
        if bundled != release_version:
            raise ValueError("Release source version mismatch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("version")
    verify = commands.add_parser("verify-assets")
    verify.add_argument("directory", type=Path)
    verify.add_argument("--tag", required=True)
    verify.add_argument("--commit", required=True)
    next_parser = commands.add_parser("next-version")
    next_parser.add_argument("--date", type=date.fromisoformat)
    stamp = commands.add_parser("stamp")
    stamp.add_argument("version")
    source = commands.add_parser("source")
    source.add_argument("--output", type=Path, required=True)
    source.add_argument("--working-tree", action="store_true")
    package = commands.add_parser("render")
    package.add_argument("--output", type=Path, required=True)
    package.add_argument("--archive", type=Path, required=True)
    package.add_argument("--pkgrel", type=int, default=1)
    bundle = commands.add_parser("bundle-resources")
    bundle.add_argument("--directory", type=Path, default=ROOT)
    bundle.add_argument("--cache", type=Path, required=True)
    commands.add_parser("verify-resources")
    installer = commands.add_parser("installer")
    installer.add_argument("--output", type=Path, required=True)
    sums = commands.add_parser("checksums")
    sums.add_argument("directory", type=Path)
    dependencies = commands.add_parser("dependencies")
    dependencies.add_argument("--ci", action="store_true")
    args = parser.parse_args()
    data = manifest()
    if args.command == "version":
        print(version())
    elif args.command == "verify-assets":
        verify_assets(args.directory, args.tag, args.commit)
        print("Release assets match their checksums, date tag and source commit")
    elif args.command == "next-version":
        tags = git("tag", "--list").decode().splitlines()
        print(next_version(tags, args.date or datetime.now(ZoneInfo("Asia/Shanghai")).date()))
    elif args.command == "stamp":
        (ROOT / data["versionFile"]).write_text(validate_version(args.version) + "\n")
    elif args.command == "source":
        print(source_archive(args.output.resolve(), args.working_tree))
    elif args.command == "render":
        if args.pkgrel < 1:
            raise ValueError("pkgrel must be positive")
        render(args.output.resolve(), args.archive.resolve(), args.pkgrel)
    elif args.command == "bundle-resources":
        bundle_resources(args.directory, args.cache, data)
        verify_resources(args.directory, data)
    elif args.command == "installer":
        code = (
            (ROOT / "scripts/install/arch.py")
            .read_text()
            .replace("DATA = None", "DATA = " + repr(data), 1)
        )
        launcher = (ROOT / "scripts/install/launcher.sh.in").read_text()
        defaults = [
            e["package"]
            for v in data["packages"].values()
            for e in v["runtime"] + v["optional"]
            if e["defaultInstall"]
        ]
        launcher = launcher.replace("@DEFAULT_PACKAGES@", " ".join(defaults)).replace(
            "@INSTALLER_PYTHON@", code
        )
        args.output.write_text(launcher)
        args.output.chmod(0o755)
    elif args.command == "verify-resources":
        verify_resources(ROOT, data)
    elif args.command == "checksums":
        checksums(args.directory)
    elif args.command == "dependencies":
        values = data["build"] + data["check"] + (data["ci"] if args.ci else [])
        for entry in {e["package"]: e for e in values}.values():
            print(f"{entry.get('aur', '-')}\t{entry['package']}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"release: {error}") from error
