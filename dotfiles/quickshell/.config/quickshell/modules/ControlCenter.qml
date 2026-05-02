import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

import "../components"
import "../services"

PanelWindow {
    id: controlCenter
    visible: false
    color: "transparent"

    property var mpd
    property var vpn
    property var podman

    MatugenColors { id: mocha }

    anchors { top: true; bottom: true; right: true }
    implicitWidth: 320

    MouseArea {
        anchors.fill: parent
        onClicked: controlCenter.visible = false
    }

    GlassPanel {
        id: panel
        x: parent.width - width
        width: 320; height: parent.height
        matugen: mocha
        glassRadius: 0
        anchors.top: parent.top; anchors.bottom: parent.bottom

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 14
            spacing: 12

            // === HEADER ===
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "\u2699 Control Center"
                    color: mocha.text; font.pixelSize: 15; font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: networkState === "connected" ? "\uD83C\uDF10 Connected" : "\uD83C\uDF10 Disconnected"
                    color: networkState === "connected" ? mocha.green : mocha.red
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignRight
                }

                Rectangle {
                    width: 26; height: 26; radius: 13; color: mocha.surface0
                    Text { anchors.centerIn: parent; text: "\u2715"; color: mocha.subtext0; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; onClicked: controlCenter.visible = false }
                }
            }

            // === VOLUME ===
            VolumeSlider {
                id: volSlider
                Layout.fillWidth: true
                icon: "\uD83D\uDD0A"
                textColor: mocha.text
                primaryColor: mocha.mauve
                surfaceVariantColor: mocha.surface0
                value: volumeValue
                onChange: function(v) { setVolume(v) }
            }

            // === BRIGHTNESS ===
            VolumeSlider {
                id: brightSlider
                Layout.fillWidth: true
                icon: "\uD83D\uDD06"
                textColor: mocha.text
                primaryColor: mocha.mauve
                surfaceVariantColor: mocha.surface0
                value: brightnessValue
                onChange: function(v) { setBrightness(v) }
            }

            // === MPD CONTROLS ===
            Rectangle {
                Layout.fillWidth: true; height: 88; radius: 10
                color: mocha.surface0

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10
                    spacing: 6

                    Text {
                        text: mpd.track || "No track"
                        color: mocha.text; font.pixelSize: 13; font.bold: true
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: mpd.artist || "Unknown artist"
                        color: mocha.subtext0; font.pixelSize: 11
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 14
                        Rectangle { width: 30; height: 30; radius: 15; color: mocha.surface1
                            Text { anchors.centerIn: parent; text: "\u23EE"; color: mocha.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: mpd.prev() } }
                        Rectangle { width: 34; height: 34; radius: 17; color: mocha.mauve
                            Text { anchors.centerIn: parent; text: mpd.playing ? "\u23F8" : "\u25B6"; color: "#fff"; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; onClicked: mpd.playPause() } }
                        Rectangle { width: 30; height: 30; radius: 15; color: mocha.surface1
                            Text { anchors.centerIn: parent; text: "\u23ED"; color: mocha.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: mpd.next() } }
                    }
                }
            }

            // === MPRIS CONTROLS ===
            Rectangle {
                Layout.fillWidth: true; height: 88; radius: 10
                color: mocha.surface0
                visible: mprisDetected && (mprisStatus === "Playing" || mprisStatus === "Paused")

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10
                    spacing: 6

                    Text {
                        text: mprisTrack || "No track"
                        color: mocha.teal; font.pixelSize: 13; font.bold: true
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: mprisStatus || "Unknown"
                        color: mocha.subtext0; font.pixelSize: 11
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 14
                        Rectangle { width: 30; height: 30; radius: 15; color: mocha.surface1
                            Text { anchors.centerIn: parent; text: "\u23EE"; color: mocha.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: mprisPrev() } }
                        Rectangle { width: 34; height: 34; radius: 17; color: mocha.teal
                            Text { anchors.centerIn: parent; text: mprisStatus === "Playing" ? "\u23F8" : "\u25B6"; color: "#fff"; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; onClicked: mprisPlayPause() } }
                        Rectangle { width: 30; height: 30; radius: 15; color: mocha.surface1
                            Text { anchors.centerIn: parent; text: "\u23ED"; color: mocha.text; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: mprisNext() } }
                    }
                }
            }

            // === SYSTEM TOGGLES ===
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: 8; rowSpacing: 8

                ToggleButton { icon: "\uD83D\uDCF6"; label: wifiOn ? "WiFi" : "WiFi Off"; active: wifiOn; onClicked: toggleWifi() }
                ToggleButton { icon: "\uD83E\uDDB7"; label: btOn ? "BT" : "BT Off"; active: btOn; onClicked: toggleBluetooth() }
                ToggleButton { icon: "\uD83D\uDD12"; label: vpn.connected ? "VPN" : "VPN Off"; active: vpn.connected; onClicked: vpn.toggle() }
                ToggleButton { icon: "\uD83D\uDD15"; label: dndOn ? "DND" : "DND Off"; active: dndOn; onClicked: toggleDnd() }
                ToggleButton { icon: "\u26A1"; label: mocha.performanceMode === "high" ? "Perf" : "Save"; active: mocha.performanceMode === "high"; onClicked: togglePerformance() }
                ToggleButton { icon: powerProfile === "performance" ? "\u26A1" : "\uD83D\uDD0B"; label: powerProfile === "performance" ? "Perf" : (powerProfile === "balanced" ? "Balanced" : "Low"); active: powerProfile === "performance"; activeColor: powerProfile === "performance" ? mocha.green : (powerProfile === "balanced" ? mocha.peach : mocha.blue); onClicked: togglePowerProfile() }
            }

            // === PODMAN QUICK VIEW ===
            Text {
                text: "\uD83D\uDC0B Containers (" + podman.count + ")"
                color: mocha.text; font.pixelSize: 13; font.bold: true
            }

            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 4
                model: podman.containers

                delegate: Rectangle {
                    width: parent ? parent.width : 0; height: 34; radius: 8
                    color: mocha.surface0

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8
                        spacing: 8

                        Text {
                            text: modelData.name; color: mocha.text; font.pixelSize: 11
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.status; color: modelData.status === "running" ? mocha.green : mocha.subtext0
                            font.pixelSize: 10
                        }
                        Rectangle {
                            width: 20; height: 20; radius: 4; color: mocha.red
                            Text { anchors.centerIn: parent; text: "\u23F9"; color: "#fff"; font.pixelSize: 8 }
                            MouseArea { anchors.fill: parent; onClicked: podman.stopContainer(modelData.id) }
                        }
                    }
                }
            }
        }
    }

    // === STATE ===
    property int volumeValue: 0
    property int brightnessValue: 0
    property bool wifiOn: false
    property bool btOn: false
    property bool dndOn: false
    property string mprisStatus: ""
    property string mprisTrack: ""
    property bool mprisDetected: false
    property string powerProfile: "balanced"
    property string networkState: "unknown"

    Timer {
        interval: 2000; running: controlCenter.visible; repeat: true
        onTriggered: {
            volumePoll.running = true
            brightnessPoll.running = true
            wifiPoll.running = true
            btPoll.running = true
            dndPoll.running = true
            powerProfilePoll.running = true
        }
    }

    Timer {
        interval: 3000; running: controlCenter.visible; repeat: true
        onTriggered: { mprisStatusPoll.running = true; mprisTrackPoll.running = true }
    }

    Timer {
        interval: 5000; running: controlCenter.visible; repeat: true
        onTriggered: { networkPoll.running = true }
    }

    Process { id: volumePoll; command: ["sh","-c","pamixer --get-volume 2>/dev/null || wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.volumeValue = parseInt(text.trim()) || 0 } } }
    Process { id: brightnessPoll; command: ["sh","-c","v=$(brightnessctl g 2>/dev/null); m=$(brightnessctl m 2>/dev/null); if [ -n \"$v\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ]; then echo $(( v * 100 / m )); else echo 0; fi"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.brightnessValue = parseInt(text.trim()) || 0 } } }
    Process { id: wifiPoll; command: ["sh","-c","nmcli radio wifi 2>/dev/null | grep -q enabled && echo on || echo off"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.wifiOn = text.trim() === "on" } } }
    Process { id: btPoll; command: ["sh","-c","rfkill unblock bluetooth 2>/dev/null; bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.btOn = text.trim() === "on" } } }
    Process { id: dndPoll; command: ["cat", "/home/ForeverLX/.config/nightforge/dnd"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.dndOn = text.trim() === "1" } } }
    Process { id: mprisStatusPoll; command: ["sh","-c","playerctl -s status 2>/dev/null || echo 'No player'"]; running: false
        stdout: StdioCollector { onStreamFinished: {
            var s = text.trim()
            controlCenter.mprisDetected = s === "Playing" || s === "Paused" || s === "Stopped"
            controlCenter.mprisStatus = s === "No player" ? "" : s
        } } }
    Process { id: mprisTrackPoll; command: ["sh","-c","playerctl -s metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo ''"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.mprisTrack = text.trim() } } }
    Process { id: powerProfilePoll; command: ["cat","/sys/firmware/acpi/platform_profile"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.powerProfile = text.trim() } } }
    Process { id: networkPoll; command: ["sh","-c","nmcli -t -f STATE general 2>/dev/null | head -n1"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.networkState = text.trim() === "connected" ? "connected" : "disconnected" } } }

    function setVolume(v) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", "pamixer --set-volume " + v + " 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (v/100).toFixed(2)]
        proc.running = true
    }
    function setBrightness(v) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", "brightnessctl s " + v + "% 2>/dev/null || echo skip"]
        proc.running = true
    }
    function toggleWifi() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", wifiOn ? "nmcli radio wifi off" : "nmcli radio wifi on"]
        proc.running = true; wifiOn = !wifiOn
    }
    function toggleBluetooth() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", btOn ? "bluetoothctl power off" : "bluetoothctl power on"]
        proc.running = true; btOn = !btOn
    }
    function toggleDnd() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", dndOn ? "echo 0 > /home/ForeverLX/.config/nightforge/dnd" : "echo 1 > /home/ForeverLX/.config/nightforge/dnd"]
        proc.running = true; dndOn = !dndOn
    }
    function togglePerformance() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["bash", "/home/ForeverLX/Github/nightforge/scripts/toggle-performance-mode.sh"]
        proc.running = true
    }
    function mprisPlayPause() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["playerctl", "play-pause"]; proc.running = true
    }
    function mprisPrev() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["playerctl", "previous"]; proc.running = true
    }
    function mprisNext() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["playerctl", "next"]; proc.running = true
    }
    function togglePowerProfile() {
        var nextProfile = (powerProfile === "performance") ? "low-power" : "performance"
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", "echo " + nextProfile + " | sudo tee /sys/firmware/acpi/platform_profile >/dev/null"]
        proc.running = true; powerProfile = nextProfile
    }
}
