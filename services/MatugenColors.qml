pragma Singleton
import QtQuick 2.15
import Quickshell
import Quickshell.Io

QtObject {
    // Fallback colors (NightForge dark palette)
    property color primary: "#2a2a3e"
    property color surface: "#1a1a2e"
    property color onSurface: "#c0c0d0"
    property color outline: "#3a3a4e"
    property color surfaceVariant: "#2e2e42"
    property color error: "#f87171"
    property color secondary: "#4a4a6e"
    property color tertiary: "#6a6a8e"

    property string performanceMode: "high"

    Process {
        id: colorsPoll
        command: ["cat", "/tmp/matugen/colors.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (parsed && parsed.colors) {
                        var c = parsed.colors
                        if (c.primary) primary = c.primary
                        if (c.surface) surface = c.surface
                        if (c.surfaceText) onSurface = c.surfaceText
                        if (c.outline) outline = c.outline
                        if (c.surfaceVariant) surfaceVariant = c.surfaceVariant
                        if (c.error) error = c.error
                        if (c.secondary) secondary = c.secondary
                        if (c.tertiary) tertiary = c.tertiary
                    }
                } catch(e) {
                    console.log("MatugenColors parse error:", e)
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: colorsPoll.running = true
    }

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
}
