import QtQuick
import Quickshell.Io

import "../services"

Rectangle {
    property int workspaceNumber: 1
    property bool active: false
    property string primaryColor: ""
    property string textColor: ""
    property string outlineColor: ""

    MatugenColors { id: mocha }

    width: 22
    height: 22
    radius: 4
    color: active ? mocha.mauve : "transparent"
    border.color: wsMouse.containsMouse ? mocha.surface1 : mocha.surface0
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: workspaceNumber
        color: active ? mocha.crust : mocha.subtext0
        font.pixelSize: 11
        font.bold: active
    }

    MouseArea {
        id: wsMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', parent);
            proc.command = ["niri", "msg", "action", "focus-workspace", workspaceNumber.toString()];
            proc.running = true;
        }
    }
}