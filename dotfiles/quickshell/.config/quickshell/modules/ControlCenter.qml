// ControlCenter Module - Slide-out panel with volume, brightness, MPD, toggles, podman
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

    anchors {
        top: true
        bottom: true
        right: true
    }

    implicitWidth: 320

    // Fullscreen click-catcher to close when clicking outside
    Rectangle {
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: 320
        color: mocha ? mocha.mantle : "#1a1a2e"
        border.color: mocha ? mocha.surface0 : "#3a3a4e"
        border.width: 1

        // Close on click outside the panel area is handled by the window losing focus
        // But we also want Esc or a close button
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            // === HEADER ===
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "⚙ Control Center"
                    color: mocha ? mocha.text : "#c0c0d0"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: networkState === "connected" ? "🌐 Connected" : "🌐 Disconnected"
                    color: networkState === "connected" ? "#4ade80" : "#f87171"
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignRight
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: mocha ? mocha.surface1 : "#2e2e42"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: mocha ? mocha.text : "#c0c0d0"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: controlCenter.visible = false
                    }
                }
            }

            // === VOLUME ===
            VolumeSlider {
                id: volSlider
                Layout.fillWidth: true
                icon: "🔊"
                textColor: mocha ? mocha.text : "#c0c0d0"
                primaryColor: mocha ? mocha.mauve : "#2a2a3e"
                surfaceVariantColor: mocha ? mocha.surface1 : "#2e2e42"
                value: volumeValue
                onChange: function(v) {
                    setVolume(v)
                }
            }

            // === BRIGHTNESS ===
            VolumeSlider {
                id: brightSlider
                Layout.fillWidth: true
                icon: "🔆"
                textColor: mocha ? mocha.text : "#c0c0d0"
                primaryColor: mocha ? mocha.mauve : "#2a2a3e"
                surfaceVariantColor: mocha ? mocha.surface1 : "#2e2e42"
                value: brightnessValue
                onChange: function(v) {
                    setBrightness(v)
                }
            }

            // === MPD CONTROLS ===
            Rectangle {
                Layout.fillWidth: true
                height: 100
                radius: 12
                color: mocha ? mocha.surface1 : "#2e2e42"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: mpd.track || "No track"
                        color: mocha ? mocha.text : "#c0c0d0"
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: mpd.artist || "Unknown artist"
                        color: mocha ? mocha.surface0 : "#3a3a4e"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: mocha ? mocha.mauve : "#2a2a3e"
                            Text { anchors.centerIn: parent; text: "⏮"; color: "#fff"; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: mpd.prev() }
                        }

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: mocha ? mocha.mauve : "#2a2a3e"
                            Text { anchors.centerIn: parent; text: mpd.playing ? "⏸" : "▶"; color: "#fff"; font.pixelSize: 14 }
                            MouseArea { anchors.fill: parent; onClicked: mpd.playPause() }
                        }

                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: mocha ? mocha.mauve : "#2a2a3e"
                            Text { anchors.centerIn: parent; text: "⏭"; color: "#fff"; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: mpd.next() }
                        }
                    }
                }
            }

            // === MPRIS CONTROLS ===
            Rectangle {
                Layout.fillWidth: true
                height: 100
                radius: 12
                color: mocha ? mocha.surface1 : "#2e2e42"
                visible: mprisDetected && (mprisStatus === "Playing" || mprisStatus === "Paused")

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: mprisTrack || "No track"
                        color: mocha ? mocha.teal : "#2a9d8f"
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: mprisStatus || "Unknown"
                        color: mocha ? mocha.surface0 : "#3a3a4e"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: mocha ? mocha.teal : "#2a9d8f"
                            Text { anchors.centerIn: parent; text: "⏮"; color: "#fff"; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: mprisPrev() }
                        }

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: mocha ? mocha.teal : "#2a9d8f"
                            Text { anchors.centerIn: parent; text: mprisStatus === "Playing" ? "⏸" : "▶"; color: "#fff"; font.pixelSize: 14 }
                            MouseArea { anchors.fill: parent; onClicked: mprisPlayPause() }
                        }

                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: mocha ? mocha.teal : "#2a9d8f"
                            Text { anchors.centerIn: parent; text: "⏭"; color: "#fff"; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: mprisNext() }
                        }
                    }
                }
            }

            // === SYSTEM TOGGLES ===
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 8

                ToggleButton {
                    icon: "📶"
                    label: wifiOn ? "WiFi" : "WiFi Off"
                    active: wifiOn
                    onClicked: toggleWifi()
                }

                ToggleButton {
                    icon: "🦷"
                    label: btOn ? "BT" : "BT Off"
                    active: btOn
                    onClicked: toggleBluetooth()
                }

                ToggleButton {
                    icon: "🔒"
                    label: vpn.connected ? "VPN" : "VPN Off"
                    active: vpn.connected
                    onClicked: vpn.toggle()
                }

                ToggleButton {
                    icon: "🔕"
                    label: dndOn ? "DND" : "DND Off"
                    active: dndOn
                    onClicked: toggleDnd()
                }

                ToggleButton {
                    icon: "⚡"
                    label: mocha.performanceMode === "high" ? "Perf" : "Save"
                    active: mocha.performanceMode === "high"
                    onClicked: togglePerformance()
                }

                ToggleButton {
                    icon: powerProfile === "performance" ? "⚡" : "🔋"
                    label: powerProfile === "performance" ? "Perf" : (powerProfile === "balanced" ? "Balanced" : "Low")
                    active: powerProfile === "performance"
                    activeColor: powerProfile === "performance" ? "#4ade80" : (powerProfile === "balanced" ? "#facc15" : "#60a5fa")
                    onClicked: togglePowerProfile()
                }
            }

            // === PODMAN QUICK VIEW ===
            Text {
                text: "🐋 Containers (" + podman.count + ")"
                color: mocha ? mocha.text : "#c0c0d0"
                font.pixelSize: 13
                font.bold: true
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: podman.containers

                delegate: Rectangle {
                    width: parent ? parent.width : 0
                    height: 36
                    radius: 8
                    color: mocha ? mocha.surface1 : "#2e2e42"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: modelData.name
                            color: mocha ? mocha.text : "#c0c0d0"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.status
                            color: modelData.status === "running" ? "#4ade80" : (mocha ? mocha.surface0 : "#3a3a4e")
                            font.pixelSize: 10
                        }

                        Rectangle {
                            width: 20; height: 20; radius: 4
                            color: mocha ? mocha.red : "#f87171"
                            Text { anchors.centerIn: parent; text: "⏹"; color: "#fff"; font.pixelSize: 8 }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: podman.stopContainer(modelData.id)
                            }
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

    // === POLLING ===
    Timer {
        interval: 2000
        running: controlCenter.visible
        repeat: true
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
        interval: 3000
        running: controlCenter.visible
        repeat: true
        onTriggered: {
            mprisStatusPoll.running = true
            mprisTrackPoll.running = true
        }
    }

    Timer {
        interval: 5000
        running: controlCenter.visible
        repeat: true
        onTriggered: {
            networkPoll.running = true
        }
    }

    Process { id: volumePoll; command: ["sh","-c","pamixer --get-volume 2>/dev/null || wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}'"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.volumeValue = parseInt(text.trim()) || 0 } }
    }
    Process { id: brightnessPoll; command: ["sh","-c","v=$(brightnessctl g 2>/dev/null); m=$(brightnessctl m 2>/dev/null); if [ -n \"$v\" ] && [ -n \"$m\" ] && [ \"$m\" -gt 0 ]; then echo $(( v * 100 / m )); else echo 0; fi"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.brightnessValue = parseInt(text.trim()) || 0 } }
    }
    Process { id: wifiPoll; command: ["sh","-c","nmcli radio wifi 2>/dev/null | grep -q enabled && echo on || echo off"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.wifiOn = text.trim() === "on" } }
    }
    Process { id: btPoll; command: ["sh","-c","rfkill unblock bluetooth 2>/dev/null; bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.btOn = text.trim() === "on" } }
    }
    Process { id: dndPoll; command: ["cat", "/home/ForeverLX/.config/nightforge/dnd"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.dndOn = text.trim() === "1" } }
    }
    Process { id: mprisStatusPoll; command: ["sh","-c","playerctl -s status 2>/dev/null || echo 'No player'"]; running: false
        stdout: StdioCollector { onStreamFinished: {
            var s = text.trim()
            controlCenter.mprisDetected = s === "Playing" || s === "Paused" || s === "Stopped"
            controlCenter.mprisStatus = s === "No player" ? "" : s
        } }
    }
    Process { id: mprisTrackPoll; command: ["sh","-c","playerctl -s metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo ''"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.mprisTrack = text.trim() } }
    }
    Process { id: powerProfilePoll; command: ["cat","/sys/firmware/acpi/platform_profile"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.powerProfile = text.trim() } }
    }
    Process { id: networkPoll; command: ["sh","-c","nmcli -t -f STATE general 2>/dev/null | head -n1"]; running: false
        stdout: StdioCollector { onStreamFinished: { controlCenter.networkState = text.trim() === "connected" ? "connected" : "disconnected" } }
    }

    // === ACTIONS ===
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
        proc.running = true
        wifiOn = !wifiOn
    }

    function toggleBluetooth() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", btOn ? "bluetoothctl power off" : "bluetoothctl power on"]
        proc.running = true
        btOn = !btOn
    }

    function toggleDnd() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", dndOn ? "echo 0 > /home/ForeverLX/.config/nightforge/dnd" : "echo 1 > /home/ForeverLX/.config/nightforge/dnd"]
        proc.running = true
        dndOn = !dndOn
    }

    function togglePerformance() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["bash", "/home/ForeverLX/Github/nightforge/scripts/toggle-performance-mode.sh"]
        proc.running = true
    }

    function mprisPlayPause() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["playerctl", "play-pause"]
        proc.running = true
    }

    function mprisPrev() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["playerctl", "previous"]
        proc.running = true
    }

    function mprisNext() {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["playerctl", "next"]
        proc.running = true
    }

    function togglePowerProfile() {
        var nextProfile = (powerProfile === "performance") ? "low-power" : "performance"
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', controlCenter)
        proc.command = ["sh", "-c", "echo " + nextProfile + " | sudo tee /sys/firmware/acpi/platform_profile >/dev/null"]
        proc.running = true
        powerProfile = nextProfile
    }
}
