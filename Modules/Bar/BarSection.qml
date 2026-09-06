import QtQuick.Layouts

GridLayout {
    id: root

    property bool vertical: false
    property int componentCount: 0
    property bool compact: false

    rows: vertical ? Math.max(1, componentCount) : 1
    columns: vertical ? 1 : Math.max(1, componentCount)
    rowSpacing: compact ? 4 : 8
    columnSpacing: compact ? 4 : 8
}
