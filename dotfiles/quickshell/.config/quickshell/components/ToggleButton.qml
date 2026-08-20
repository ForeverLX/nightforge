import QtQuick
import QtQuick.Layouts

import "../services"

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property string activeColor: ""

    signal clicked()

    MatugenColors { id: mocha }

    width: 90
    height: 64
    radius: 10
    color: active && activeColor !== "" ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.3) : (active ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.3) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4))
    border.width: active ? 1 : 0
    border.color: active && activeColor !== "" ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.5) : (active ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.5) : "transparent")

    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on border.width { NumberAnimation { duration: 200 } }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 18
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: root.label
            color: active ? "#ffffff" : mocha.subtext0
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
