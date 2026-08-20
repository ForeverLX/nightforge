import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../services"
import "../WindowRegistry.js" as LayoutMath

PanelWindow {
    id: window
    visible: false
    color: "transparent"

    MatugenColors { id: mocha }

    property var outputs: []

    Process {
        id: outputPoller
        command: ["sh", "-c", "niri msg outputs 2>/dev/null || echo '[]'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { window.outputs = JSON.parse(text.trim()) || [] } catch(e) { window.outputs = [] }
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: { outputPoller.running = false; outputPoller.running = true } }

    MouseArea {
        anchors.fill: parent
        onClicked: window.visible = false
    }

    Item {
        anchors.centerIn: parent

        property var layoutInfo: LayoutMath.getLayoutSimple(Screen.width, Screen.height, "monitor")
        width: layoutInfo ? layoutInfo.w : 420
        height: layoutInfo ? layoutInfo.h : 380

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Display Controls"
                        color: mocha.text
                        font.pixelSize: 16
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "󰅖"
                        color: mocha.subtext0
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 14
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Outputs: " + window.outputs.length
                    color: mocha.subtext0
                    font.pixelSize: 12
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: window.outputs

                    delegate: Rectangle {
                        width: ListView.view ? ListView.view.width : 0
                        height: 90
                        radius: 10
                        color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name || "Unknown"
                                    color: mocha.text
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: modelData.current_mode
                                        ? (modelData.current_mode.width + "x" + modelData.current_mode.height + "@" + Math.round(modelData.current_mode.refresh / 1000) + "Hz")
                                        : ""
                                    color: mocha.subtext0
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                text: modelData.logical
                                    ? "Position: " + modelData.logical.x + "," + modelData.logical.y + " | Scale: " + (modelData.scale || 1.0) + "x"
                                    : ""
                                color: mocha.subtext0
                                font.pixelSize: 10
                                visible: text !== ""
                            }

                            Text {
                                text: modelData.make && modelData.model
                                    ? (modelData.make + " " + modelData.model)
                                    : ""
                                color: mocha.overlay0
                                font.pixelSize: 10
                                visible: text !== ""
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: window.outputs.length === 0 ? "No outputs detected" : ""
                        color: mocha.subtext0
                        font.pixelSize: 12
                        visible: window.outputs.length === 0
                    }
                }
            }
        }
    }
}