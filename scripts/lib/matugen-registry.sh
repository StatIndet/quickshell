#!/usr/bin/env bash
# Shared registry implementation for management and generation. Requires jq.

matugen_registry_init() {
    local library_dir
    library_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    # shellcheck source=scripts/lib/clavis-paths.sh
    source "$library_dir/clavis-paths.sh"
    clavis_paths_init
    matugen_builtin_dir=$(cd -- "$library_dir/../.." && pwd)/matugen
    matugen_user_dir="$CLAVIS_CONFIG_HOME/matugen"
    matugen_parser="$library_dir/../theme/matugen_registry.jq"
}

matugen_read_config() {
    local origin=$1 directory=$2 parsed i missing_csv
    local -a inputs=() missing=()
    if [[ ! -e "$directory/config.toml" ]]; then
        if [[ "$origin" == user ]]; then
            printf '{"sections":[],"errors":[]}\n'
        else
            printf '{"sections":[],"errors":["Missing builtin registry"]}\n'
        fi
        return
    fi
    if [[ ! -f "$directory/config.toml" || ! -r "$directory/config.toml" ]]; then
        printf '{"sections":[],"errors":["Registry is not a readable regular file"]}\n'
        return
    fi
    parsed=$(jq -Rs --arg origin "$origin" --arg base "$directory" -f "$matugen_parser" "$directory/config.toml") || return
    mapfile -d '' -t inputs < <(jq -j '.sections[] | .inputPath, "\u0000"' <<< "$parsed")
    for i in "${!inputs[@]}"; do
        if [[ ! -f "${inputs[$i]}" || ! -r "${inputs[$i]}" ]]; then
            missing+=("$i")
        fi
    done
    missing_csv=$(IFS=,; printf '%s' "${missing[*]}")
    jq --argjson missing "[$missing_csv]" '.sections |= (to_entries | map(
        .key as $index | .value |
        if ($missing | index($index)) != null then
            .valid = false | .errors += ["Template file is missing or not a readable regular file"] |
            .error = (.errors | unique | join("; "))
        else . end))' <<< "$parsed"

}

matugen_registry_list() {
    local builtin user
    builtin=$(matugen_read_config builtin "$matugen_builtin_dir") || return
    user=$(matugen_read_config user "$matugen_user_dir") || return
    jq -n --argjson builtin "$builtin" --argjson user "$user" '
        ($builtin.sections | map(.id)) as $ids |
        ($user.sections | map(if .id == "quickshell" or (.id as $id | $ids | index($id)) != null
            then .valid = false | .errors += ["Template ID is reserved by Clavis"] | .error = (.errors | unique | join("; ")) else . end)) as $users |
        {schemaVersion: 1, templates: ($builtin.sections + $users),
         errors: ($builtin.errors + $user.errors + [$users[] | select(.id == "quickshell") | .error])}'
}

# JSON basic string escapes are also valid in the supported TOML subset.
# Quote IDs so a dot remains part of the ID, not a nested TOML table.
matugen_render_entry() {
    jq -r '"[templates." + (.id | tojson) + "]\ninput_path = " + (.inputPath | tojson) +
        "\noutput_path = " + (.outputPath | tojson) +
        (if .postHook != "" then "\npost_hook = " + (.postHook | tojson) else "" end) + "\n"'
}
