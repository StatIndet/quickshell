#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

prefix="$tmp_dir/prefix"
cache_home="$tmp_dir/cache"
output="$(
    XDG_CACHE_HOME="$cache_home" \
        "$repo_root/install.sh" --dry-run --prefix "$prefix"
)"

grep -Fq "Prefix: $prefix" <<<"$output"
grep -Fq "Build directory: $cache_home/clavis-shell/" <<<"$output"
grep -Fq "/build" <<<"$output"
grep -Fq "QML modules: $prefix/lib/qt6/qml" <<<"$output"
grep -Fq "Configure Clavis core" <<<"$output"
grep -Fq "Build Clavis core" <<<"$output"
grep -Fq "Test Clavis core" <<<"$output"
grep -Fq "Install key and QML modules" <<<"$output"
[[ ! -e "$prefix" ]]

fake_bin="$tmp_dir/bin"
build_dir="$tmp_dir/build"
command_log="$tmp_dir/commands.log"
mkdir -p "$fake_bin"

cat >"$fake_bin/cmake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'cmake %s\n' "$*" >>"$CLAVIS_TEST_COMMAND_LOG"

case "${1:-}" in
    -S)
        build_dir=""
        while (($# > 0)); do
            if [[ "$1" == -B ]]; then
                build_dir="$2"
                break
            fi
            shift
        done
        mkdir -p \
            "$build_dir/bin" \
            "$build_dir/Clavis/Sysmon" \
            "$build_dir/M3Shapes"
        printf '#!/usr/bin/env bash\n' >"$build_dir/bin/key"
        chmod +x "$build_dir/bin/key"
        printf 'plugin\n' >"$build_dir/Clavis/Sysmon/libClavisSysmon.so"
        printf 'plugin\n' >"$build_dir/M3Shapes/libM3Shapes.so"
        ;;
    --install)
        build_dir="$2"
        shift 2
        [[ "${1:-}" == --prefix ]]
        prefix="$2"
        mkdir -p "$prefix/bin"
        cp "$build_dir/bin/key" "$prefix/bin/key"
        ;;
    --build)
        ;;
    *)
        echo "unexpected cmake invocation: $*" >&2
        exit 2
        ;;
esac
EOF

cat >"$fake_bin/ctest" <<'EOF'
#!/usr/bin/env bash
printf 'ctest %s\n' "$*" >>"$CLAVIS_TEST_COMMAND_LOG"
EOF

cat >"$fake_bin/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'npm %s\n' "$*" >>"$CLAVIS_TEST_COMMAND_LOG"

package="${2:-}"
destination=""
while (($# > 0)); do
    if [[ "$1" == --pack-destination ]]; then
        destination="$2"
        break
    fi
    shift
done

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
case "$package" in
    @meteocons/lottie@0.1.0)
        package_name=@meteocons/lottie
        extension=json
        archive=meteocons-lottie-0.1.0.tgz
        ;;
    @meteocons/svg@0.1.0)
        package_name=@meteocons/svg
        extension=svg
        archive=meteocons-svg-0.1.0.tgz
        ;;
    *)
        echo "unexpected npm package: $package" >&2
        exit 2
        ;;
esac

slugs=(clear-day clear-night not-available cloudy)
for style in fill flat line monochrome; do
    mkdir -p "$fixture/package/$style"
    for slug in "${slugs[@]}"; do
        printf '{}\n' >"$fixture/package/$style/$slug.$extension"
    done
done
cat >"$fixture/package/manifest.json" <<'JSON'
{
  "styles": ["fill", "flat", "line", "monochrome"],
  "categories": [
    {
      "icons": [
        {"slug": "clear-day"},
        {"slug": "clear-night"},
        {"slug": "not-available"},
        {"slug": "cloudy"}
      ]
    }
  ]
}
JSON
printf '{"name":"%s","version":"0.1.0"}\n' "$package_name" \
    >"$fixture/package/package.json"
mkdir -p "$destination"
tar -czf "$destination/$archive" -C "$fixture" package
printf '%s\n' "$archive"
EOF

chmod +x "$fake_bin/cmake" "$fake_bin/ctest" "$fake_bin/npm"

