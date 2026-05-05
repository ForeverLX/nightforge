import QtQuick

Rectangle {
    id: root
    property string icon: ""
    property string value: ""
    property color color: "#cdd6f4"
    signal clicked()

    height: 28
    radius: 8
    color: mouse.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.9) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.8)
    width: row.implicitWidth + 14

    property var mocha: ({ text: "#cdd6f4", surface0: "#313244", surface1: "#45475a" })

    scale: mouse.containsMouse ? 1.15 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.icon
            color: root.color
            font.pixelSize: 11
            font.family: "Font Awesome 6 Free Solid"
        }
        Text {
            text: root.value
            color: root.color
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
