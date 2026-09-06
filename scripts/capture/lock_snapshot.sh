#!/usr/bin/env bash
set -euo pipefail

output=${1:?missing output name}
script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Main process owns the lease through stdin. Keep the local image alive until
# unlock/cancellation releases it; EOF also releases it if the parent exits.
umask 077
snapshot_dir=$(mktemp -d "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/clavis-snapshot.XXXXXX")
trap 'rm -rf -- "$snapshot_dir"' EXIT
trap 'exit 1' HUP INT TERM
export CLAVIS_SNAPSHOT_OUTPUT="$output"
export CLAVIS_SNAPSHOT_PATH="$snapshot_dir/frame.bmp"
timeout --kill-after=0.2s 1.5s quickshell --path "$script_dir/LockSnapshot.qml" >/dev/null
[[ -s "$CLAVIS_SNAPSHOT_PATH" ]]
printf '%s\n' "$CLAVIS_SNAPSHOT_PATH"
IFS= read -r _release || true
