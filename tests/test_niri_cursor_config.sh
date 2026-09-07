#!/bin/sh
set -eu
repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
exec python3 "$repo_dir/tests/test_niri_config.py" ConfigurationContracts.test_cursor_wrapper
