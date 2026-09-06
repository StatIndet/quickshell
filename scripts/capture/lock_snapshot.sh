#!/usr/bin/env bash
set -euo pipefail

# Separate Wayland connection: avoid Quickshell's WLR OutputTransformQuery
# interacting with Qt's wl_surface.enter handlers. No desktop image touches disk.
output=${1:?missing output name}
timeout --kill-after=0.2s 1s grim -l 1 -o "$output" - | base64 --wrap=0
