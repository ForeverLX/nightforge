import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "../services"

PanelWindow {
    id: powerMenu
    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }

    MatugenColors { id: mocha }

    MouseArea {
        anchors.fill: parent
        onClicked: powerMenu.visible = false
    }

    Item {
        anchors.centerIn: parent
        width: 280
        height: 320

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                Text {
                    text: "󰐥 Power"
                    color: mocha.text
                    font.pixelSize: 16
                    font.bold: true
                    font.family: "Iosevka Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                Item { Layout.preferredHeight: 10 }

                // Lock
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 8
                    color: lockArea.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Text { text: "󰌾"; color: mocha.text; font.pixelSize: 16; font.family: "Iosevka Nerd Font" }
                        Text { text: "Lock"; color: mocha.text; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }
                    MouseArea {
                        id: lockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenu.visible = false
                            var p = Qt.createQmlObject('import Quickshell.Io; Process {}', powerMenu)
                            p.command = ["niri", "msg", "action", "lock-screen"]
                            p.running = true
                        }
                    }
                }

                // Logout
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 8
                    color: logoutArea.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Text { text: "󰍃"; color: mocha.text; font.pixelSize: 16; font.family: "Iosevka Nerd Font" }
                        Text { text: "Logout"; color: mocha.text; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }
                    MouseArea {
                        id: logoutArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenu.visible = false
                            var p = Qt.createQmlObject('import Quickshell.Io; Process {}', powerMenu)
                            p.command = ["niri", "msg", "action", "quit"]
                            p.running = true
                        }
                    }
                }

                // Suspend
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 8
                    color: suspendArea.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Text { text: "󰒲"; color: mocha.text; font.pixelSize: 16; font.family: "Iosevka Nerd Font" }
                        Text { text: "Suspend"; color: mocha.text; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }
                    MouseArea {
                        id: suspendArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenu.visible = false
                            var p = Qt.createQmlObject('import Quickshell.Io; Process {}', powerMenu)
                            p.command = ["systemctl", "suspend"]
                            p.running = true
                        }
                    }
                }

                // Reboot
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 8
                    color: rebootArea.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Text { text: "󰜉"; color: mocha.text; font.pixelSize: 16; font.family: "Iosevka Nerd Font" }
                        Text { text: "Reboot"; color: mocha.text; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }
                    MouseArea {
                        id: rebootArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenu.visible = false
                            var p = Qt.createQmlObject('import Quickshell.Io; Process {}', powerMenu)
                            p.command = ["systemctl", "reboot"]
                            p.running = true
                        }
                    }
                }

                // Shutdown
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 8
                    color: shutdownArea.containsMouse ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.3) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Text { text: "󰐥"; color: mocha.red; font.pixelSize: 16; font.family: "Iosevka Nerd Font" }
                        Text { text: "Shutdown"; color: mocha.red; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                    }
                    MouseArea {
                        id: shutdownArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenu.visible = false
                            var p = Qt.createQmlObject('import Quickshell.Io; Process {}', powerMenu)
                            p.command = ["systemctl", "poweroff"]
                            p.running = true
                        }
                    }
                }
            }
        }
    }
}
