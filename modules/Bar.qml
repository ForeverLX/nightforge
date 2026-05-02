import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services"

Scope {
    id: barRoot

    // === NIRI IPC ===
    property var workspaces: []
    property int currentWorkspace: 1

    Process {
        id: niriWsPoll
        command: ["niri", "msg", "--json", "workspaces"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    workspaces = JSON.parse(this.text)
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: niriWsPoll.running = true
    }

    Process {
        id: niriActiveWsPoll
        command: ["niri", "msg", "--json", "active-workspace"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text)
                    currentWorkspace = data && data.id ? data.id : 1
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: niriActiveWsPoll.running = true
    }

    // === SYSTEM STATUS ===
    property string clock: ""
    property string battery: "N/A"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clock = Qt.formatDateTime(new Date(), "hh:mm")
        }
    }

    Process {
        id: batteryPoll
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = this.text.trim()
                if (txt !== "") {
                    battery = txt + "%"
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: batteryPoll.running = true
    }

    // === ENGAGEMENT CONTEXT ===
    property string engagementContext: "No active engagement"
    property bool engagementCritical: false

    Process {
        id: engagementPoll
        command: ["cat", "/home/ForeverLX/.config/nightforge/engagement-context"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var trimmed = text.trim()
                if (trimmed !== "") {
                    engagementContext = trimmed
                    var lower = trimmed.toLowerCase()
                    engagementCritical = lower.indexOf("critical") !== -1 || lower.indexOf("red") !== -1 || lower.indexOf("alert") !== -1
                } else {
                    engagementContext = "No active engagement"
                    engagementCritical = false
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: engagementPoll.running = true
    }

    // === PERFORMANCE MODE ===
    property string performanceMode: "high"

    Process {
        id: perfPoll
        command: ["cat", "/home/ForeverLX/.config/nightforge/performance-mode"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = text.trim()
                performanceMode = txt === "low" ? "low" : "high"
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: perfPoll.running = true
    }

    function togglePerformanceMode() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { running: true }', barRoot)
        proc.command = ["bash", "/home/ForeverLX/Github/nightforge/scripts/toggle-performance-mode.sh"]
        proc.running = true
    }

    function editEngagement() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { running: true }', barRoot)
        proc.command = ["bash", "/home/ForeverLX/Github/nightforge/scripts/engagement-edit.sh"]
        proc.running = true
    }

    // === BAR LAYOUT ===
    PanelWindow {
        id: bar
        visible: true
        implicitHeight: MatugenColors.performanceMode === "low" ? 28 : 32
        color: MatugenColors.surface

        anchors {
            top: true
            left: true
            right: true
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: MatugenColors.outline
        }

        RowLayout {
            anchors.fill: parent
            spacing: MatugenColors.performanceMode === "low" ? 4 : 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 1

            // === LEFT: WORKSPACES ===
            Row {
                Layout.alignment: Qt.AlignLeft
                spacing: 4

                Repeater {
                    model: [1, 2, 3, 4, 5]
                    delegate: Rectangle {
                        width: 22
                        height: 22
                        radius: 4
                        color: modelData === currentWorkspace ? MatugenColors.primary : "transparent"
                        border.color: MatugenColors.outline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: modelData === currentWorkspace ? MatugenColors.surfaceText : MatugenColors.outline
                            font.pixelSize: 11
                            font.bold: modelData === currentWorkspace
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', barRoot)
                                proc.command = ["niri", "msg", "action", "focus-workspace", modelData.toString()]
                                proc.running = true
                            }
                        }
                    }
                }
            }

            // === CENTER: CLOCK ===
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: clock
                color: MatugenColors.surfaceText
                font.pixelSize: 13
                font.bold: true
            }

            // === RIGHT: STATUS INDICATORS ===
            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 12

                // Performance mode indicator
                Text {
                    text: performanceMode === "high" ? "\ud83d\ude80 High" : "\ud83d\udc22 Low"
                    color: performanceMode === "high" ? MatugenColors.tertiary : MatugenColors.error
                    font.pixelSize: 11

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: togglePerformanceMode()
                    }
                }

                // Engagement context
                Text {
                    width: 160
                    text: "ENG: " + engagementContext
                    color: engagementCritical ? MatugenColors.error : MatugenColors.tertiary
                    font.pixelSize: 11
                    elide: Text.ElideRight

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editEngagement()
                    }
                }

                // MPD status
                Text {
                    text: (MpdClient.playing ? "\u25b6 " : "\u23f8 ") + (MpdClient.artist || MpdClient.track ? MpdClient.artist + " - " + MpdClient.track : "No music")
                    color: MpdClient.playing ? MatugenColors.secondary : MatugenColors.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: 140

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MpdClient.playing ? MpdClient.pause() : MpdClient.play()
                    }
                }

                // Podman status
                Text {
                    text: "\ud83d\udce6 " + (PodmanStatus.count > 0 ? "Active (" + PodmanStatus.count + ")" : "Down")
                    color: PodmanStatus.count > 0 ? "#4ade80" : MatugenColors.outline
                    font.pixelSize: 11
                }

                // VPN status
                Text {
                    text: "\ud83d\udd12 " + VpnStatus.statusText
                    color: VpnStatus.connected ? "#4ade80" : MatugenColors.error
                    font.pixelSize: 11

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VpnStatus.toggle()
                    }
                }

                // Battery
                Text {
                    text: "\ud83d\udd0b " + battery
                    color: MatugenColors.surfaceText
                    font.pixelSize: 11
                }

                // Date
                Text {
                    text: Qt.formatDateTime(new Date(), "yyyy-MM-dd")
                    color: MatugenColors.outline
                    font.pixelSize: 10
                }
            }
        }
    }
}
