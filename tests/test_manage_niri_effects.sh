#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manager="$repo_dir/scripts/system/manage-niri-effects.sh"
mock_niri="$repo_dir/tests/fixtures/mock-niri"
test_dir=$(mktemp -d /tmp/clavis-niri-effects-test.XXXXXX)

cleanup() {
    rm -rf -- "$test_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

assert_not_contains() {
    if grep -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

main_config="$test_dir/config.kdl"
snippet="$test_dir/clavis/effects.kdl"
printf '%s\n' 'input {}' > "$main_config"

"$manager" write "$main_config" "$snippet" true "$mock_niri" >/dev/null
assert_contains "$snippet" "X-Ray is niri's default"
assert_not_contains "$snippet" 'match namespace='
assert_not_contains "$snippet" 'match title='
assert_not_contains "$snippet" 'background-effect'
assert_not_contains "$snippet" 'xray true'
assert_not_contains "$snippet" 'xray false'
assert_not_contains "$snippet" 'blur true'
assert_not_contains "$snippet" 'clavis-wallpaper'
assert_not_contains "$snippet" 'clavis-overview-wallpaper'
assert_not_contains "$snippet" 'clavis-lock'
assert_not_contains "$snippet" 'clavis-region-selector'

"$manager" write "$main_config" "$snippet" false "$mock_niri" >/dev/null
assert_contains "$snippet" 'match namespace="^clavis-shell-"'
assert_contains "$snippet" 'match title="^(clavis-control-center|clavis-file-picker)$"'
assert_contains "$snippet" 'xray false'
assert_not_contains "$snippet" 'xray true'
assert_not_contains "$snippet" 'blur true'

printf '%s\n' 'known-good' > "$snippet"
if MOCK_NIRI_FAIL=1 "$manager" write "$main_config" "$snippet" true "$mock_niri" >/dev/null 2>&1; then
    fail "invalid snippet unexpectedly replaced the valid file"
fi
assert_contains "$snippet" 'known-good'

"$manager" configure "$main_config" "$snippet" true "$mock_niri" >/dev/null
assert_contains "$main_config" 'include optional=true "clavis/effects.kdl"'
[ -f "$main_config.clavis-backup" ] || fail "main config backup was not created"
[ "$(grep -Fc 'include optional=true "clavis/effects.kdl"' "$main_config")" -eq 1 ] \
    || fail "include was not added exactly once"

"$manager" configure "$main_config" "$snippet" false "$mock_niri" >/dev/null
[ "$(grep -Fc 'include optional=true "clavis/effects.kdl"' "$main_config")" -eq 1 ] \
    || fail "include was duplicated"
assert_contains "$snippet" 'xray false'

commented_main="$test_dir/commented-config.kdl"
printf '%s\n' \
    'input {}' \
    'include optional=true "clavis/effects.kdl" // Clavis' \
    > "$commented_main"
"$manager" configure "$commented_main" "$snippet" true "$mock_niri" >/dev/null
[ "$(grep -Fc 'clavis/effects.kdl' "$commented_main")" -eq 1 ] \
    || fail "include with a trailing comment was duplicated"

invalid_main="$test_dir/invalid-config.kdl"
invalid_snippet="$test_dir/invalid-effects.kdl"
printf '%s\n' 'INVALID' > "$invalid_main"
if "$manager" configure "$invalid_main" "$invalid_snippet" true "$mock_niri" >/dev/null 2>&1; then
    fail "invalid main config unexpectedly passed validation"
fi
[ "$(cat "$invalid_main")" = "INVALID" ] \
    || fail "invalid main config was overwritten"
[ ! -e "$invalid_main.clavis-backup" ] \
    || fail "backup was created before validation succeeded"

echo "niri effects config tests passed"
