import QtQuick
import qs.Common
import qs.Widgets.common

PopupToolTip {
    id: root

    property font font

    // Hover/pressed conditions already suppress tooltips for inactive
    // controls. Walking effective visibility through a Loader-backed sidebar
    // creates a dependency cycle in Qt 6 and can saturate the GUI thread.
    respectParentHierarchy: false
    horizontalPadding: 10
    verticalPadding: 5
    font {
        family: Sizes.fontFamily
        pixelSize: 12
        hintingPreference: Font.PreferNoHinting
    }

}
