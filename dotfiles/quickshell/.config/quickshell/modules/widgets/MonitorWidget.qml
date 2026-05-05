import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../../components"
import "../../services"

Item {
    id: window
    property string widgetName: "monitor"

    implicitWidth: 420
    implicitHeight: 380

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

    GlassPanel {
        anchors.fill: parent
        matugen: mocha
        glassRadius: 20

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
                    height: 70
                    radius: 10
                    color: mocha.surface0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4
                        Text {
                            text: (typeof modelData === "object" ? (modelData.name || "Unknown") : "Unknown")
                            color: mocha.text
                            font.pixelSize: 13
                            font.bold: true
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
