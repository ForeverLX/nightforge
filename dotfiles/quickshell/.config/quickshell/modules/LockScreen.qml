import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "../services"

PanelWindow {
    id: lockScreen
    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: "nightforge-lock"

    MatugenColors { id: mocha }

    property string lockClock: ""
    property string lockDate: ""

    Timer {
        interval: 1000; running: lockScreen.visible; repeat: true; triggeredOnStart: true
        onTriggered: {
            var n = new Date()
            lockClock = n.getHours().toString().padStart(2,'0') + ":" + n.getMinutes().toString().padStart(2,'0')
            var M = ["January","February","March","April","May","June","July","August","September","October","November","December"]
            var D = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
            lockDate = D[n.getDay()] + ", " + M[n.getMonth()] + " " + n.getDate()
        }
    }

    Item {
        anchors.fill: parent
        focus: lockScreen.visible

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.95)

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: lockClock
                    color: mocha.text
                    font.pixelSize: 72
                    font.family: "Iosevka Nerd Font"
                    font.weight: Font.Light
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: lockDate
                    color: mocha.subtext0
                    font.pixelSize: 18
                    font.family: "Google Sans"
                }

                Item { height: 40 }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰌾  Locked"
                    color: mocha.subtext0
                    font.pixelSize: 14
                    font.family: "Iosevka Nerd Font"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Press Enter to unlock"
                    color: mocha.overlay0
                    font.pixelSize: 12
                    font.family: "Google Sans"
                }
            }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                lockScreen.visible = false
                event.accepted = true
            }
        }
    }
}
