import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../services"
import "../WindowRegistry.js" as LayoutMath

PanelWindow {
    id: menu

    anchors.top: true; anchors.left: true; anchors.right: true; anchors.bottom: true
    color: "transparent"
    visible: false

    MatugenColors { id: mocha }

    readonly property string wallpaperDir: "/home/ForeverLX/Pictures/wallpapers"
    readonly property string cacheDir:     "/home/ForeverLX/.cache/qs-wallpapers"
    property var    wallpapers: []
    property var    _buf: []
    property string currentWall: ""
    property string previewPath: ""
    property string previewName: ""

    onVisibleChanged: {
        if (!visible) return
        menu._buf = []
        menu.wallpapers = []
        mkCache.running = false
        mkCache.running = true
    }

    Process {
        id: mkCache
        command: ["mkdir", "-p", menu.cacheDir]
        running: false
        onRunningChanged: if (!running) { wallScan.running = false; wallScan.running = true }
    }

    Process {
        id: wallScan
        command: ["sh", "-c",
            "find \"" + menu.wallpaperDir + "\" -maxdepth 2 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " +
            "-o -iname '*.webp' -o -iname '*.bmp' \\) | sort | while read f; do " +
            "  base=$(basename \"$f\"); " +
            "  thumb=\"" + menu.cacheDir + "/${base%.*}.png\"; " +
            "  [ -f \"$thumb\" ] || magick \"$f\" -resize 260x200^ -gravity center -extent 260x200 \"$thumb\" 2>/dev/null; " +
            "  [ -f \"$thumb\" ] && echo \"$f|$thumb|$base\"; " +
            "done"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                var parts = line.split("|")
                if (parts.length < 2) return
                var b = menu._buf.slice()
                b.push({ orig: parts[0], thumb: parts[1], name: parts[2] })
                menu._buf = b
                menu.wallpapers = b
            }
        }
        onRunningChanged: if (!running) { queryCurrent.running = false; queryCurrent.running = true }
    }

    Process {
        id: queryCurrent
        command: ["cat", "/home/ForeverLX/.cache/current_wallpaper"]
        running: false
        stdout: StdioCollector { onStreamFinished: { menu.currentWall = text.trim() } }
    }

    function setWallpaper(path) {
        menu.currentWall = path
        var awwwProc = Qt.createQmlObject('import Quickshell.Io; Process {}', menu)
        awwwProc.command = ["sh", "-c", "awww img '" + path + "' --transition-type wipe --transition-duration 1 && echo '" + path + "' > /home/ForeverLX/.cache/current_wallpaper"]
        awwwProc.running = true
        var matugenProc = Qt.createQmlObject('import Quickshell.Io; Process {}', menu)
        matugenProc.command = ["bash", "/home/ForeverLX/.local/bin/matugen-sync.sh", path]
        matugenProc.running = true
        menu.visible = false
    }

    MouseArea { anchors.fill: parent; onClicked: menu.visible = false }

    Rectangle {
        anchors.centerIn: parent

        property var layoutInfo: LayoutMath.getLayoutSimple(Screen.width, Screen.height, "wallpaper")
        width: layoutInfo ? layoutInfo.w : 820
        height: layoutInfo ? layoutInfo.h : 620
        radius: 14
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)

        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent; anchors.margins: 20; spacing: 14

            // Header
            Item { width: parent.width; height: 28
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "󰋩 Wallpaper"; color: mocha.mauve; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; font.bold: true
                }
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14; color: mocha.surface1
                    Text { anchors.centerIn: parent; text: "󰅖"; color: mocha.subtext0; font.family: "Iosevka Nerd Font"; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: menu.visible = false }
                }
            }

            // Thumbnail grid
            Rectangle {
                width: parent.width; height: 566; radius: 12; color: "transparent"; clip: true

                Flickable {
                    id: flick
                    anchors.fill: parent; anchors.margins: 6
                    contentWidth: width
                    contentHeight: grid.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    leftMargin: 4; rightMargin: 4

                    WheelHandler {
                        orientation: Qt.Vertical
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        rotationScale: -5
                        target: flick
                        property: "contentY"
                    }

                    Grid {
                        id: grid
                        width: parent.width
                        columns: Math.max(1, Math.floor(width / 172))
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: menu.wallpapers

                            Item {
                                id: card
                                required property var modelData
                                readonly property bool active: menu.currentWall === modelData.orig

                                width: 164; height: 120

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7; clip: true; color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + card.modelData.thumb
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }
                                }

                                // Hover glow / selection border
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: "transparent"
                                    border.width: card.active ? 3 : (ma.containsMouse ? 2 : 0)
                                    border.color: card.active ? mocha.mauve : (ma.containsMouse ? mocha.mauve : "transparent")
                                    Behavior on border.width { NumberAnimation { duration: 150 } }
                                }

                                Rectangle {
                                    visible: card.active
                                    width: 10; height: 10; radius: 5
                                    color: mocha.mauve
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.margins: 7
                                }

                                Text {
                                    visible: card.active
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.margins: 7
                                    text: modelData.name
                                    color: mocha.text
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    width: parent.width - 24
                                }

                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        menu.previewPath = card.modelData.orig
                                        menu.previewName = card.modelData.name
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: menu.wallpapers.length === 0
                        anchors.centerIn: parent
                        text: "Scanning wallpapers..."
                        color: mocha.subtext0
                        font.pixelSize: 14
                    }
                }
            }
        }
    }

    // Preview overlay
    Rectangle {
        id: previewOverlay
        anchors.fill: parent
        color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.85)
        visible: menu.previewPath !== ""
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea { anchors.fill: parent; onClicked: menu.previewPath = "" }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            // Preview image
            Rectangle {
                Layout.preferredWidth: 640
                Layout.preferredHeight: 400
                radius: 12
                color: mocha.surface0
                clip: true

                Image {
                    anchors.fill: parent
                    source: menu.previewPath !== "" ? "file://" + menu.previewPath : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
            }

            // Filename
            Text {
                text: menu.previewName
                color: mocha.text
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Buttons
            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    width: 100; height: 36; radius: 8
                    color: mocha.surface1
                    Text { anchors.centerIn: parent; text: "Cancel"; color: mocha.text; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: menu.previewPath = "" }
                }

                Rectangle {
                    width: 100; height: 36; radius: 8
                    color: mocha.mauve
                    Text { anchors.centerIn: parent; text: "Apply"; color: "#fff"; font.pixelSize: 12 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            menu.setWallpaper(menu.previewPath)
                            menu.previewPath = ""
                        }
                    }
                }
            }
        }
    }
}
