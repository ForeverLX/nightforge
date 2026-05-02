// Quickshell - NightForge Modular Shell Entry Point
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "modules"
import "services"

Scope {
    id: shell

    // === SERVICES ===
    MatugenColors { id: matugenColors }
    MpdClient { id: mpdClient }
    VpnStatus { id: vpnStatus }
    PodmanStatus { id: podmanStatus }

    // === MODULES ===
    Bar { id: bar }

    ControlCenter {
        id: controlCenter
        visible: false
        mpd: mpdClient
        vpn: vpnStatus
        podman: podmanStatus
    }

    MusicPopup {
        id: musicPopup
        visible: false
        mpd: mpdClient
    }

    OSD {
        id: osd
        visible: false
    }

    WallpaperPicker {
        id: wallpaperPicker
        visible: false
    }

    StatusMonitor {
        id: statusMonitor
        visible: false
    }

    // === TOGGLE SYSTEM ===
    // Reads /tmp/quickshell-toggle — keybinds write commands here.
    // 250ms polling is responsive without CPU overhead.
    Process {
        id: toggleWatcher
        command: ["sh", "-c", "[ -f /tmp/quickshell-toggle ] && content=$(head -1 /tmp/quickshell-toggle) && [ -n \"$content\" ] && > /tmp/quickshell-toggle && echo \"$content\" || echo ''"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var cmd = text.trim()
                if (cmd === "") return

                if (cmd === "controlcenter") {
                    controlCenter.visible = !controlCenter.visible
                } else if (cmd === "music") {
                    musicPopup.visible = !musicPopup.visible
                } else if (cmd === "wallpaper") {
                    wallpaperPicker.visible = !wallpaperPicker.visible
                } else if (cmd === "close") {
                    controlCenter.visible = false
                    musicPopup.visible = false
                    wallpaperPicker.visible = false
                    osd.visible = false
                    statusMonitor.visible = false
                } else if (cmd.startsWith("osd:")) {
                    var parts = cmd.split(":")
                    if (parts.length >= 4) {
                        osd.show(parts[1], parts[2], parseInt(parts[3]))
                        osd.visible = true
                        osdTimer.start()
                    }
                }
            }
        }
    }

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: toggleWatcher.running = true
    }

    Timer {
        id: osdTimer
        interval: 2000
        onTriggered: osd.visible = false
    }
}
