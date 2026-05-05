import QtQuick
import Quickshell
import Quickshell.Io

import "../../components"
import "../../services"

Item {
    id: menu
    property string widgetName: "wallpaper"

    implicitWidth: 820
    implicitHeight: 620

    MatugenColors { id: mocha }

    readonly property string wallpaperDir: "/home/ForeverLX/Pictures/wallpapers"
    readonly property string cacheDir:     "/home/ForeverLX/.cache/qs-wallpapers"
    property var    wallpapers: []
    property var    _buf: []
    property string currentWall: ""

    Component.onCompleted: {
        _buf = []
        wallpapers = []
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
    }

    GlassPanel {
        anchors.fill: parent
        matugen: mocha
        glassRadius: 20

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Item {
                width: parent.width
                height: 28
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{1f5bc} Wallpaper"
                    color: mocha.mauve
                    font.pixelSize: 18
                    font.bold: true
                }
            }

            Rectangle {
                width: parent.width
                height: 566
                radius: 12
                color: "transparent"
                clip: true

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: wallRow.implicitWidth
                    contentHeight: height
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    leftMargin: 4
                    rightMargin: 4

                    WheelHandler {
                        orientation: Qt.Horizontal
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        rotationScale: -5
                        target: flick
                        property: "contentX"
                    }
                    WheelHandler {
                        orientation: Qt.Vertical
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        rotationScale: -5
                        target: flick
                        property: "contentX"
                    }

                    Row {
                        id: wallRow
                        spacing: 10
                        height: parent.height

                        Repeater {
                            model: menu.wallpapers

                            Item {
                                id: card
                                required property var modelData
                                readonly property bool active: menu.currentWall === modelData.orig

                                width: 164
                                height: 120

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    clip: true
                                    color: mocha.surface0
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + card.modelData.thumb
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: "transparent"
                                    border.width: card.active ? 3 : (ma.containsMouse ? 2 : 0)
                                    border.color: card.active ? mocha.mauve : (ma.containsMouse ? mocha.surface2 : "transparent")
                                }

                                Rectangle {
                                    visible: card.active
                                    width: 10
                                    height: 10
                                    radius: 5
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
                                    onClicked: menu.setWallpaper(card.modelData.orig)
                                }
                            }
                        }

                        Text {
                            visible: menu.wallpapers.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Scanning wallpapers..."
                            color: mocha.subtext0
                            font.pixelSize: 14
                            leftPadding: 20
                        }
                    }
                }
            }
        }
    }
}
