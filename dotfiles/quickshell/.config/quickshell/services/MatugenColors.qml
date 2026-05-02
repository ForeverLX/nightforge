import QtQuick 2.15
import Quickshell
import Quickshell.Io

Item {
    visible: false
    // Catppuccin Mocha fallback palette
    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#89b4fa"
    property color sapphire: "#74c7ec"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"

    property string performanceMode: "high"
    property bool blurEnabled: performanceMode === "high"
    property bool animationEnabled: performanceMode === "high"

    Process {
        id: themeReader
        command: ["cat", "/tmp/qs_colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try {
                    let c = JSON.parse(txt);
                    if (c.base) base = c.base;
                    if (c.mantle) mantle = c.mantle;
                    if (c.crust) crust = c.crust;
                    if (c.text) text = c.text;
                    if (c.subtext0) subtext0 = c.subtext0;
                    if (c.subtext1) subtext1 = c.subtext1;
                    if (c.surface0) surface0 = c.surface0;
                    if (c.surface1) surface1 = c.surface1;
                    if (c.surface2) surface2 = c.surface2;
                    if (c.overlay0) overlay0 = c.overlay0;
                    if (c.overlay1) overlay1 = c.overlay1;
                    if (c.overlay2) overlay2 = c.overlay2;
                    if (c.blue) blue = c.blue;
                    if (c.sapphire) sapphire = c.sapphire;
                    if (c.peach) peach = c.peach;
                    if (c.green) green = c.green;
                    if (c.red) red = c.red;
                    if (c.mauve) mauve = c.mauve;
                    if (c.pink) pink = c.pink;
                    if (c.yellow) yellow = c.yellow;
                    if (c.maroon) maroon = c.maroon;
                    if (c.teal) teal = c.teal;
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: themeReader.running = true
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