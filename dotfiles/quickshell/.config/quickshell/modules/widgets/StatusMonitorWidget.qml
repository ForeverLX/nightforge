import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../../components"
import "../../services"

Item {
    id: statusMonitor
    property string widgetName: "statusmonitor"

    implicitWidth: 520
    implicitHeight: 600

    MatugenColors { id: mocha }

    property bool fullMode: false
    property real cpuPercent: 0
    property real ramPercent: 0
    property real tempCelsius: 0
    property string diskUsage: "--"
    property string uptimeStr: "--"
    property var prevCpuStats: []
    property bool cpuInitialized: false
    property int activeTab: 0

    property var containers: []

    function parseMeminfo(text) {
        var lines = text.split("\n")
        var total = 0; var available = 0
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("MemTotal:") === 0) total = parseInt(line.replace(/\D/g, "")) || 1
            else if (line.indexOf("MemAvailable:") === 0) available = parseInt(line.replace(/\D/g, "")) || 0
        }
        if (total > 0) ramPercent = 100 * (total - available) / total
    }

    function parseCpuStat(text) {
        var lines = text.split("\n")
        if (lines.length === 0) return
        var parts = lines[0].trim().split(/\s+/)
        if (parts.length < 8 || parts[0] !== "cpu") return
        var values = []; var total = 0
        for (var i = 1; i < parts.length; i++) { var v = parseInt(parts[i]) || 0; values.push(v); total += v }
        if (cpuInitialized && prevCpuStats.length === values.length) {
            var prevTotal = 0
            for (var j = 0; j < prevCpuStats.length; j++) prevTotal += prevCpuStats[j]
            var deltaTotal = total - prevTotal
            var idle = values[3] + (values[4] || 0)
            var prevIdle = prevCpuStats[3] + (prevCpuStats[4] || 0)
            var deltaIdle = idle - prevIdle
            if (deltaTotal > 0) cpuPercent = Math.round(100 * (deltaTotal - deltaIdle) / deltaTotal)
        } else { cpuInitialized = true }
        prevCpuStats = values
    }

    function parseTemp(text) {
        var val = parseInt(text.trim())
        if (!isNaN(val)) tempCelsius = Math.round(val / 1000)
    }

    function parseDisk(text) { var txt = text.trim(); if (txt !== "") diskUsage = txt }
    function parseUptime(text) {
        var seconds = parseFloat(text.trim().split(" ")[0]) || 0
        var days = Math.floor(seconds / 86400); var hours = Math.floor((seconds % 86400) / 3600); var mins = Math.floor((seconds % 3600) / 60)
        uptimeStr = days + "d " + hours + "h " + mins + "m"
    }

    function parseContainers(text) {
        try {
            var lines = text.trim().split("\n")
            var result = []
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].trim().split(/\s+/)
                if (parts.length >= 2) {
                    result.push({ id: parts[0], name: parts[1], status: parts[2] || "unknown" })
                }
            }
            containers = result
        } catch(e) { containers = [] }
    }

    Process { id: cpuPoll; command: ["cat", "/proc/stat"]; running: true
        stdout: StdioCollector { onStreamFinished: parseCpuStat(text) } }
    Process { id: memPoll; command: ["cat", "/proc/meminfo"]; running: true
        stdout: StdioCollector { onStreamFinished: parseMeminfo(text) } }
    Process { id: tempPoll; command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1"]; running: true
        stdout: StdioCollector { onStreamFinished: parseTemp(text) } }
    Process { id: diskPoll; command: ["sh", "-c", "df -h / | tail -1 | awk '{print $5}'"]; running: true
        stdout: StdioCollector { onStreamFinished: parseDisk(text) } }
    Process { id: uptimePoll; command: ["cat", "/proc/uptime"]; running: true
        stdout: StdioCollector { onStreamFinished: parseUptime(text) } }
    Process { id: containerPoll; command: ["sh", "-c", "podman ps --format '{{.ID}} {{.Names}} {{.Status}}' 2>/dev/null || echo ''"]; running: true
        stdout: StdioCollector { onStreamFinished: parseContainers(text) } }

    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: {
            cpuPoll.running = false; cpuPoll.running = true
            memPoll.running = false; memPoll.running = true
            tempPoll.running = false; tempPoll.running = true
            diskPoll.running = false; diskPoll.running = true
            uptimePoll.running = false; uptimePoll.running = true
            containerPoll.running = false; containerPoll.running = true
        }
    }

    GlassPanel {
        anchors.fill: parent
        matugen: mocha
        glassRadius: 20

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header with tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: ["System", "Containers", "Sessions"]
                    delegate: Rectangle {
                        height: 30
                        radius: 8
                        color: statusMonitor.activeTab === index
                            ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.3)
                            : mocha.surface0

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: statusMonitor.activeTab === index ? mocha.mauve : mocha.text
                            font.pixelSize: 12
                            font.bold: statusMonitor.activeTab === index
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: statusMonitor.activeTab = index
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 60; height: 22; radius: 4; color: mocha.surface0
                    Text { anchors.centerIn: parent; text: fullMode ? "Full" : "Min"; color: mocha.text; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: fullMode = !fullMode }
                }
            }

            // === SYSTEM TAB ===
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                visible: activeTab === 0

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "CPU: " + cpuPercent + "%"; color: mocha.text; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: mocha.surface0
                        Rectangle {
                            width: parent.width * (cpuPercent / 100)
                            height: parent.height
                            radius: 3
                            color: cpuPercent > 80 ? mocha.red : (cpuPercent > 50 ? mocha.peach : mocha.green)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "RAM: " + Math.round(ramPercent) + "%"; color: mocha.text; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: mocha.surface0
                        Rectangle {
                            width: parent.width * (ramPercent / 100)
                            height: parent.height
                            radius: 3
                            color: ramPercent > 80 ? mocha.red : (ramPercent > 50 ? mocha.peach : mocha.green)
                        }
                    }
                }

                Text {
                    text: "Temp: " + tempCelsius + "\u00B0C"
                    color: tempCelsius > 75 ? mocha.red : (tempCelsius > 60 ? mocha.peach : mocha.teal)
                    font.pixelSize: 11
                }

                ColumnLayout {
                    visible: fullMode
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Disk (/): " + diskUsage; color: mocha.text; font.pixelSize: 11 }
                    Text { text: "Uptime: " + uptimeStr; color: mocha.subtext0; font.pixelSize: 11 }
                }
            }

            // === CONTAINERS TAB ===
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                visible: activeTab === 1

                Text {
                    text: "Active Containers (" + containers.length + ")"
                    color: mocha.text
                    font.pixelSize: 13
                    font.bold: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: containers

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 36
                        radius: 8
                        color: mocha.surface0

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                text: modelData.name
                                color: mocha.text
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.status
                                color: modelData.status.indexOf("Up") === 0 ? mocha.green : mocha.subtext0
                                font.pixelSize: 10
                            }
                            Text {
                                text: modelData.id.substring(0, 8)
                                color: mocha.overlay0
                                font.pixelSize: 9
                                font.family: "monospace"
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No containers running"
                        color: mocha.subtext0
                        font.pixelSize: 12
                        visible: parent.count === 0
                    }
                }
            }

            // === SESSIONS TAB ===
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                visible: activeTab === 2

                Text {
                    text: "Agent Sessions"
                    color: mocha.text
                    font.pixelSize: 13
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: mocha.surface0

                    Text {
                        anchors.centerIn: parent
                        text: "No active sessions"
                        color: mocha.subtext0
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
