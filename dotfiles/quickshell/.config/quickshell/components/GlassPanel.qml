import QtQuick

Item {
    id: glass
    default property alias content: inner.data
    property var matugen: null
    property color glassColor: matugen ? Qt.rgba(matugen.base.r, matugen.base.g, matugen.base.b, 0.75) : Qt.rgba(0.09, 0.09, 0.14, 0.75)
    property color borderColor: matugen ? Qt.rgba(matugen.text.r, matugen.text.g, matugen.text.b, 0.06) : Qt.rgba(0.76, 0.79, 0.84, 0.06)
    property int glassRadius: 14
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
