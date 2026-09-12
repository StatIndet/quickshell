# Date releases and AUR publishing

Each repository builds and tests independently. Release tooling reads `packaging/dependencies.json`,
the version file named there, and `packaging/arch/PKGBUILD.in`. Generated `PKGBUILD` and `.SRCINFO`
are release artifacts and AUR contents; they are not committed back into the source being hashed.
Python 3.10+ and Arch makepkg are needed for release metadata; wheel builds use the declared
Python build dependencies. Native packaging uses CMake/Ninja and ordinary DESTDIR staging.

## First-time GitHub/AUR configuration

Create the AUR maintainer account and register a dedicated SSH public key. In each GitHub
repository's `release` environment configure:

| Setting | Type | Value |
| --- | --- | --- |
| `AUR_SSH_PRIVATE_KEY` | Secret | Private key whose public key is registered with AUR |
| `AUR_KNOWN_HOSTS` | Variable | Verified `aur.archlinux.org` SSH host-key lines |
| `AUR_GIT_NAME` | Variable | Maintainer commit author |
| `AUR_GIT_EMAIL` | Variable | Maintainer commit email |

Verify host keys against Arch's published fingerprints before saving them; do not blindly
trust a keyscan. The workflow uses strict host-key checking. The environment can use GitHub's
normal reviewer/branch protections if desired. The publishing job alone receives write access
and the AUR secret; PR builds use read-only repository access and no publishing secrets.
AUR repositories must be unclaimed or maintained by this account. The package bases are
`key-cli`, `keytop` and `clavis-shell`; the optional packages are split outputs of the first two.

For the initial rollout publish key-cli, then keytop, then Clavis. Clavis records minimum backend
versions in its runtime dependencies. Publishing one project does not build, test or release a
sibling repository. Later updates remain independent; change Clavis's minimum dependency only
when its public backend requirements change. Machine `schemaVersion` is unrelated to the date version.

## Normal release

Open Actions → Release → Run workflow. Select the source commit/branch/tag in `ref`, leave
`retry_tag` empty. The workflow:

1. Allocates the next version using the Asia/Shanghai date: `2026.9.12`, then `.1`, `.2`, etc.
   Invalid dates and versions older than existing date tags are rejected. Releases are serialized.
2. Updates the one version file in a temporary release commit and creates a local date tag.
   It does not commit version bumps to the default branch.
3. Runs repository checks and builds the actual source archive with makepkg in a disposable
   Arch container. Runtime-only sibling dependencies are not build prerequisites.
4. Transfers the tested commit as a Git bundle to the publishing job, pushes its tag, creates
   a draft, uploads all assets, and publishes it without marking it latest.
5. Pushes generated PKGBUILD, `.SRCINFO` and any install metadata to AUR; only after success
   does it mark the GitHub release latest.

Source archives use a whitelist of tracked roots, normalized ownership/modes and commit timestamps.
They exclude local profiles, caches and uncommitted files. `RELEASE.json` records the exact release
commit and build timestamp. Clavis's complete source asset also includes checksum-pinned weather
resources and their license; GitHub's automatic tag archive is not a substitute for that asset.
Public assets are source, package metadata, checksums, optional installer, and the key-cli wheel.
Pacman binaries are validated in CI but are not a supported binary installation channel.

Builds/test logs are attached to Actions. QML advisory warning counts and retained logs remain
visible; advisory output is not described as zero warnings. Hardware and graphical-session
acceptance requires a separate Arch/Niri test session, without using the maintainer's live desktop.
Validate weather animation/fallback, symbol fonts, map rendering, system metrics, keyboard state,
recording, clipboard and opt-in service activation before announcing the first release.

## Failed publishing and package-only changes

If AUR synchronization fails after the public assets exist, run the workflow again with
`retry_tag=v2026.9.12`. It downloads and checks the existing assets, updates AUR, and marks that
same release latest. It does not rebuild, allocate a new version, or overwrite assets. A retry
refuses to downgrade a newer AUR package. Incomplete drafts/tag-push failures require inspecting
the failed publishing job; the AUR-only retry deliberately does not claim to repair partial assets.

For a packaging-only fix, download the existing release source asset and render updated metadata
with `--pkgrel 2` (or the next revision), then review/push it to AUR. Keep the source version/hash
unchanged and do not replace published assets. The `retry_tag` path replays the original metadata,
so use it only for a failed synchronization, not for a packaging edit.

## Local preparation without deployment

```bash
python3 scripts/release.py version
python3 scripts/release.py source --working-tree --output .packaging/local
python3 scripts/release.py render --output .packaging/local \
  --archive .packaging/local/PACKAGE-VERSION.tar.gz
```

Replace `PACKAGE-VERSION` with the name/version printed by the tooling. `--working-tree` explicitly
includes non-ignored working changes under the whitelist for local verification; production uses
only the tested commit. The resulting source asset is already in makepkg's source directory, so
its release URL does not need to exist for local builds. Run makepkg there as an ordinary user;
do not use `--install` or `--syncdeps` when only validating artifacts on your development host.
`python3 scripts/check-package.py PATH_TO_EACH_PACKAGE` checks actual package resources and metadata.
Clavis can also render the standalone installer with `scripts/release.py installer --output PATH`.

`scripts/ci/arch.sh` is intentionally restricted to the disposable Arch container; it installs
build dependencies inside that container and must not be used as a host setup script. Local
checks continue to use the repository's documented development check entry point.
