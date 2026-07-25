#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
app_shell="$repo_root/AppShell.qml"
launcher="$repo_root/Modules/Launcher/LauncherWindow.qml"

for signature in \
    'function set(path: string, screenName: string): string' \
    'function clear(screenName: string): string' \
    'function setFolder(path: string): string'; do
    rg -Fq "$signature" "$app_shell"
done

rg -Fq 'readonly property var modeLabels: ["Applications", "Windows", "Wallpapers"]' "$launcher"
rg -Fq 'root.setMode((root.currentMode + 1) % root.modeLabels.length)' "$launcher"
rg -Fq 'else wallpaperPage.applyWallpaper()' "$launcher"

echo "wallpaper picker contract tests passed"
