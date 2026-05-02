import QtQuick

Item {
    id: glass
    default property alias content: inner.data
    property var matugen: null
    property color glassColor: matugen ? Qt.rgba(matugen.mantle.r, matugen.mantle.g, matugen.mantle.b, 0.94) : Qt.rgba(0.09, 0.09, 0.14, 0.94)
    property color borderColor: matugen ? matugen.surface0 : "#313244"
    property int glassRadius: 10
    property int borderWidth: 1
    property real opacityFactor: 1.0

    Rectangle {
        anchors.fill: parent
        radius: glass.glassRadius
        color: glass.glassColor
        opacity: glass.opacityFactor
        border.width: glass.borderWidth
        border.color: glass.borderColor

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: 12
        }
    }
}
