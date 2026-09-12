"""Date versions and shipped source/metadata are public release contracts."""

from datetime import date
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_tool", ROOT / "scripts/release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseContracts(unittest.TestCase):
    def test_date_versions_and_same_day_retries(self):
        self.assertEqual(release.next_version([], date(2026, 9, 12)), "2026.9.12")
        tags = ["v0.1.0", "v2026.9.12", "v2026.9.12.1", "unrelated"]
        self.assertEqual(release.next_version(tags, date(2026, 9, 12)), "2026.9.12.2")
        self.assertEqual(release.next_version(tags, date(2026, 10, 1)), "2026.10.1")
        self.assertEqual(release.next_version(["v2026.12.31"], date(2027, 1, 1)), "2027.1.1")
        with self.assertRaises(ValueError):
            release.next_version(["v2026.9.13"], date(2026, 9, 12))
        for invalid in ("0.1.0", "2026.09.12", "2026.2.30", "2026.9.12.0", "2026.9.12.65536"):
            with self.assertRaises(ValueError):
                release.validate_version(invalid)

    @unittest.skipUnless(shutil.which("vercmp"), "pacman version comparator unavailable")
    def test_arch_version_order(self):
        versions = ["0.2.0", "2026.9.12", "2026.9.12.1", "2026.9.13", "2026.10.1", "2027.1.1"]
        for first, second in zip(versions, versions[1:]):
            result = subprocess.check_output(["vercmp", first, second], text=True)
            self.assertLess(int(result), 0)

    def test_source_archive_is_reproducible_and_excludes_private_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repository"
            root.mkdir()
            (root / "packaging").mkdir()
            config = {
                "name": "example",
                "versionFile": "VERSION",
                "sourceRoots": ["VERSION", "public"],
                "build": [],
                "check": [],
                "ci": [],
                "packages": {},
            }
            (root / "packaging/dependencies.json").write_text(json.dumps(config))
            (root / "VERSION").write_text("2026.9.12\n")
            (root / "public").mkdir()
            (root / "public/example.txt").write_text("release content\n")
            (root / ".env").write_text("PRIVATE=not-for-release\n")
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(root),
                    "-c",
                    "user.name=Fixture",
                    "-c",
                    "user.email=fixture@example.invalid",
                    "commit",
                    "-qm",
                    "fixture",
                ],
                check=True,
            )
            (root / "public/uncommitted.txt").write_text("not committed")
            first = release.source_archive(Path(directory) / "first", root=root)
            second = release.source_archive(Path(directory) / "second", root=root)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with tarfile.open(first) as archive:
                names = set(archive.getnames())
                self.assertIn("example-2026.9.12/public/example.txt", names)
                self.assertNotIn("example-2026.9.12/.env", names)
                self.assertNotIn("example-2026.9.12/public/uncommitted.txt", names)
                metadata = json.load(archive.extractfile("example-2026.9.12/RELEASE.json"))
                self.assertEqual(metadata["version"], "2026.9.12")
                self.assertFalse(metadata["workingTree"])
                self.assertTrue(all(m.uid == 0 and m.gid == 0 for m in archive.getmembers()))
            (first.parent / "PKGBUILD").write_text("package fixture")
            (first.parent / ".SRCINFO").write_text(
                "pkgbase = example\npkgver = 2026.9.12\npkgrel = 1\n"
                + f"sha256sums = {release.sha256(first)}\n"
            )
            release.checksums(first.parent)
            release.verify_assets(first.parent, "v2026.9.12", metadata["commit"], root=root)
            if shutil.which("makepkg"):
                templates = root / "packaging/arch"
                templates.mkdir()
                (templates / "PKGBUILD.in").write_text(
                    "pkgname=example\npkgver=@PKGVER@\npkgrel=@PKGREL@\narch=(any)\n"
                    "source=(example-$pkgver.tar.gz)\nsha256sums=('@SHA256@')\n"
                    "package() { :; }\n"
                )
                (root / "VERSION").write_text("2026.10.1\n")
                release.render(first.parent, first, pkgrel=2, root=root)
                fields = dict(
                    line.strip().split(" = ", 1)
                    for line in (first.parent / ".SRCINFO").read_text().splitlines()
                    if " = " in line
                )
                self.assertEqual(fields["pkgver"], "2026.9.12")
                self.assertEqual(fields["pkgrel"], "2")
                release.checksums(first.parent)
                release.verify_assets(first.parent, "v2026.9.12", metadata["commit"], root=root)
            with self.assertRaises(ValueError):
                release.verify_assets(first.parent, "v2026.9.12", "wrong-commit", root=root)
            (first.parent / "PKGBUILD").write_text("corrupted")
            with self.assertRaises(ValueError):
                release.verify_assets(first.parent, "v2026.9.12", metadata["commit"], root=root)

    def test_resource_checksum_failure_does_not_publish_cache(self):
        from unittest.mock import patch
        import io

        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(release.urllib.request, "urlopen", return_value=io.BytesIO(b"corrupt")),
        ):
            with self.assertRaises(ValueError):
                release.fetch_resource(
                    {
                        "url": "https://example.invalid/resource",
                        "name": "fixture",
                        "sha256": "0" * 64,
                    },
                    Path(directory),
                )
            self.assertEqual(list(Path(directory).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
