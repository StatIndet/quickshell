# Date releases on GitHub

Each repository builds and tests independently. Release tooling reads `packaging/dependencies.json`,
the version file named there, and `packaging/arch/PKGBUILD.in`. Generated `PKGBUILD` and `.SRCINFO`
are release artifacts suitable for manual Arch packaging; they are not committed back into the source being hashed.
Python 3.10+ and Arch makepkg are needed for release metadata; wheel builds use the declared
Python build dependencies. Native packaging uses CMake/Ninja and ordinary DESTDIR staging.

## GitHub configuration

The publishing job uses the automatic `GITHUB_TOKEN` with `contents: write`. No AUR account,
SSH key, AUR secrets or AUR variables are required. Existing AUR settings are unused.
The `release` environment can retain normal GitHub reviewer/branch protections if configured.
PR and build jobs keep read-only repository access and receive no publishing credentials.

The workflows publish GitHub Releases and Arch packaging files. They do not upload packages
to AUR or require this project's packages to be registered there. Package bases remain
`key-cli`, `keytop` and `clavis-shell`; the optional access packages remain split outputs.
Clavis's build still downloads external AUR build dependencies such as `libcava` and
`qt6-m3shapes-git` anonymously, so availability of those sources can still affect its build.

For the initial rollout publish key-cli, then keytop, then Clavis. Clavis records minimum backend
versions in its runtime dependencies. Publishing one project does not build, test or release a
sibling repository. Later updates remain independent; change Clavis's minimum dependency only
when its public backend requirements change. Machine `schemaVersion` is unrelated to the date version.

## Normal release

Open Actions → Release → Run workflow on the branch containing the updated workflow.
Select the source commit/branch/tag in `ref`. The workflow:

1. Allocates the next version using the Asia/Shanghai date: `2026.9.12`, then `.1`, `.2`, etc.
   Invalid dates and versions older than existing date tags are rejected. Releases are serialized.
2. Updates the one version file in a temporary release commit and creates a local date tag.
   It does not commit version bumps to the default branch.
3. Runs repository checks and builds the actual source archive with makepkg in a disposable
   Arch container. Runtime-only sibling dependencies are not build prerequisites.
4. Transfers the tested commit as a Git bundle to the publishing job and verifies the assets
   against their checksums, version and source commit before pushing the tag.
5. Creates a draft and uploads all assets, then publishes the GitHub release and marks it
   latest. AUR registration and package availability do not gate this publishing step.

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

Inspect a failed publishing job before retrying: a pushed tag or partially uploaded draft may
already exist. The workflow does not overwrite public assets. Starting a new release allocates
the next date version; it does not resume an older draft. The old AUR-only `retry_tag` input has
been removed.

If an earlier workflow already published a complete GitHub release and then failed at AUR
synchronization, verify its assets against its tag before marking that existing release latest
in GitHub. No AUR synchronization is needed. If no release was published, dispatch the updated
workflow normally.

For a packaging-only fix, download the existing release source asset and render updated metadata
with `--pkgrel 2` (or the next revision), then review it for local builds or later manual AUR
publication. Keep the source version/hash unchanged and do not replace published assets.

The Clavis one-command installer still resolves project packages from AUR. A GitHub release
alone does not make those packages available to it. Until they are published to AUR, use the
release PKGBUILD/source assets to build and install the projects manually, starting with key-cli
and keytop. Source development and installation entry points remain available in each repository.

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
