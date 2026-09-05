#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/matugen-registry.sh
source "$script_dir/../lib/matugen-registry.sh"
matugen_registry_init

fail() {
    jq -nc --arg error "$1" '{schemaVersion: 1, ok: false, error: ($error | gsub("\u001b\\[[0-9;]*[A-Za-z]"; ""))}'
    exit 1
}
success() {
    jq -nc --arg id "${template_id:-}" '{schemaVersion: 1, ok: true, id: $id}'
}
command_name=${1:-list}
shift "$(( $# > 0 ? 1 : 0 ))"
if [[ "$command_name" == list ]]; then
    matugen_registry_list
    exit
fi
[[ "$command_name" == validate || "$command_name" == add || "$command_name" == remove ]] || fail 'Unknown operation'
template_id=${1:-}
[[ "$template_id" =~ ^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$ ]] || fail 'Use letters, numbers, dots, hyphens or underscores for the template ID'
[[ "$template_id" != quickshell ]] || fail 'This template ID is reserved by Clavis'

# Serialize Clavis writers without creating the user registry just to inspect it.
mkdir -p -- "$CLAVIS_RUNTIME_HOME/temporary"
exec 9>"$CLAVIS_RUNTIME_HOME/temporary/matugen-registry.lock"
flock -x 9
work_dir=$(mktemp -d "$CLAVIS_RUNTIME_HOME/temporary/matugen-manage.XXXXXX")
config_temp=''
copied_path=''
cleanup() {
    [[ -z "$config_temp" ]] || rm -f -- "$config_temp"
    [[ -z "$copied_path" ]] || rm -f -- "$copied_path"
    rm -rf -- "$work_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
config_path="$matugen_user_dir/config.toml"
[[ ! -L "$config_path" ]] || fail 'Edit the symlinked registry manually'
config_existed=false
if [[ -e "$config_path" ]]; then
    [[ -f "$config_path" && -r "$config_path" ]] || fail 'Registry is not a readable regular file'
    cp -- "$config_path" "$work_dir/original"
    config_existed=true
else
    : > "$work_dir/original"
fi
registry=$(matugen_registry_list)
jq -e '.errors | length == 0' <<< "$registry" >/dev/null || fail 'Fix unsupported registry syntax before editing templates'

commit_config() {
    # Editors do not take our lock: refuse an observed concurrent modification.
    if [[ "$config_existed" == true ]]; then
        cmp -s -- "$config_path" "$work_dir/original" || fail 'Registry changed; refresh and retry'
    else
        [[ ! -e "$config_path" && ! -L "$config_path" ]] || fail 'Registry changed; refresh and retry'
    fi
    mv -T -- "$config_temp" "$config_path" || fail 'Unable to replace the registry'
    config_temp=''
}

if [[ "$command_name" == remove ]]; then
    entry=$(jq -c --arg id "$template_id" '[.templates[] | select(.origin == "user" and .id == $id)] | if length == 1 then .[0] else null end' <<< "$registry")
    [[ "$entry" != null ]] || fail 'User template is missing or its ID is duplicated'
    config_temp=$(mktemp "$matugen_user_dir/.config.XXXXXX")
    jq -Rrs --argjson entry "$entry" 'split("\n") | .[:$entry.start] + .[$entry.end:] | join("\n")' "$work_dir/original" > "$config_temp"
    commit_config
    # Only delete an unshared, direct managed source, never an output or an
    # arbitrary path registered manually. A symlinked source is left untouched.
    input=$(jq -r '.inputPath' <<< "$entry")
    resolved=$(realpath -m -- "$input" 2>/dev/null || true)
    managed=$(realpath -m -- "$matugen_user_dir/templates")
    if [[ "$input" == "$matugen_user_dir/templates/"* && "$(dirname -- "$resolved")" == "$managed" && ! -L "$input" && -f "$input" ]]; then
        shared=false
        while IFS= read -r other; do
            if [[ -n "$other" && "$(realpath -m -- "$other")" == "$resolved" ]]; then shared=true; break; fi
        done < <(jq -r --arg id "$template_id" '.templates[] | .outputPath, (select(.origin != "user" or .id != $id) | .inputPath)' <<< "$registry")
        if [[ "$shared" == false ]]; then
            rm -f -- "$input" || printf 'Registration removed; source cleanup failed: %s\n' "$input" >&2
        fi
    fi
    success
    exit
fi

[[ $# -eq 4 ]] || fail 'Expected ID, source file, output path and optional hook (empty string allowed)'
source_path=$2
output_path=$3
post_hook=$4
collision=$(jq -r --arg id "$template_id" '.templates[] | select(.id == $id) | .origin' <<< "$registry")
[[ -z "$collision" ]] || fail "Template ID '$template_id' already exists ($collision); choose another name"
[[ -f "$source_path" && -r "$source_path" ]] || fail 'Select a readable regular template file'
# Reject binary inputs before copying; UTF-8 text is the template contract.
iconv -f UTF-8 -t UTF-8 -- "$source_path" > "$work_dir/source" 2>/dev/null || fail 'Template must be UTF-8 text'
[[ $(LC_ALL=C tr -cd '\000' < "$work_dir/source" | wc -c) -eq 0 ]] || fail 'Template contains NUL bytes'
entry=$(jq -nc --arg id "$template_id" --arg input "$(realpath -- "$source_path")" --arg output "$output_path" --arg hook "$post_hook" '{id: $id, inputPath: $input, outputPath: $output, postHook: $hook}')
matugen_render_entry <<< "$entry" > "$work_dir/entry.toml"
parsed=$(jq -Rs --arg origin user --arg base "$matugen_user_dir" -f "$matugen_parser" "$work_dir/entry.toml")
jq -e '.sections | length == 1 and all(.[]; .valid)' <<< "$parsed" >/dev/null || fail 'Invalid output path or template fields'
entry=$(jq -c '.sections[0]' <<< "$parsed")
output=$(jq -r '.outputPath' <<< "$entry")
[[ ! -d "$output" ]] || fail 'Output path points to a directory'
# Matugen dry-run checks its config without executing hooks or writing outputs.
# It does not guarantee template expressions will render; generation isolates failures.
command -v matugen >/dev/null || fail 'Matugen is not installed'
{
    printf '[config]\nversion_check = false\n\n'
    jq '.postHook = ""' <<< "$entry" | matugen_render_entry
} > "$work_dir/config.toml"
matugen color hex '#6750a4' --dry-run --config "$work_dir/config.toml" > "$work_dir/validation.log" 2>&1 || fail "Matugen validation failed: $(tail -c 2000 "$work_dir/validation.log")"
if [[ "$command_name" == validate ]]; then success; exit; fi

filename=$(basename -- "$source_path")
extension=''
if [[ "$filename" == *.* ]]; then
    suffix=${filename##*.}
    if [[ "$suffix" =~ ^[A-Za-z0-9_-]+$ ]]; then extension=".$suffix"; fi
fi
destination="$matugen_user_dir/templates/$template_id$extension"
[[ ! -e "$destination" && ! -L "$destination" ]] || fail 'A managed template file already exists at this location'
[[ "$(realpath -m -- "$output")" != "$(realpath -m -- "$destination")" ]] || fail 'Output must not overwrite the managed template'
mkdir -p -- "$matugen_user_dir/templates"
config_temp=$(mktemp "$matugen_user_dir/.config.XXXXXX")
cat -- "$work_dir/original" > "$config_temp"
printf '\n' >> "$config_temp"
jq --arg input "templates/$template_id$extension" --arg output "$output_path" '.inputPath = $input | .outputPath = $output' <<< "$entry" | matugen_render_entry >> "$config_temp"
# Hard-link a complete temporary copy into place without overwriting orphan files.
source_temp=$(mktemp "$matugen_user_dir/templates/.template.XXXXXX")
if ! cp -- "$work_dir/source" "$source_temp"; then rm -f -- "$source_temp"; fail 'Unable to copy template'; fi
if ! ln -- "$source_temp" "$destination"; then rm -f -- "$source_temp"; fail 'Unable to create managed template'; fi
rm -f -- "$source_temp"
copied_path=$destination
commit_config
copied_path=''
success
