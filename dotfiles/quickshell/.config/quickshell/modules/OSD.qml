// OSD Module - ilyamiro-styled on-screen display
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Layouts

import "../services"

PanelWindow {
    id: osd
    visible: false
    color: "transparent"

    MatugenColors { id: mocha }

    anchors {
        top: true
        left: true
        right: true
    }

    property string osdIcon: ""
    property string osdLabel: ""
    property int osdValue: 0

    function show(icon, label, value) {
        osdIcon = icon
        osdLabel = label
        osdValue = value
        visible = true
    }

    // Click-through background
    MouseArea {
        anchors.fill: parent
        enabled: false
    }

    // Centered OSD box
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        width: 280
        height: 80
        radius: 16
        color: mocha.crust
        border.color: mocha.surface0
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    text: osd.osdIcon
                    color: mocha.text
                    font.pixelSize: 18
                }

                Text {
                    text: osd.osdLabel
                    color: mocha.text
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            // Progress bar background
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                radius: 4
                color: mocha.surface0

                Rectangle {
                    width: parent.width * (Math.max(0, Math.min(100, osd.osdValue)) / 100)
                    height: parent.height
                    radius: 4
                    color: mocha.mauve
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: osd.osdValue + "%"
                color: mocha.subtext0
                font.pixelSize: 11
            }
        }
    }
}