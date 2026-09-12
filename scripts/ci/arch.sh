#!/usr/bin/env bash
# Runs only inside an ephemeral Arch CI container, never on the developer host.
set -euo pipefail
[[ ${CLAVIS_CI_CONTAINER:-} == 1 && -f /.dockerenv && $(id -u) == 0 ]] || {
    printf 'arch.sh requires the disposable Arch CI container.\n' >&2
    exit 1
}
root=$(git rev-parse --show-toplevel)
cd "$root"
if ! id builder >/dev/null 2>&1; then useradd --create-home builder; fi
printf 'builder ALL=(root) NOPASSWD: /usr/bin/pacman\n' > /etc/sudoers.d/clavis-builder
chmod 440 /etc/sudoers.d/clavis-builder
chown -R builder:builder "$root"

dependency_text=$(python3 scripts/release.py dependencies --ci)
mapfile -t dependency_rows <<< "$dependency_text"
official=() aur=()
for row in "${dependency_rows[@]}"; do
    IFS=$'\t' read -r source package <<< "$row"
    if [[ $source == - ]]; then official+=("${package%%[<>=]*}"); else aur+=("$source"); fi
done
pacman -Syu --needed --noconfirm "${official[@]}"
mkdir -p .packaging/ci-deps
chown builder:builder .packaging .packaging/ci-deps
for base in "${aur[@]}"; do
    [[ ! -d .packaging/ci-deps/$base ]] || continue
    runuser -u builder -- git clone --depth 1 -- "https://aur.archlinux.org/$base.git" ".packaging/ci-deps/$base"
    (
        cd ".packaging/ci-deps/$base"
        runuser -u builder -- makepkg --syncdeps --noconfirm
        mapfile -t packages < <(runuser -u builder -- makepkg --packagelist)
        pacman -U --noconfirm --needed "${packages[@]}"
    )
done
actionlint
name=$(python3 -c 'import json; print(json.load(open("packaging/dependencies.json"))["name"])')
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=
export XDG_RUNTIME_DIR=/tmp/clavis-ci-runtime
install -d -m 700 -o builder -g builder "$XDG_RUNTIME_DIR"
runuser -u builder -- python3 scripts/release.py bundle-resources --cache .packaging/resource-cache
case $name in
    clavis-shell) runuser -u builder -- scripts/dev/check.sh --full ;;
    key-cli) runuser -u builder -- scripts/check.sh --build ;;
    keytop) runuser -u builder -- make check ;;
    *) exit 2 ;;
esac
# This archive is built and tested independently of the checkout and sibling repos.
runuser -u builder -- python3 scripts/release.py source --output .packaging/release
archive="$root/.packaging/release/$name-$(python3 scripts/release.py version).tar.gz"
runuser -u builder -- python3 scripts/release.py render --archive "$archive" --output .packaging/release
(
    cd .packaging/release
    runuser -u builder -- makepkg --cleanbuild --force --noconfirm
    mapfile -t packages < <(runuser -u builder -- makepkg --packagelist)
    runuser -u builder -- python3 "$root/scripts/check-package.py" "${packages[@]}"
)
if [[ $name == key-cli ]]; then
    runuser -u builder -- python3 -m build --wheel --no-isolation --outdir .packaging/release
elif [[ $name == clavis-shell ]]; then
    runuser -u builder -- python3 scripts/release.py installer --output .packaging/release/install-arch.sh
fi
# Pacman binaries are CI diagnostics; releases distribute source, metadata and wheels.
find .packaging/release -maxdepth 1 -name '*.pkg.tar.*' -delete
runuser -u builder -- python3 scripts/release.py checksums .packaging/release
