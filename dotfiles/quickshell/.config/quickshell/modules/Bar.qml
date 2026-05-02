import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../services"
import "../components"

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: bar

            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }

            Scaler {
                id: scaler
                currentWidth: bar.width
            }

            function s(val) { return scaler.s(val); }

            property int barHeight: 48
            property bool isExpanded: false

            implicitHeight: bar.currentHeight
            margins { top: 0; bottom: 0; left: 4; right: 4 }
            exclusiveZone: barHeight
            color: "transparent"

            MatugenColors { id: mocha }

            property string performanceMode: "high"
            property bool lowPerf: performanceMode === "low"

            property string clock: ""
            property string dateStr: ""
            property string battery: "N/A"
            property string vpnStatus: "Down"
            property string podmanStatus: "Down"
            property string volume: "0"
            property string windowTitle: ""

            property int currentHeight: 4

            Behavior on currentHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Process {
                id: perfPoll
                command: ["cat", "/home/ForeverLX/.config/nightforge/performance-mode"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        var txt = text.trim()
                        bar.performanceMode = txt === "low" ? "low" : "high"
                    }
                }
            }
            Timer { interval: 5000; running: true; repeat: true; onTriggered: { perfPoll.running = false; perfPoll.running = true } }

            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: {
                    bar.clock = Qt.formatDateTime(new Date(), "hh:mm")
                    bar.dateStr = Qt.formatDateTime(new Date(), "MMM dd")
                }
            }

            Process {
                id: batteryPoll
                command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"]
                running: true
                stdout: StdioCollector { onStreamFinished: { var txt = this.text.trim(); if (txt !== "") bar.battery = txt + "%" } }
            }
            Timer { interval: 60000; running: true; repeat: true; onTriggered: batteryPoll.running = true }

            Process {
                id: volumePoll
                command: ["sh", "-c", "pamixer --get-volume 2>/dev/null || wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]
                running: true
                stdout: StdioCollector { onStreamFinished: { var txt = this.text.trim(); if (txt !== "") bar.volume = txt } }
            }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: volumePoll.running = true }

            Process {
                id: vpnPoll
                command: ["sh", "-c", "wg show wg0 2>/dev/null | grep -q 'interface' && echo 'Up' || echo 'Down'"]
                running: true
                stdout: StdioCollector { onStreamFinished: { bar.vpnStatus = this.text.trim() } }
            }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: vpnPoll.running = true }

            Process {
                id: podmanPoll
                command: ["sh", "-c", "podman ps --quiet 2>/dev/null | wc -l"]
                running: true
                stdout: StdioCollector { onStreamFinished: { var count = parseInt(this.text.trim()) || 0; bar.podmanStatus = count > 0 ? "Active (" + count + ")" : "Down" } }
            }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: podmanPoll.running = true }

            Process {
                id: windowPoll
                command: ["sh", "-c", "niri msg --json windows 2>/dev/null | jq -r '.[] | select(.is_focused == true) | .title' | head -1 || echo ''"]
                running: true
                stdout: StdioCollector { onStreamFinished: { bar.windowTitle = this.text.trim() } }
            }
            Timer { interval: 1000; running: true; repeat: true; onTriggered: windowPoll.running = true }

            Timer {
                id: collapseTimer
                interval: 1000
                onTriggered: { bar.currentHeight = 4; bar.isExpanded = false }
            }

            FocusScope {
                anchors.fill: parent

                // Bar background
                Rectangle {
                    id: barBg
                    anchors.fill: parent
                    color: bar.isExpanded
                        ? Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, 0.92)
                        : Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, 0.85)
                    radius: s(14)
                    border.width: 1
                    border.color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)

                    Behavior on color { ColorAnimation { duration: 200 } }

                    MouseArea {
                        id: barMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onEntered: { collapseTimer.stop(); bar.currentHeight = bar.barHeight; bar.isExpanded = true }
                        onExited: { collapseTimer.start() }
                        onClicked: { if (mouse.button === Qt.RightButton) statusMonitor.visible = !statusMonitor.visible }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: bar.isExpanded ? s(8) : 0
                        anchors.rightMargin: bar.isExpanded ? s(8) : 0
                        clip: true
                        opacity: bar.isExpanded ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            spacing: s(8)

                            // === LEFT CAPSULE: App button + Window title ===
                            Rectangle {
                                Layout.alignment: Qt.AlignLeft
                                height: s(36); radius: s(10)
                                color: mocha.surface0
                                visible: bar.isExpanded
                                width: leftInner.implicitWidth + s(12)

                                Row {
                                    id: leftInner
                                    anchors.centerIn: parent
                                    spacing: s(6)

                                    Rectangle {
                                        width: s(28); height: s(28); radius: s(8)
                                        color: appBtn.containsMouse ? mocha.surface1 : "transparent"
                                        Text { anchors.centerIn: parent; text: "\u2630"; color: mocha.text; font.pixelSize: s(14) }
                                        MouseArea {
                                            id: appBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var p = Qt.createQmlObject('import Quickshell.Io; Process {}', bar)
                                                p.command = ["sh", "-c", "echo launcher > /tmp/quickshell-toggle"]
                                                p.running = true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: s(200); height: s(28); radius: s(6); color: "transparent"
                                        visible: bar.windowTitle !== ""
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: s(2)
                                            text: bar.windowTitle; color: mocha.subtext0; font.pixelSize: s(11)
                                            elide: Text.ElideRight; width: parent.width
                                        }
                                    }
                                }
                            }

                            // === CENTER CAPSULE: Clock ===
                            Rectangle {
                                Layout.alignment: Qt.AlignCenter
                                height: s(36); radius: s(10)
                                color: mocha.surface0
                                visible: bar.isExpanded
                                width: centerInner.implicitWidth + s(14)

                                Row {
                                    id: centerInner
                                    anchors.centerIn: parent
                                    spacing: s(6)
                                    Text { text: bar.clock; color: mocha.text; font.pixelSize: s(13); font.bold: true }
                                    Text { text: "|"; color: mocha.surface1; font.pixelSize: s(12) }
                                    Text { text: bar.dateStr; color: mocha.subtext0; font.pixelSize: s(11) }
                                }
                            }

                            // === RIGHT CAPSULE: Status icons ===
                            Rectangle {
                                Layout.alignment: Qt.AlignRight
                                height: s(36); radius: s(10)
                                color: mocha.surface0
                                visible: bar.isExpanded
                                width: rightInner.implicitWidth + s(12)

                                Row {
                                    id: rightInner
                                    anchors.centerIn: parent
                                    spacing: s(10)

                                    Text {
                                        text: "\uD83D\uDCE6" + bar.podmanStatus.replace("Active", "")
                                        color: bar.podmanStatus.indexOf("Active") !== -1 ? mocha.green : mocha.subtext0
                                        font.pixelSize: s(11)
                                    }
                                    Text {
                                        text: "\uD83D\uDD12" + bar.vpnStatus
                                        color: bar.vpnStatus === "Up" ? mocha.green : mocha.red
                                        font.pixelSize: s(11)
                                    }
                                    Text {
                                        text: "\uD83D\uDD0A" + bar.volume + "%"
                                        color: mocha.text; font.pixelSize: s(11)
                                    }
                                    Text {
                                        text: "\uD83D\uDD0B" + bar.battery
                                        color: mocha.text; font.pixelSize: s(11)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
