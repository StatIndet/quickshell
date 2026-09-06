#!/usr/bin/env bash
set -euo pipefail

output=${1:?missing output name}
script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Private transient PNG bridges the two Qt processes; remove it on every exit.
umask 077
snapshot_dir=$(mktemp -d "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/clavis-snapshot.XXXXXX")
trap 'rm -rf -- "$snapshot_dir"' EXIT
export CLAVIS_SNAPSHOT_OUTPUT="$output"
export CLAVIS_SNAPSHOT_PATH="$snapshot_dir/frame.png"
timeout --kill-after=0.2s 1.5s quickshell --path "$script_dir/LockSnapshot.qml" >/dev/null
[[ -s "$CLAVIS_SNAPSHOT_PATH" ]]
base64 --wrap=0 "$CLAVIS_SNAPSHOT_PATH"
