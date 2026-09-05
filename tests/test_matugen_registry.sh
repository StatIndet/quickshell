#!/usr/bin/env bash
# Black-box registry and generation contract: only inspect JSON responses and
# resulting files. No source/layout assertions; all writes and hooks are isolated.
# Literal path and hook syntax is deliberately passed to the implementation.
# shellcheck disable=SC2016,SC2088
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v matugen >/dev/null || exit 77
command -v jq >/dev/null || exit 77
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
export HOME="$test_root/home with spaces"
export XDG_CONFIG_HOME="$HOME/config"
export CLAVIS_CONFIG_HOME="$XDG_CONFIG_HOME/clavis"
export CLAVIS_RUNTIME_HOME="$test_root/runtime"
export CLAVIS_GENERATED_HOME="$test_root/generated"
mkdir -p "$HOME" "$test_root/bin"
# Builtin hooks must not signal applications in the developer's session.
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$HOME/signals"\n' > "$test_root/bin/pkill"
chmod +x "$test_root/bin/pkill"
export PATH="$test_root/bin:$PATH"
manager="$repo_root/scripts/theme/manage_matugen_templates.sh"
generator="$repo_root/scripts/theme/generate_matugen_colors.sh"
manage() { bash "$manager" "$@"; }
generate() { bash "$generator" --color '#6750a4' "$@"; }
assert() { if ! "$@"; then printf 'Assertion failed: %s\n' "$*" >&2; exit 1; fi; }
reject() {
    if manage "$@" > "$test_root/rejected.json"; then
        printf 'Expected rejection: %s\n' "$*" >&2; exit 1
    fi
    jq -e '.schemaVersion == 1 and .ok == false and (.error | length > 0)' "$test_root/rejected.json" >/dev/null
}

manage list > "$test_root/list.json"
jq -e '.errors == [] and ([.templates[] | select(.origin == "builtin")] | length > 1) and all(.templates[]; .valid)' "$test_root/list.json" >/dev/null
assert test ! -e "$CLAVIS_CONFIG_HOME/matugen"
generate > "$test_root/generated.jsonl"
assert test -s "$CLAVIS_GENERATED_HOME/clavis/colors.json"
assert test -s "$HOME/.config/kitty/current-theme.conf"
assert test -s "$HOME/signals"
assert test ! -e "$CLAVIS_CONFIG_HOME/matugen"

printf 'background = {{colors.primary.default.hex}}\n' > "$test_root/ghostty.conf"
hook='printf "hook ran\n" >> "$HOME/hook-ran"'
manage validate ghostty "$test_root/ghostty.conf" '~/ghostty/Matugen' "$hook" > /dev/null
assert test ! -e "$CLAVIS_CONFIG_HOME/matugen"
assert test ! -e "$HOME/hook-ran"
manage add ghostty "$test_root/ghostty.conf" '~/ghostty/Matugen' "$hook" > /dev/null
assert cmp "$test_root/ghostty.conf" "$CLAVIS_CONFIG_HOME/matugen/templates/ghostty.conf"
manage list | jq -e '.templates[] | select(.id == "ghostty") | .origin == "user" and .valid and .hasPostHook' >/dev/null
assert test ! -e "$HOME/ghostty/Matugen"
generate > /dev/null
assert test ! -e "$HOME/hook-ran"
assert test ! -e "$HOME/ghostty/Matugen"
generate --templates ghostty > /dev/null
assert test -s "$HOME/ghostty/Matugen"
assert test -s "$HOME/hook-ran"
cp "$HOME/ghostty/Matugen" "$test_root/retained"
generate --templates '' --mode light --scheme scheme-expressive > /dev/null
assert cmp "$HOME/ghostty/Matugen" "$test_root/retained"

reject add kitty "$test_root/ghostty.conf" '~/another' ''
reject add ghostty "$test_root/ghostty.conf" '~/another' ''
reject add quickshell "$test_root/ghostty.conf" '~/another' ''
reject add '../escape' "$test_root/ghostty.conf" '~/another' ''
reject add injection "$test_root/ghostty.conf" '$(touch /tmp/clavis-should-not-exist)' ''
reject add injection "$test_root/ghostty.conf" '$OTHER/target' ''
reject add directory "$test_root" '~/another' ''

# Dotted IDs are emitted as one quoted TOML key, not a nested table.
manage add editor.custom "$test_root/ghostty.conf" '$HOME/editor/theme' '' > /dev/null
generate --templates editor.custom > /dev/null
assert test -s "$HOME/editor/theme"

