// WallpaperWidget — transparent overlay wallpaper grid
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    implicitWidth: 840; implicitHeight: 600
    exclusiveZone: 0; color: "transparent"; visible: false

    // ---- colors ----
    property color cBase: "#0d0f1a"
    property color cText: "#cdd6f4"
    property color cSubtext0: "#a6adc8"
    property color cMauve: "#8B6FEF"
    property color cSurface0: "#313244"
    property color cOverlay0: "#6c7086"
    function a(c,a){return Qt.rgba(c.r,c.g,c.b,a)}

    MatugenColors {
        id: theme
        onBaseChanged:if(base)root.cBase=base
        onTextChanged:if(text)root.cText=text
        onMauveChanged:if(mauve)root.cMauve=mauve
        onSubtext0Changed:if(subtext0)root.cSubtext0=subtext0
        onSurface0Changed:if(surface0)root.cSurface0=surface0
        onOverlay0Changed:if(overlay0)root.cOverlay0=overlay0
    }

    // ---- data ----
    readonly property string wallpaperDir: "/home/ForeverLX/Pictures/wallpapers"
    readonly property string cacheDir: "/home/ForeverLX/.cache/qs-wallpapers"
    property var wallpapers: []
    property string currentWallpaper: ""
    property string lastIpcMsg: ""
    property bool scanned: false

    // ---- IPC toggle ----
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: { ipcPoll.running = false; ipcPoll.running = true }
    }
    Process {
        id: ipcPoll
        command: ["cat", "/tmp/qs_wallpaper_state"]
        stdout: StdioCollector {
            onStreamFinished: {
                var msg = text.trim()
                if (!msg || msg === root.lastIpcMsg) return
                root.lastIpcMsg = msg
                if (msg === "toggle") root.visible = !root.visible
                else if (msg === "open") root.visible = true
                else if (msg === "close") root.visible = false
                clearIpc.running = true
            }
        }
    }
    Process { id: clearIpc; command: ["sh", "-c", ": > /tmp/qs_wallpaper_state"]; running: false }

    // ---- scan wallpapers with bash glob (no find escaping issues) ----
    Process {
        id: wallScan
        running: false
        command: [
            "bash", "-c",
            "shopt -s nullglob; cd " + root.wallpaperDir + " && " +
            "for f in *.jpg *.jpeg *.png *.webp *.bmp; do " +
            "  name=\"${f%.*}\"; " +
            "  thumb=\"" + root.cacheDir + "/${name}.png\"; " +
            "  echo \"$PWD/$f|$thumb|$name\"; " +
            "done | sort"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()
                if (!raw) { root.scanned = true; return }
                root.wallpapers = []
                var lines = raw.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|")
                    if (parts.length >= 3)
                        root.wallpapers.push({ orig: parts[0], thumb: parts[1], name: parts[2] })
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                root.scanned = true
                curPoll.running = true
            }
        }
    }
    Process {
        id: curPoll
        command: ["cat", "/tmp/qs_current_wallpaper"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { root.currentWallpaper = text.trim() }
        }
    }

    // ---- set wallpaper ----
    function setWallpaper(path) {
        if (!path) return
        root.currentWallpaper = path
        var safe = path.replace(/'/g, "'\\''")
        var cmd = "printf '%s\\n' '" + safe + "' > /tmp/qs_current_wallpaper && " +
                  "awww img '" + safe + "' --transition-type none 2>/dev/null && " +
                  "~/.local/bin/matugen-sync.sh '" + safe + "' 2>/dev/null"
        setProc.command = ["sh", "-c", cmd]
        setProc.running = true
    }
    Process { id: setProc; running: false; stdout: StdioCollector { onStreamFinished: {} } }

    function randomWallpaper() {
        if (wallpapers.length === 0) return
        setWallpaper(wallpapers[Math.floor(Math.random() * wallpapers.length)].orig)
    }

    // ---- close ----
    Shortcut { sequence: "Escape"; onActivated: root.visible = false }

    // ---- backdrop (semi-transparent, rounded at bottom) ----
    Rectangle {
        anchors.fill: parent; radius: 12
        color: a(cBase, 0.85)
        border.width: 1; border.color: a(cMauve, 0.12)
    }

    // ---- content ----
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 12

        // Header — centered row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Wallpaper count
            Text {
                text: root.scanned ? wallpapers.length + "" : ""
                color: cSubtext0; font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Wallpapers"
                color: cText; font.pixelSize: 20; font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillWidth: true }

            // Dice / Random
            Rectangle {
                width: 32; height: 32; radius: 8
                color: a(cMauve, 0.12)
                Text { anchors.centerIn: parent; text: "🎲"; font.pixelSize: 16 }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: parent.color = a(cMauve, 0.3)
                    onExited: parent.color = a(cMauve, 0.12)
                    onClicked: root.randomWallpaper()
                }
            }

            // Close button
            Rectangle {
                width: 28; height: 28; radius: 7
                color: a(cMauve, 0.12)
                Text { anchors.centerIn: parent; text: "✕"; color: cText; font.pixelSize: 13 }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: parent.color = a(cMauve, 0.3)
                    onExited: parent.color = a(cMauve, 0.12)
                    onClicked: root.visible = false
                }
            }
        }

        // Loading / empty state
        Text {
            Layout.alignment: Qt.AlignHCenter; Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            visible: !root.scanned || wallpapers.length === 0
            text: root.scanned ? "No wallpapers found" : "Scanning..."
            color: cSubtext0; font.pixelSize: 14
        }

        // Thumbnail grid
        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: grid.width; contentHeight: grid.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            visible: root.scanned && wallpapers.length > 0

            Grid {
                id: grid
                columns: Math.max(1, Math.floor(parent.width / 175))
                spacing: 8

                Repeater {
                    model: root.wallpapers
                    delegate: Component {
                        Item {
                            width: 164; height: 140
                            property bool isActive: modelData.orig === root.currentWallpaper

                            Rectangle {
                                anchors.fill: parent; radius: 10
                                color: a(cBase, 0.6)
                                border.width: isActive ? 2 : 1
                                border.color: isActive ? cMauve : a(cOverlay0, 0.2)

                                Image {
                                    anchors.fill: parent; anchors.margins: 3
                                    asynchronous: true; cache: true
                                    source: "file://" + modelData.thumb
                                    fillMode: Image.PreserveAspectCrop
                                }

                                // Active dot
                                Rectangle {
                                    anchors.top: parent.top; anchors.right: parent.right
                                    anchors.margins: 5
                                    width: 14; height: 14; radius: 7
                                    visible: isActive
                                    color: cMauve
                                }

                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true
                                    onClicked: root.setWallpaper(modelData.orig)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: wallScan.running = true
}
