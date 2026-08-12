#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: brightness.sh --device DEVICE {--get|--set-percent PERCENT|--adjust DELTA}
EOF
}

device=""
action=""
value=""
while (($# > 0)); do
    case "$1" in
        --device)
            (($# >= 2)) || { usage; exit 2; }
            device="$2"
            shift 2
            ;;
        --get)
            action="get"
            shift
            ;;
        --set-percent)
            (($# >= 2)) || { usage; exit 2; }
            action="set"
            value="$2"
            shift 2
            ;;
        --adjust)
            (($# >= 2)) || { usage; exit 2; }
            action="adjust"
            value="$2"
            shift 2
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

[[ -n "$device" && -n "$action" ]] || { usage; exit 2; }
[[ "$device" =~ ^[A-Za-z0-9._:-]+$ ]] || {
    echo "Invalid backlight device name" >&2
    exit 2
}

backlight_root="${BRIGHTNESS_SYSFS_ROOT:-/sys/class/backlight}"
device_root="$backlight_root/$device"
for attribute in brightness actual_brightness max_brightness; do
    [[ -r "$device_root/$attribute" ]] || {
        echo "Backlight $device has no readable $attribute attribute" >&2
        exit 1
    }
done

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/brightness"
cache_file="$cache_root/$device.max"
lock_file="$cache_root/$device.lock"
mkdir -p "$cache_root"
exec 9>"$lock_file"
flock 9

driver_max="$(<"$device_root/max_brightness")"
[[ "$driver_max" =~ ^[1-9][0-9]*$ ]] || {
    echo "Backlight $device reported an invalid maximum" >&2
    exit 1
}
device_identity="$(readlink -f -- "$device_root/device" 2>/dev/null || readlink -f -- "$device_root")"

safe_max="$driver_max"
if [[ -r "$cache_file" ]]; then
    read -r cached_driver_max cached_safe_max cached_identity <"$cache_file" || true
    if [[ "${cached_driver_max:-}" == "$driver_max" \
        && "${cached_safe_max:-}" =~ ^[1-9][0-9]*$ \
        && "$cached_safe_max" -le "$driver_max" \
        && "${cached_identity:-}" == "$device_identity" ]]; then
        safe_max="$cached_safe_max"
    fi
fi

raw_to_percent() {
    local raw="$1"
    if ((raw >= safe_max)); then
        printf '100\n'
    else
        printf '%s\n' "$(((raw * 100 + safe_max / 2) / safe_max))"
    fi
}

report() {
    local raw actual percent
    raw="$(<"$device_root/brightness")"
    actual="$(<"$device_root/actual_brightness")"
    percent="$(raw_to_percent "$raw")"
    printf '%s,%s,%s,%s,%s\n' "$device" "$raw" "$actual" "$percent" "$driver_max"
}

write_raw() {
    brightnessctl --device "$device" set "$1" --quiet
}

calibrate_upper_bound() {
    local known_good="$1"
    local low high probe actual

    if ((known_good <= 0)); then
        probe=$((driver_max / 2))
        while ((probe > 0)); do
            write_raw "$probe"
            sleep 0.04
            actual="$(<"$device_root/actual_brightness")"
            if ((actual > 0)); then
                known_good="$probe"
                break
            fi
            probe=$((probe / 2))
        done
    fi
    ((known_good > 0)) || {
        echo "Backlight $device did not expose a usable non-zero level" >&2
        return 1
    }

    low="$known_good"
    high=$((driver_max - 1))
    while ((low < high)); do
        probe=$(((low + high + 1) / 2))
        write_raw "$probe"
        sleep 0.04
        actual="$(<"$device_root/actual_brightness")"
        if ((actual > 0)); then
            low="$probe"
        else
            high=$((probe - 1))
        fi
    done

    safe_max="$low"
    printf '%s %s %s\n' "$driver_max" "$safe_max" "$device_identity" >"$cache_file"
}

set_percent() {
    local percent="$1"
    local previous_raw previous_actual target actual
    [[ "$percent" =~ ^[0-9]+$ ]] || {
        echo "Percent must be an integer from 0 to 100" >&2
        return 2
    }
    ((percent >= 0 && percent <= 100)) || {
        echo "Percent must be an integer from 0 to 100" >&2
        return 2
    }

    previous_raw="$(<"$device_root/brightness")"
    previous_actual="$(<"$device_root/actual_brightness")"
    target=$(((safe_max * percent + 50) / 100))
    write_raw "$target"

    if ((percent == 100 && safe_max == driver_max)); then
        sleep 0.06
        actual="$(<"$device_root/actual_brightness")"
        if ((target > 0 && actual == 0)); then
            if ((previous_actual > 0)); then
                calibrate_upper_bound "$previous_raw"
            else
                calibrate_upper_bound 0
            fi
            write_raw "$safe_max"
        fi
    fi
    report
}

case "$action" in
    get)
        report
        ;;
    set)
        set_percent "$value"
        ;;
    adjust)
        [[ "$value" =~ ^([+-])([0-9]+)%$ ]] || {
            echo "Adjustment must look like +10% or -10%" >&2
            exit 2
        }
        current_percent="$(raw_to_percent "$(<"$device_root/brightness")")"
        delta="${BASH_REMATCH[2]}"
        if [[ "${BASH_REMATCH[1]}" == + ]]; then
            target_percent=$((current_percent + delta))
        else
            target_percent=$((current_percent - delta))
        fi
        ((target_percent < 0)) && target_percent=0
        ((target_percent > 100)) && target_percent=100
        set_percent "$target_percent"
        ;;
esac
