// WallpaperPicker Module - ilyamiro-styled wallpaper grid
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts

import "../services"

PanelWindow {
    id: wallpaperPicker
    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MatugenColors { id: mocha }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: wallpaperPicker.visible = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: 700
        height: 500
        radius: 20
        color: mocha.crust
        border.color: mocha.surface0
        border.width: 1

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "🖼 Wallpaper"
                    color: mocha.mauve
                    font.pixelSize: 18
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: mocha.surface0

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: mocha.subtext0
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: wallpaperPicker.visible = false
                    }
                }
            }

            // Wallpaper grid
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 140
                cellHeight: 110
                model: wallpaperModel

                delegate: Rectangle {
                    width: grid.cellWidth - 8
                    height: grid.cellHeight - 8
                    radius: 8
                    color: mocha.mantle
                    border.color: wpMouse.containsMouse ? mocha.surface0 : "transparent"
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        anchors.margins: 4
                        source: "file://" + modelData.path
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 200
                        sourceSize.height: 150
                        asynchronous: true
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 4
                        text: modelData.name
                        color: mocha.text
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        style: Text.Outline
                        styleColor: "#000"
                    }

                    MouseArea {
                        id: wpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            setWallpaper(modelData.path)
                        }
                    }
                }
            }
        }
    }

    property var wallpaperModel: []

    onVisibleChanged: {
        if (visible) refreshWallpapers()
    }

    Process {
        id: wallpaperScan
        command: ["sh", "-c", "find /home/ForeverLX/Pictures/wallpapers -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort | head -50"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                var items = []
                for (var i = 0; i < lines.length; i++) {
                    var path = lines[i].trim()
                    if (path === "") continue
                    var name = path.substring(path.lastIndexOf("/") + 1)
                    items.push({ path: path, name: name })
                }
                wallpaperPicker.wallpaperModel = items
            }
        }
    }

    function refreshWallpapers() {
        wallpaperScan.running = true
    }

    function setWallpaper(path) {
        var swwwProc = Qt.createQmlObject('import Quickshell.Io; Process {}', wallpaperPicker)
        swwwProc.command = ["sh", "-c", "command -v awww >/dev/null 2>&1 && awww img '" + path + "' || cp '" + path + "' /home/ForeverLX/.cache/current_wallpaper.jpg"]
        swwwProc.running = true

        var matugenProc = Qt.createQmlObject('import Quickshell.Io; Process {}', wallpaperPicker)
        matugenProc.command = ["bash", "/home/ForeverLX/.local/bin/matugen-sync.sh", path]
        matugenProc.running = true

        wallpaperPicker.visible = false
    }
}