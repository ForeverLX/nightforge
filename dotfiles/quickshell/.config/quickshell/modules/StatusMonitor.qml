import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../services"
import "../components"

PanelWindow {
    id: statusMonitor
    visible: false
    color: "transparent"

    anchors { top: true; left: true; right: true; bottom: true }

    MatugenColors { id: mocha }

    property bool fullMode: false
    property real cpuPercent: 0
    property real ramPercent: 0
    property real tempCelsius: 0
    property string diskUsage: "--"
    property string uptimeStr: "--"

    property var prevCpuStats: []
    property bool cpuInitialized: false

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

    Timer {
        interval: 3000; running: statusMonitor.visible; repeat: true
        onTriggered: {
            cpuPoll.running = false; cpuPoll.running = true
            memPoll.running = false; memPoll.running = true
            tempPoll.running = false; tempPoll.running = true
            if (fullMode) { diskPoll.running = false; diskPoll.running = true; uptimePoll.running = false; uptimePoll.running = true }
        }
    }

    onVisibleChanged: {
        if (visible) {
            cpuPoll.running = false; cpuPoll.running = true
            memPoll.running = false; memPoll.running = true
            tempPoll.running = false; tempPoll.running = true
            if (fullMode) { diskPoll.running = false; diskPoll.running = true; uptimePoll.running = false; uptimePoll.running = true }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: statusMonitor.visible = false
    }

    GlassPanel {
        anchors.centerIn: parent
        width: 300; height: contentLayout.implicitHeight + 28
        matugen: mocha
        glassRadius: 14

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent; anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "System Monitor"; color: mocha.text; font.pixelSize: 14; font.bold: true }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 60; height: 22; radius: 4; color: mocha.surface0
                    Text { anchors.centerIn: parent; text: fullMode ? "Full" : "Min"; color: mocha.text; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: fullMode = !fullMode }
                }
                Text { text: "\u2715"; color: mocha.subtext0; font.pixelSize: 14
                    MouseArea { anchors.fill: parent; onClicked: statusMonitor.visible = false } }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "CPU: " + cpuPercent + "%"; color: mocha.text; font.pixelSize: 11 }
                Rectangle { Layout.fillWidth: true; height: 6; radius: 3; color: mocha.surface0
                    Rectangle {
                        width: parent.width * (cpuPercent / 100); height: parent.height; radius: 3
                        color: cpuPercent > 80 ? mocha.red : (cpuPercent > 50 ? mocha.peach : mocha.green)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "RAM: " + Math.round(ramPercent) + "%"; color: mocha.text; font.pixelSize: 11 }
                Rectangle { Layout.fillWidth: true; height: 6; radius: 3; color: mocha.surface0
                    Rectangle {
                        width: parent.width * (ramPercent / 100); height: parent.height; radius: 3
                        color: ramPercent > 80 ? mocha.red : (ramPercent > 50 ? mocha.peach : mocha.green)
                    }
                }
            }

            Text {
                text: "Temp: " + tempCelsius + "\u00B0C"; color: tempCelsius > 75 ? mocha.red : (tempCelsius > 60 ? mocha.peach : mocha.teal)
                font.pixelSize: 11
            }

            ColumnLayout {
                visible: fullMode; Layout.fillWidth: true; spacing: 8
                Text { text: "Disk (/): " + diskUsage; color: mocha.text; font.pixelSize: 11 }
                Text { text: "Uptime: " + uptimeStr; color: mocha.subtext0; font.pixelSize: 11 }
            }
        }
    }
}
