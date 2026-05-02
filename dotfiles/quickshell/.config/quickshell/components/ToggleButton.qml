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
    color: active && activeColor !== "" ? activeColor : (active ? mocha.mauve : mocha.surface0)

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.icon
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