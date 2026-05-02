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

    function show(icon, label, value) {
        osdIcon = icon
        osdLabel = label
        osdValue = value
        visible = true
        hideTimer.stop()
        hideTimer.start()
    }

    Timer { id: hideTimer; interval: 2000; onTriggered: { osdOpacity = 0; fadeTimer.start() } }
    Timer { id: fadeTimer; interval: 300; onTriggered: osd.visible = false; osdOpacity = 1.0 }

    property real osdOpacity: 1.0
    Behavior on osdOpacity { NumberAnimation { duration: 250 } }

    MouseArea { anchors.fill: parent; enabled: false }

    GlassPanel {
        id: osdBox
        anchors.top: parent.top; anchors.topMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        width: 280; height: 80
        matugen: mocha
        glassRadius: 16
        opacity: osd.osdOpacity

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 8
                Text { text: osd.osdIcon; color: mocha.text; font.pixelSize: 18 }
                Text { text: osd.osdLabel; color: mocha.text; font.pixelSize: 14; font.bold: true }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: mocha.surface0
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
