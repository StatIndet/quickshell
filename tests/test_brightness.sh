#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_root/scripts/system/brightness.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
backlight_root="$tmp_dir/sys/class/backlight"
device_root="$backlight_root/panel_backlight"
hardware_root="$tmp_dir/sys/devices/panel"
command_log="$tmp_dir/brightnessctl.log"
mkdir -p "$fake_bin" "$device_root" "$hardware_root"
ln -s "$hardware_root" "$device_root/device"
printf '900\n' >"$device_root/brightness"
printf '900\n' >"$device_root/actual_brightness"
printf '1000\n' >"$device_root/max_brightness"

cat >"$fake_bin/brightnessctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$BRIGHTNESS_TEST_LOG"
device=""
value=""
while (($# > 0)); do
    case "$1" in
        --device)
            device="$2"
            shift 2
            ;;
        set)
            value="$2"
            break
            ;;
        *)
            shift
            ;;
    esac
done

device_root="$BRIGHTNESS_SYSFS_ROOT/$device"
printf '%s\n' "$value" >"$device_root/brightness"
if ((value <= BRIGHTNESS_TEST_SAFE_MAX)); then
    printf '%s\n' "$value" >"$device_root/actual_brightness"
else
    printf '0\n' >"$device_root/actual_brightness"
fi
EOF
chmod +x "$fake_bin/brightnessctl"

run_helper() {
    PATH="$fake_bin:/usr/bin" \
        XDG_CACHE_HOME="$tmp_dir/cache" \
        BRIGHTNESS_SYSFS_ROOT="$backlight_root" \
        BRIGHTNESS_TEST_SAFE_MAX=980 \
        BRIGHTNESS_TEST_LOG="$command_log" \
        "$helper" --device panel_backlight "$@"
}

output="$(run_helper --set-percent 100)"
[[ "$(<"$device_root/brightness")" == 980 ]]
[[ "$(<"$device_root/actual_brightness")" == 980 ]]
[[ "$output" == 'panel_backlight,980,980,100,1000' ]]
grep -Eq '^1000 980 .*/sys/devices/panel$' \
    "$tmp_dir/cache/quickshell/brightness/panel_backlight.max"

output="$(run_helper --get)"
[[ "$output" == 'panel_backlight,980,980,100,1000' ]]

output="$(run_helper --adjust -10%)"
[[ "$(<"$device_root/brightness")" == 882 ]]
[[ "$output" == 'panel_backlight,882,882,90,1000' ]]

printf 'Adaptive brightness boundary test passed\n'
