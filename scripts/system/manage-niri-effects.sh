#!/bin/sh

set -eu

mode=${1:-}
main_config=${2:-}
snippet_path=${3:-}
xray_value=${4:-true}
niri_command=${5:-niri}
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$mode" != "write" ] && [ "$mode" != "configure" ]; then
    echo "usage: manage-niri-effects.sh <write|configure> <main-config> <snippet> <xray> [niri]" >&2
    exit 2
fi

if [ "$xray_value" != "true" ] && [ "$xray_value" != "false" ]; then
    echo "invalid xray value: $xray_value" >&2
    exit 2
fi

snippet_dir=$(dirname -- "$snippet_path")
mkdir -p -- "$snippet_dir"
snippet_tmp=$(mktemp "$snippet_dir/.clavis-effects.kdl.XXXXXX")
main_tmp=

cleanup() {
    rm -f -- "$snippet_tmp"
    if [ -n "$main_tmp" ]; then
        rm -f -- "$main_tmp"
    fi
}
trap cleanup EXIT HUP INT TERM

{
    echo "// Managed by Clavis. Manual edits will be replaced."
    if [ "$xray_value" = "true" ]; then
        echo "// X-Ray is niri's default for client-requested effects."
        echo "// No rule override is required."
    else
        echo "layer-rule {"
        echo "    match namespace=\"^clavis-shell-\""
        echo
        echo "    background-effect {"
        echo "        xray false"
        echo "    }"
        echo "}"
        echo
        echo "window-rule {"
        echo "    match title=\"^(clavis-control-center|clavis-file-picker)$\""
        echo
        echo "    background-effect {"
        echo "        xray false"
        echo "    }"
        echo "}"
    fi
} > "$snippet_tmp"

"$niri_command" validate -c "$snippet_tmp" >/dev/null
chmod 600 "$snippet_tmp"
mv -f -- "$snippet_tmp" "$snippet_path"

if [ "$mode" = "write" ]; then
    trap - EXIT HUP INT TERM
    echo "ready"
    exit 0
fi

exec "$script_dir/manage-niri-fragment.sh" \
    configure "$main_config" "$snippet_path" "$niri_command" "EFFECTS"