cat >> "$CLAVIS_CONFIG_HOME/matugen/config.toml" <<'TOML'
[templates.missing]
input_path = "templates/not-found"
output_path = "~/missing/theme"
TOML
manage list | jq -e '.templates[] | select(.id == "missing") | .valid == false and (.error | length > 0)' >/dev/null
# A fresh process sees a manually added registration immediately.
cat >> "$CLAVIS_CONFIG_HOME/matugen/config.toml" <<'TOML'
[templates.manual]
input_path = "templates/ghostty.conf"
output_path = "~/manual/theme"
TOML
manage list | jq -e '.templates[] | select(.id == "manual") | .valid and .origin == "user"' >/dev/null

printf '{{this.is.not.a.valid.template.expression\n' > "$test_root/broken.conf"
manage add broken "$test_root/broken.conf" '~/broken/theme' '' > /dev/null
if generate --templates broken,editor.custom --mode dark > "$test_root/failure.jsonl" 2> "$test_root/failure.log"; then
    printf 'Expected external generation failure\n' >&2; exit 1
else
    assert test "$?" -eq 3
fi
jq -se 'any(.[]; .event == "core-ready") and any(.[]; .event == "external-error" and .id == "broken") and .[-1].event == "finished"' "$test_root/failure.jsonl" >/dev/null
assert test -s "$CLAVIS_GENERATED_HOME/clavis/colors.json"
assert test -s "$HOME/editor/theme"

# Unsupported syntax cannot silently become an active template.
cp "$CLAVIS_CONFIG_HOME/matugen/config.toml" "$test_root/before"
cat >> "$CLAVIS_CONFIG_HOME/matugen/config.toml" <<'TOML'
[templates.inline]
foo = { input_path = "templates/ghostty.conf", output_path = "~/bad" }
TOML
manage list | jq -e '(.errors | length > 0) and any(.templates[]; .id == "inline" and .valid == false)' >/dev/null
cp "$CLAVIS_CONFIG_HOME/matugen/config.toml" "$test_root/invalid"
reject add cannot-add "$test_root/ghostty.conf" '~/another' ''
assert cmp "$CLAVIS_CONFIG_HOME/matugen/config.toml" "$test_root/invalid"
cp "$test_root/before" "$CLAVIS_CONFIG_HOME/matugen/config.toml"

manage remove manual > /dev/null
manage remove ghostty > /dev/null
assert test ! -e "$CLAVIS_CONFIG_HOME/matugen/templates/ghostty.conf"
assert cmp "$HOME/ghostty/Matugen" "$test_root/retained"
manage list | jq -e 'all(.templates[]; .id != "ghostty" and .id != "manual")' >/dev/null
reject remove kitty
# An installed-style shell root locates its own package resources, independent
# of the source checkout. This does not install anything on the host.
installed="$test_root/package/etc/xdg/quickshell/clavis"
mkdir -p "$installed/scripts"
cp -r "$repo_root/scripts/lib" "$repo_root/scripts/theme" "$installed/scripts/"
cp -r "$repo_root/matugen" "$installed/matugen"
bash "$installed/scripts/theme/manage_matugen_templates.sh" list | jq -e --arg prefix "$installed/matugen/" 'all(.templates[] | select(.origin == "builtin"); .inputPath | startswith($prefix))' >/dev/null
bash "$installed/scripts/theme/generate_matugen_colors.sh" --color '#aabbcc' --templates '' --mode light > /dev/null
assert test -s "$CLAVIS_GENERATED_HOME/clavis/colors.json"

# Arbitrary newly registered IDs scale without app-specific code paths.
for number in $(seq 1 100); do
    printf '\n[templates.application-%s]\ninput_path = "%s"\noutput_path = "~/application-%s/theme"\n' "$number" "$test_root/ghostty.conf" "$number" >> "$CLAVIS_CONFIG_HOME/matugen/config.toml"
done
manage list | jq -e '[.templates[] | select(.id | startswith("application-"))] | length == 100 and all(.[]; .valid)' >/dev/null
generate --templates application-100 > /dev/null
assert test -s "$HOME/application-100/theme"
bash "$generator" --image "$repo_root/assets/images/dino.png" --templates '' > /dev/null
assert test -s "$CLAVIS_GENERATED_HOME/clavis/colors.json"

# A registration with no input can still be removed without touching output.
cat >> "$CLAVIS_CONFIG_HOME/matugen/config.toml" <<'TOML'
[templates.no-input]
output_path = "~/keep-this-output"
TOML
printf 'keep' > "$HOME/keep-this-output"
manage remove no-input > /dev/null
assert test -s "$HOME/keep-this-output"

printf 'Matugen registry integration passed\n'
