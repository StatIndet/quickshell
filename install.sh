#!/usr/bin/env bash
# Build and install Clavis native helpers into a user-owned prefix.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
prefix="${HOME}/.local"
dry_run=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--prefix PATH] [--dry-run]

Build, test, and install the Clavis key CLI and QML modules without root.

Options:
  --prefix PATH  Installation prefix (default: ~/.local)
  --dry-run      Print the installation plan without changing files
  --help         Show this help
EOF
}

while (($# > 0)); do
    case "$1" in
        --prefix)
            (($# >= 2)) || {
                echo "install.sh: --prefix requires a path" >&2
                exit 2
            }
            prefix="$2"
            shift
            ;;
        --dry-run)
            dry_run=true
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo "install.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [[ "$prefix" != /* ]]; then
    echo "install.sh: --prefix must be an absolute path" >&2
    exit 2
fi

source_revision=source
if command -v git >/dev/null 2>&1; then
    source_revision="$(git -C "$script_dir" rev-parse --verify HEAD 2>/dev/null || printf 'source\n')"
fi
build_dir="${CLAVIS_BUILD_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/clavis-shell/$source_revision/build}"
qml_dir="$prefix/lib/qt6/qml"
build_jobs="${CLAVIS_BUILD_JOBS:-2}"
meteocons_lottie_dir="${CLAVIS_METEOCONS_DIR:-$script_dir/assets/icons/weather/meteocons/lottie}"
meteocons_svg_dir="${CLAVIS_METEOCONS_SVG_DIR:-$script_dir/assets/icons/weather/meteocons/svg}"

if [[ ! "$build_jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo "install.sh: CLAVIS_BUILD_JOBS must be a positive integer" >&2
    exit 2
fi

echo "Clavis QuickShell installation"
echo "Source: $script_dir"
echo "Prefix: $prefix"
echo "Build directory: $build_dir"
echo "QML modules: $qml_dir"
echo
echo "1. Configure Clavis core"
echo "2. Build Clavis core"
echo "3. Test Clavis core"
echo "4. Install key and QML modules"

if [[ "$dry_run" == true ]]; then
    echo
    echo "Dry run: no files changed"
    exit 0
fi

meteocons_complete() {
    local destination="$1"
    local extension="$2"
    local expected_name="$3"
    local expected_version="$4"

    [[ -f "$destination/manifest.json" && -f "$destination/package.json" ]] || return 1
    command -v node >/dev/null 2>&1 || return 1
    node - "$destination" "$extension" "$expected_name" "$expected_version" <<'NODE'
const fs = require("fs");
const path = require("path");

const [destination, extension, expectedName, expectedVersion] = process.argv.slice(2);
let manifest, packageJson;
try {
  manifest = JSON.parse(fs.readFileSync(path.join(destination, "manifest.json"), "utf8"));
  packageJson = JSON.parse(fs.readFileSync(path.join(destination, "package.json"), "utf8"));
} catch {
  process.exit(1);
}
if (packageJson.name !== expectedName || packageJson.version !== expectedVersion) {
  process.exit(1);
}

const styles = Array.isArray(manifest.styles) ? manifest.styles : [];
const slugs = new Set();
for (const category of Array.isArray(manifest.categories) ? manifest.categories : []) {
  for (const icon of Array.isArray(category.icons) ? category.icons : []) {
    if (typeof icon.slug === "string" && icon.slug.length > 0) slugs.add(icon.slug);
  }
}
if (styles.length === 0 || slugs.size === 0) process.exit(1);

for (const style of styles) {
  for (const slug of slugs) {
    if (!fs.existsSync(path.join(destination, style, `${slug}.${extension}`))) {
      process.exit(1);
    }
  }
}
NODE
}

download_root=""
cleanup_download() {
    if [[ -n "$download_root" && -d "$download_root" ]]; then
        rm -rf "$download_root"
    fi
}
trap cleanup_download EXIT

install_meteocons_pack() {
    local package="$1"
    local destination="$2"
    local extension="$3"
    local package_name="${package%@*}"
    local package_version="${package##*@}"
    local package_dir archive

    if meteocons_complete \
        "$destination" "$extension" "$package_name" "$package_version"; then
        return
    fi

    if ! command -v npm >/dev/null 2>&1; then
        echo "install.sh: npm is required to install Meteocons weather icons" >&2
        exit 1
    fi

    if [[ -z "$download_root" ]]; then
        download_root="$(mktemp -d)"
    fi
    package_dir="$download_root/${package##*/}"
    install -d "$package_dir"
    npm pack "$package" --silent --pack-destination "$package_dir" >/dev/null
    archive="$(find "$package_dir" -maxdepth 1 -type f -name '*.tgz' -print -quit)"
    if [[ -z "$archive" ]]; then
        echo "install.sh: npm did not produce a $package archive" >&2
        exit 1
    fi

    install -d "$destination"
    tar -xzf "$archive" --strip-components=1 -C "$destination"
    if ! meteocons_complete \
        "$destination" "$extension" "$package_name" "$package_version"; then
        echo "install.sh: $package archive is incomplete" >&2
        exit 1
    fi
}

install_meteocons_pack @meteocons/lottie@0.1.0 "$meteocons_lottie_dir" json
install_meteocons_pack @meteocons/svg@0.1.0 "$meteocons_svg_dir" svg

for module in Clavis M3Shapes; do
    if [[ -e "$build_dir/$module" ]]; then
        rm -rf "${build_dir:?}/$module"
    fi
done

cmake \
    -S "$script_dir/core" \
    -B "$build_dir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCLAVIS_INSTALL_RAPL_CAPABILITY=OFF
cmake --build "$build_dir" --parallel "$build_jobs"
env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen \
    ctest --test-dir "$build_dir" --output-on-failure
cmake --install "$build_dir" --prefix "$prefix"

for module in Clavis M3Shapes; do
    source_dir="$build_dir/$module"
    if [[ ! -d "$source_dir" ]]; then
        echo "install.sh: built QML module is missing: $source_dir" >&2
        exit 1
    fi
done

install -d "$qml_dir"
for module in Clavis M3Shapes; do
    if [[ -e "$qml_dir/$module" ]]; then
        rm -rf "${qml_dir:?}/$module"
    fi
    cp -a "$build_dir/$module" "$qml_dir/"
done

echo
echo "Installed key: $prefix/bin/key"
echo "Installed QML modules: $qml_dir/{Clavis,M3Shapes}"
