import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Layouts

import "../services"
import "../components"

PanelWindow {
    id: osd
    visible: false
    color: "transparent"

    MatugenColors { id: mocha }

    anchors { top: true; left: true; right: true; bottom: true }

    property string osdIcon: ""
    property string osdLabel: ""
    property int osdValue: 0

    property real osdOpacity: 1.0
    property real osdScale: 1.0
    property real osdY: 0

    Behavior on osdOpacity { NumberAnimation { duration: 250 } }
    Behavior on osdScale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
    Behavior on osdY { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    function show(icon, label, value) {
        osdIcon = icon
        osdLabel = label
        osdValue = value
        osdScale = 1.0
        osdY = 0
        osdOpacity = 1.0
        visible = true
        hideTimer.stop()
        hideTimer.start()
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: {
            osdOpacity = 0
            osdScale = 0.9
            osdY = -20
            fadeTimer.start()
        }
    }
    Timer {
        id: fadeTimer
        interval: 300
        onTriggered: {
            osd.visible = false
            // Reset for next show
            osdOpacity = 1.0
            osdScale = 1.0
            osdY = 0
        }
    }

    MouseArea { anchors.fill: parent; enabled: false }

    GlassPanel {
        id: osdBox
        anchors.top: parent.top; anchors.topMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        width: 280; height: 80
        matugen: mocha
        glassRadius: 16
        opacity: osd.osdOpacity
        transform: [
            Scale {
                origin.x: osdBox.width / 2
                origin.y: osdBox.height / 2
                xScale: osd.osdScale
                yScale: osd.osdScale
            },
            Translate {
                y: osd.osdY
            }
        ]

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 8
                Text { text: osd.osdIcon; color: mocha.text; font.pixelSize: 18; font.family: "Iosevka Nerd Font" }
                Text { text: osd.osdLabel; color: mocha.text; font.pixelSize: 14; font.bold: true }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)
                Rectangle {
                    width: parent.width * (Math.max(0, Math.min(100, osd.osdValue)) / 100)
                    height: parent.height; radius: 4; color: mocha.mauve
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: osd.osdValue + "%"; color: mocha.subtext0; font.pixelSize: 11
            }
        }
    }
}
