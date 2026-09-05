#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/matugen-registry.sh
source "$script_dir/../lib/matugen-registry.sh"
matugen_registry_init
mode=dark
scheme="scheme-tonal-spot"
image_path=""
source_color=""
dry_run=false
templates_requested=false
templates_csv=""

usage() {
    printf 'Usage: %s (--image PATH | --color HEX) [--mode dark|light] [--scheme SCHEME] [--templates ID,...] [--dry-run]\n' "$0" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            image_path=$2
            shift 2
            ;;
        --color)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            source_color=$2
            shift 2
            ;;
        --mode)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            mode=$2
            shift 2
            ;;
        --scheme)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            scheme=$2
            shift 2
            ;;
        --templates)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            templates_requested=true
            templates_csv=$2
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

if [[ -n "$image_path" && -n "$source_color" ]] \
    || [[ -z "$image_path" && -z "$source_color" ]]; then
    usage
    exit 2
fi
if [[ "$mode" != dark && "$mode" != light ]]; then
    usage
    exit 2
fi
if ! command -v matugen >/dev/null 2>&1; then
    printf 'matugen is required but was not found in PATH\n' >&2
    exit 1
fi
# Core generation is independent of external validation and execution.
registry=$(matugen_registry_list)
core=$(jq -c '[.templates[] | select(.origin == "builtin" and .id == "quickshell")] | if length == 1 then .[0] else null end' <<< "$registry")
if ! jq -e '. != null and .valid' <<< "$core" >/dev/null; then
    printf 'Missing or invalid internal quickshell template\n' >&2
    exit 1
fi
mkdir -p -- "$CLAVIS_RUNTIME_HOME/temporary"
runtime_dir=$(mktemp -d "$CLAVIS_RUNTIME_HOME/temporary/matugen.XXXXXX")
cleanup() { rm -rf -- "$runtime_dir"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
runtime_config="$runtime_dir/config.toml"

run_template() {
    local entry=$1 output
    {
        printf '[config]\nversion_check = false\n\n'
        matugen_render_entry <<< "$entry"
    } > "$runtime_config"
    output=$(jq -r '.outputPath' <<< "$entry")
    if [[ "$dry_run" == false ]]; then
        mkdir -p -- "$(dirname -- "$output")" || return
    fi
    local common_args=(--mode "$mode" --type "$scheme" --config "$runtime_config")
    if [[ "$dry_run" == true ]]; then common_args+=(--dry-run); fi
    if [[ -n "$image_path" ]]; then
        matugen --source-color-index 0 image "$image_path" "${common_args[@]}"
    else
        matugen color hex "$source_color" "${common_args[@]}"
    fi
}

event() {
    jq -nc --arg event "$1" --arg id "${2:-}" --arg error "${3:-}" '{schemaVersion: 1, event: $event, id: $id, error: ($error | gsub("\u001b\\[[0-9;]*[A-Za-z]"; ""))}'
}
if ! run_template "$core" > "$runtime_dir/log" 2>&1; then
    cat -- "$runtime_dir/log" >&2
    event core-error quickshell "$(tail -c 3000 "$runtime_dir/log")"
    exit 1
fi
if [[ "$dry_run" == false ]]; then event core-ready; fi
external_failed=false
report_external_error() {
    external_failed=true
    event external-error "$1" "$2"
    printf '%s: %s\n' "$1" "$2" >&2
}
registry_error=$(jq -r '.errors | join("; ")' <<< "$registry")
if [[ -n "$registry_error" ]]; then report_external_error registry "$registry_error"; fi
if [[ "$templates_requested" == false ]]; then
    templates_csv=$(jq -r '[.templates[] | select(.origin == "builtin" and .id != "quickshell") | .id] | join(",")' <<< "$registry")
fi
IFS=',' read -r -a requested_templates <<< "$templates_csv"
seen=,
for template_id in "${requested_templates[@]}"; do
    [[ -n "$template_id" && "$template_id" != quickshell ]] || continue
    if [[ "$seen" == *",$template_id,"* ]]; then continue; fi
    seen+="$template_id,"
    entry=$(jq -c --arg id "$template_id" '[.templates[] | select(.id == $id)] | .[0] // null' <<< "$registry")
    if ! jq -e '. != null and .valid' <<< "$entry" >/dev/null; then
        report_external_error "$template_id" "$(jq -r '.error // "Unknown template"' <<< "$entry")"
        continue
    fi
    if ! run_template "$entry" > "$runtime_dir/log" 2>&1; then
        report_external_error "$template_id" "$(tail -c 3000 "$runtime_dir/log")"
    fi
done
event finished
# Exit 3 specifically means core succeeded but external work failed.
if [[ "$external_failed" == true ]]; then exit 3; fi
