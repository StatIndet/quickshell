#!/usr/bin/env bash

set -euo pipefail

mode=${1:-}
schema=org.gnome.desktop.interface
key=color-scheme

case "${mode}" in
    dark | light) ;;
    *)
        printf 'usage: %s <dark|light>\n' "$0" >&2
        exit 2
        ;;
esac

if ! command -v gsettings >/dev/null 2>&1; then
    printf 'gsettings is required to synchronize the system color scheme\n' >&2
    exit 127
fi

if [[ $(gsettings writable "${schema}" "${key}") != true ]]; then
    printf '%s %s is not writable\n' "${schema}" "${key}" >&2
    exit 1
fi

value=prefer-dark
if [[ ${mode} == light ]]; then
    range=$(gsettings range "${schema}" "${key}")
    if [[ ${range} == *"'prefer-light'"* ]]; then
        value=prefer-light
    else
        value=default
    fi
fi

gsettings set "${schema}" "${key}" "${value}"
