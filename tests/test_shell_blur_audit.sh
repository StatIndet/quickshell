#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_text() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

reject_text() {
    if grep -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

for file in \
    Modules/Bar/Bar.qml \
    Modules/Bar/Tray/Tray.qml \
    Modules/Bar/Tray/TrayMenu.qml \
    Modules/ControlCenter/BezierCurveLayerEditor.qml \
    Modules/ControlCenter/WallpaperColorPicker.qml \
    Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    Modules/Launcher/LauncherWindow.qml \
    Modules/Sidebars/SidebarHostWindow.qml
do
    require_text "$file" 'WlrLayershell.namespace: "clavis-shell-'
done

for file in \
    Modules/Wallpaper/DesktopWallpaper.qml \
    Modules/Wallpaper/OverviewWallpaper.qml \
    Modules/Lock/LockSurface.qml \
    Modules/Lock/LockWarmup.qml \
    Modules/RegionSelector/RegionSelectionWindow.qml \
    Services/IdleInhibitorSurface.qml
do
    reject_text "$file" 'CompositorBlurRegion'
    reject_text "$file" 'BackgroundEffect.blurRegion'
    reject_text "$file" 'clavis-shell-'
done

require_text Modules/Bar/Bar.qml 'additionalBackgroundItems: ['
reject_text Modules/Bar/Bar.qml 'backgroundItem: barContent'
require_text Modules/Sidebars/SidebarHostWindow.qml \
    'additionalBackgroundItems: ['
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'color: "transparent"'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'FloatingWindow {'
reject_text Modules/ControlCenter/ControlCenterWindow.qml \
    'ApplicationWindow {'
reject_text Modules/ControlCenter/ControlCenterWindow.qml \
    'flags: Qt.Window | Qt.FramelessWindowHint'
require_text controlcenter.qml \
    '//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1'
require_text Modules/FilePicker/FilePickerWindow.qml \
    'color: "transparent"'
require_text Modules/FilePicker/FilePickerWindow.qml \
    'flags: Qt.Window | Qt.FramelessWindowHint'
require_text Modules/FilePicker/FilePickerWindow.qml \
    'CompositorBlurRegion {'
require_text Modules/ControlCenter/WallpaperFileBrowser.qml \
    'FilePickerWindow {'
reject_text Modules/ControlCenter/WallpaperFileBrowser.qml \
    'PanelWindow {'
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'subtractedBackgroundItems: [dashboardBlurCutout]'
require_text Modules/Launcher/LauncherWindow.qml \
    'CompositorBlurRegion {'
require_text Modules/Launcher/LauncherWindow.qml \
    'searchBar.blurRegionItems.slice(1).concat(['
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'property color color: BlurService.backgroundColor('
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'context.globalCompositeOperation ='
require_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    '"destination-out";'
reject_text Modules/Keystone/Styles/Shared/KeystoneSurface.qml \
    'id: solidRootBg'
require_text Modules/Lock/LockSurface.qml \
    'color: BlurService.backgroundColor('
require_text Modules/Lock/LockSurface.qml \
    'id: desktopSnapshotFallback'
require_text Modules/Lock/LockSurface.qml \
    'blur: root.backgroundBlur'
require_text Widgets/common/StyledToolTip.qml \
    'PopupToolTip {'
require_text Widgets/common/PopupToolTip.qml \
    'CompositorBlurRegion {'
require_text Widgets/common/CompositorBlurRegion.qml \
    'combinedRegion.regions = combinedRegions'
require_text Widgets/common/CompositorBlurRegion.qml \
    'intersection: Intersection.Subtract'
require_text Widgets/common/CompositorBlurRegion.qml \
    'Qt.callLater(root.commit)'
require_text Widgets/common/CompositorBlurRegion.qml \
    'targetWindow.BackgroundEffect.blurRegion = null'

if rg -n '(^|\\s)(PanelWindow|window|root|sidebar|controlCenter|Loader)\\.opacity\\s*[:=].*shellBackgroundOpacity' \
        Modules Widgets Services >/dev/null; then
    fail "shell background opacity is applied to a window or content parent"
fi

echo "shell blur surface audit passed"
