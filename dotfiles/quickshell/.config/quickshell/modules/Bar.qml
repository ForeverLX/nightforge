// Bar Module - NightForge top panel (ilyamiro-style)
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

            anchors {
                top: true
                left: true
                right: true
            }

            Scaler {
                id: scaler
                currentWidth: bar.width
            }

            function s(val) { return scaler.s(val); }

            property int barHeight: s(48)
            height: barHeight
            margins { top: s(8); bottom: 0; left: s(4); right: s(4) }
            exclusiveZone: barHeight
            color: "transparent"

            MatugenColors { id: mocha }

            property color bg: mocha.mantle
            property color fg: mocha.text
            property color dimFg: mocha.subtext0
            property color accent: mocha.mauve
            property color borderColor: mocha.surface0
            property color transparentBg: Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, 0.95)

            property string performanceMode: "high"
            property bool lowPerf: performanceMode === "low"

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

            property string clock: ""
            property string dateStr: ""
            property string battery: "N/A"
            property string vpnStatus: "Down"
            property string podmanStatus: "Down"
            property string volume: "0"

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
                stdout: StdioCollector {
                    onStreamFinished: {
                        var txt = this.text.trim()
                        if (txt !== "") bar.battery = txt + "%"
                    }
                }
            }
            Timer { interval: 60000; running: true; repeat: true; onTriggered: batteryPoll.running = true }

            Process {
                id: volumePoll
                command: ["sh", "-c", "pamixer --get-volume 2>/dev/null || wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        var txt = this.text.trim()
                        if (txt !== "") bar.volume = txt
                    }
                }
            }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: volumePoll.running = true }

            Process {
                id: vpnPoll
                command: ["sh", "-c", "wg show wg0 2>/dev/null | grep -q 'interface' && echo 'Up' || echo 'Down'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: { bar.vpnStatus = this.text.trim() }
                }
            }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: vpnPoll.running = true }

            Process {
                id: podmanPoll
                command: ["sh", "-c", "podman ps --quiet 2>/dev/null | wc -l"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        var count = parseInt(this.text.trim()) || 0
                        bar.podmanStatus = count > 0 ? "Active (" + count + ")" : "Down"
                    }
                }
            }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: podmanPoll.running = true }

            Item {
                anchors.fill: parent

                Rectangle {
                    id: barBg
                    anchors.fill: parent
                    color: barBg.isHovered
                        ? Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, lowPerf ? 1.0 : 0.95)
                        : Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, lowPerf ? 1.0 : 0.95)
                    radius: s(14)
                    border.width: lowPerf ? 0 : 1
                    border.color: lowPerf ? "transparent" : mocha.surface0

                    property bool isHovered: barHover.containsMouse
                    Behavior on color { enabled: !lowPerf; ColorAnimation { duration: 250 } }

                    MouseArea {
                        id: barHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            if (mouse.button === Qt.RightButton) {
                                statusMonitor.visible = !statusMonitor.visible
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: s(12)
                        anchors.rightMargin: s(12)
                        spacing: s(8)

                        // === CENTER: CLOCK ===
                        Item {
                            Layout.fillWidth: true
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: bar.clock
                                color: bar.fg
                                font.pixelSize: s(13)
                                font.bold: true
                            }
                        }

                        // === RIGHT: STATUS ===
                        Row {
                            id: rightStatus
                            Layout.alignment: Qt.AlignRight
                            spacing: s(12)

                            Text {
                                text: "📦 " + bar.podmanStatus
                                color: bar.podmanStatus.indexOf("Active") !== -1 ? mocha.green : bar.dimFg
                                font.pixelSize: s(11)
                            }

                            Text {
                                text: "🔒 " + bar.vpnStatus
                                color: bar.vpnStatus === "Up" ? mocha.green : mocha.red
                                font.pixelSize: s(11)
                            }

                            Text {
                                id: volumeText
                                text: "🔊 " + bar.volume + "%"
                                color: bar.fg
                                font.pixelSize: s(11)
                            }

                            Text {
                                text: "🔋 " + bar.battery
                                color: bar.fg
                                font.pixelSize: s(11)
                            }

                            Text {
                                text: bar.dateStr
                                color: bar.dimFg
                                font.pixelSize: s(10)
                            }

                        }
                    }
                }
            }
        }
    }
}