PATH="$fake_bin:/usr/bin" \
    CLAVIS_BUILD_DIR="$build_dir" \
    CLAVIS_TEST_COMMAND_LOG="$command_log" \
    "$repo_root/install.sh" --prefix "$prefix" >/dev/null

[[ -x "$prefix/bin/key" ]]
[[ -f "$prefix/lib/qt6/qml/Clavis/Sysmon/libClavisSysmon.so" ]]
[[ -f "$prefix/lib/qt6/qml/M3Shapes/libM3Shapes.so" ]]
grep -Fq -- "-DCLAVIS_INSTALL_RAPL_CAPABILITY=OFF" "$command_log"
grep -Fq "ctest --test-dir $build_dir --output-on-failure" "$command_log"

meteocons_dir="$tmp_dir/weather-icons/lottie"
meteocons_svg_dir="$tmp_dir/weather-icons/svg"
mkdir -p "$meteocons_dir/line"
printf '{}\n' >"$meteocons_dir/line/clear-day.json"
PATH="$fake_bin:/usr/bin" \
    CLAVIS_BUILD_DIR="$build_dir" \
    CLAVIS_METEOCONS_DIR="$meteocons_dir" \
    CLAVIS_METEOCONS_SVG_DIR="$meteocons_svg_dir" \
    CLAVIS_TEST_COMMAND_LOG="$command_log" \
    "$repo_root/install.sh" --prefix "$prefix" >/dev/null

[[ -f "$meteocons_dir/line/clear-day.json" ]]
[[ -f "$meteocons_dir/fill/not-available.json" ]]
[[ -f "$meteocons_dir/fill/cloudy.json" ]]
[[ -f "$meteocons_svg_dir/fill/clear-day.svg" ]]
[[ -f "$meteocons_svg_dir/monochrome/not-available.svg" ]]
grep -Fq "npm pack @meteocons/lottie@0.1.0 --silent --pack-destination" "$command_log"
grep -Fq "npm pack @meteocons/svg@0.1.0 --silent --pack-destination" "$command_log"

printf '{"name":"@meteocons/lottie","version":"9.9.9"}\n' \
    >"$meteocons_dir/package.json"
lottie_downloads_before="$(grep -Fc 'npm pack @meteocons/lottie@0.1.0 ' "$command_log")"
PATH="$fake_bin:/usr/bin" \
    CLAVIS_BUILD_DIR="$build_dir" \
    CLAVIS_METEOCONS_DIR="$meteocons_dir" \
    CLAVIS_METEOCONS_SVG_DIR="$meteocons_svg_dir" \
    CLAVIS_TEST_COMMAND_LOG="$command_log" \
    "$repo_root/install.sh" --prefix "$prefix" >/dev/null
lottie_downloads_after="$(grep -Fc 'npm pack @meteocons/lottie@0.1.0 ' "$command_log")"
((lottie_downloads_after == lottie_downloads_before + 1))
grep -Fq '"version":"0.1.0"' "$meteocons_dir/package.json"

rm "$meteocons_dir/fill/cloudy.json"
printf 'stale\n' >"$build_dir/Clavis/stale-plugin.so"
printf 'stale\n' >"$prefix/lib/qt6/qml/Clavis/stale-installed.so"
lottie_downloads_before="$lottie_downloads_after"
PATH="$fake_bin:/usr/bin" \
    CLAVIS_BUILD_DIR="$build_dir" \
    CLAVIS_METEOCONS_DIR="$meteocons_dir" \
    CLAVIS_METEOCONS_SVG_DIR="$meteocons_svg_dir" \
    CLAVIS_TEST_COMMAND_LOG="$command_log" \
    "$repo_root/install.sh" --prefix "$prefix" >/dev/null
[[ -f "$meteocons_dir/fill/cloudy.json" ]]
[[ ! -e "$prefix/lib/qt6/qml/Clavis/stale-plugin.so" ]]
[[ ! -e "$prefix/lib/qt6/qml/Clavis/stale-installed.so" ]]
lottie_downloads_after="$(grep -Fc 'npm pack @meteocons/lottie@0.1.0 ' "$command_log")"
((lottie_downloads_after == lottie_downloads_before + 1))

echo "QuickShell installer tests passed"
