import QtQuick

Rectangle {
    id: root
    property string icon: ""
    property int size: 28
    property color accentColor: "transparent"
    signal clicked()

    width: size
    height: size
    radius: size / 2
    color: mouse.containsMouse && accentColor !== "transparent" ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.8) :
           mouse.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.8) :
           accentColor !== "transparent" ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.6) : "transparent"

    property var mocha: ({ text: "#cdd6f4", surface1: "#45475a", mauve: "#cba6f7" })

    scale: mouse.containsMouse ? 1.15 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.mocha.text
        font.pixelSize: root.size * 0.45
        font.family: "Font Awesome 6 Free Solid"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
