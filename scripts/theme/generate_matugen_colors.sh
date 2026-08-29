#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
scripts_dir=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=scripts/lib/clavis-paths.sh
source "$scripts_dir/lib/clavis-paths.sh"
clavis_paths_init

share_root=$(cd -- "$scripts_dir/.." && pwd)
matugen_dir="$share_root/defaults/matugen"
if [[ ! -d "$matugen_dir/templates" ]]; then
    matugen_dir="$share_root/matugen"
fi
config_path="$matugen_dir/config.toml"
mode=dark
scheme=scheme-tonal-spot
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
if [[ ! -f "$config_path" ]]; then
    printf 'Missing matugen config: %s\n' "$config_path" >&2
    exit 1
fi

all_external_templates=(
    btop
    cava
    kitty
    yazi
)

selected_templates=(quickshell)
if [[ "$templates_requested" == false ]]; then
    selected_templates+=("${all_external_templates[@]}")
elif [[ -n "$templates_csv" ]]; then
    IFS=',' read -r -a requested_templates <<< "$templates_csv"
    for template_id in "${requested_templates[@]}"; do
        case "$template_id" in
            btop|cava|kitty|yazi)
                ;;
            *)
                printf 'Unknown matugen template: %s\n' "$template_id" >&2
                exit 2
                ;;
        esac
        already_selected=false
        for selected_id in "${selected_templates[@]}"; do
            if [[ "$selected_id" == "$template_id" ]]; then
                already_selected=true
                break
            fi
        done
        if [[ "$already_selected" == false ]]; then
            selected_templates+=("$template_id")
        fi
    done
fi

template_file() {
    case "$1" in
        quickshell) printf '%s\n' quickshell-colors.json ;;
        btop) printf '%s\n' btop.theme ;;
        cava) printf '%s\n' cava-colors.ini ;;
        kitty) printf '%s\n' kitty-colors.conf ;;
        yazi) printf '%s\n' yazi-theme.toml ;;
    esac
}

for template_id in "${selected_templates[@]}"; do
    template_path="$matugen_dir/templates/$(template_file "$template_id")"
    [[ -f "$template_path" ]] || {
        printf 'Missing matugen template: %s\n' "$template_path" >&2
        exit 1
    }
done

if [[ "$dry_run" == false ]]; then
    mkdir -p "$CLAVIS_GENERATED_HOME/clavis"
    for template_id in "${selected_templates[@]}"; do
        case "$template_id" in
            btop) mkdir -p "$HOME/.config/btop/themes" ;;
            cava) mkdir -p "$HOME/.config/cava/themes" ;;
            kitty) mkdir -p "$HOME/.config/kitty/themes" ;;
            yazi) mkdir -p "$HOME/.config/yazi" ;;
        esac
    done
fi

enabled_sections=,
for template_id in "${selected_templates[@]}"; do
    enabled_sections+="$template_id,"
done

mkdir -p "$CLAVIS_RUNTIME_HOME/temporary"
runtime_dir=$(mktemp -d "$CLAVIS_RUNTIME_HOME/temporary/matugen.XXXXXX")
cleanup() {
    rm -rf -- "$runtime_dir"
}
trap cleanup EXIT HUP INT TERM
runtime_config="$runtime_dir/config.toml"

awk \
    -v enabled="$enabled_sections" \
    -v matugen_dir="$matugen_dir" \
    -v generated_home="$CLAVIS_GENERATED_HOME" '
    /^\[templates\.[^]]+\]$/ {
        name = $0
        sub(/^\[templates\./, "", name)
        sub(/\]$/, "", name)
        emit = index(enabled, "," name ",") > 0
    }
    /^\[config\]$/ { emit = 1 }
    /^\[[^]]+\]$/ && $0 !~ /^\[templates\./ && $0 !~ /^\[config\]$/ {
        emit = 0
    }
    emit {
        line = $0
        if (line ~ /^input_path = "templates\//)
            sub(/^input_path = "/, "input_path = \"" matugen_dir "/", line)
        gsub(/@CLAVIS_GENERATED_HOME@/, generated_home, line)
        print line
    }
' "$config_path" > "$runtime_config"

common_args=(--mode "$mode" --type "$scheme" --config "$runtime_config")
if [[ "$dry_run" == true ]]; then
    common_args+=(--dry-run)
fi

if [[ -n "$image_path" ]]; then
    matugen --source-color-index 0 image "$image_path" "${common_args[@]}"
else
    matugen color hex "$source_color" "${common_args[@]}"
fi
