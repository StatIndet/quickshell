#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp_dir=$(mktemp -d)
mock_state="$temp_dir/awww"
config_path="$temp_dir/personalization.json"
output_path="$temp_dir/quickshell.out"
mock_log="${mock_state}.log"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    rm -rf -- "$temp_dir"
}
trap cleanup EXIT INT TERM

if grep -Fq 'revisionBeforeConfig' \
        "$repo_dir/Services/WallpaperService.qml"; then
    fail "wallpaper setters still mutate revision directly"
fi
if grep -Fq 'function onSettingsRevisionChanged' \
        "$repo_dir/Services/AwwwWallpaperService.qml"; then
    fail "awww still reapplies on transition setting changes"
fi

printf '{}\n' > "$config_path"
for source in initial b c d; do
    cp "$repo_dir/assets/images/dino.png" \
        "$temp_dir/clavis-awww-dedup-${source}.png"
done

CLAVIS_AWWW_COMMAND="$repo_dir/tests/fixtures/mock-awww" \
CLAVIS_AWWW_DAEMON_COMMAND="$repo_dir/tests/fixtures/mock-awww-daemon" \
CLAVIS_AWWW_MOCK_STATE="$mock_state" \
CLAVIS_AWWW_MOCK_APPLY_DELAY_MS=180 \
CLAVIS_AWWW_TEST_SOURCE_DIR="$temp_dir" \
CLAVIS_PERSONALIZATION_CONFIG="$config_path" \
    qs -p "$repo_dir/smoke_awww_dedup.qml" \
    >"$output_path" 2>&1

cat "$output_path"

outputs=$(
    sed -n 's/.*AWWW_DEDUP_SMOKE_PASS outputs=\([0-9][0-9]*\).*/\1/p' \
        "$output_path" | tail -n 1
)
if [ -z "$outputs" ] || [ "$outputs" -lt 1 ]; then
    if [ -f "$mock_log" ]; then
        cat "$mock_log" >&2
    fi
    fail "awww dedup smoke did not report an output count"
fi

expected=$((outputs * 3))
actual=$(grep -c '^client img ' "$mock_log" || true)
if [ "$actual" -ne "$expected" ]; then
    echo "FAIL: expected $expected awww img commands, got $actual" >&2
    cat "$mock_log" >&2
    exit 1
fi

for source in initial b d; do
    count=$(grep -c "clavis-awww-dedup-${source}\\.png" "$mock_log" || true)
    if [ "$count" -ne "$outputs" ]; then
        echo "FAIL: $source target ran $count times for $outputs outputs" >&2
        cat "$mock_log" >&2
        exit 1
    fi
done

if grep -Fq 'clavis-awww-dedup-c.png' "$mock_log"; then
    echo "FAIL: superseded c target was applied" >&2
    cat "$mock_log" >&2
    exit 1
fi

if ! grep 'clavis-awww-dedup-[bd]\.png' "$mock_log" \
        | grep -Fq -- '--transition-fps 77'; then
    echo "FAIL: next wallpaper did not use the latest transition FPS" >&2
    cat "$mock_log" >&2
    exit 1
fi

awk '
/^client img / {
    source = $NF
    position = ""
    for (field = 1; field < NF; ++field) {
        if ($field == "--transition-pos")
            position = $(field + 1)
    }
    if (position == "") {
        print "FAIL: missing batch transition position" > "/dev/stderr"
        exit 1
    }
    if (seen[source] && seen[source] != position) {
        print "FAIL: batch used different random positions" > "/dev/stderr"
        exit 1
    }
    seen[source] = position
}
' "$mock_log"

echo "awww dedup command audit passed"
