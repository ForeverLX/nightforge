// MusicPopup Module - ilyamiro-styled MPD popup
import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Layouts

import "../services"

PanelWindow {
    id: musicPopup
    visible: false
    color: "transparent"

    property var mpd

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
        onClicked: musicPopup.visible = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: 360
        height: 420
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

            // Close button
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight

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
                        onClicked: musicPopup.visible = false
                    }
                }
            }

            // Album art
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 200
                height: 200
                radius: 12
                color: mocha.mantle

                Image {
                    anchors.fill: parent
                    source: mpd.albumArt
                    fillMode: Image.PreserveAspectCrop
                    visible: mpd.albumArt !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "🎵"
                    font.pixelSize: 64
                    visible: mpd.albumArt === ""
                }
            }

            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: mpd.track || "No track"
                    color: mocha.text
                    font.pixelSize: 18
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: mpd.artist || "Unknown artist"
                    color: mocha.subtext0
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: mpd.album || ""
                    color: mocha.subtext1
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                }
            }

            // Progress bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: mocha.surface0

                Rectangle {
                    width: parent.width * (mpd.total > 0 ? mpd.elapsed / mpd.total : 0)
                    height: parent.height
                    radius: 3
                    color: mocha.mauve
                }
            }

            Text {
                text: formatTime(mpd.elapsed) + " / " + formatTime(mpd.total)
                color: mocha.subtext0
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
            }

            // Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: mocha.mauve
                    Text { anchors.centerIn: parent; text: "⏮"; color: "#ffffff"; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: mpd.prev() }
                }

                Rectangle {
                    width: 56; height: 56; radius: 28
                    color: mocha.mauve
                    Text { anchors.centerIn: parent; text: mpd.playing ? "⏸" : "▶"; color: "#ffffff"; font.pixelSize: 22 }
                    MouseArea { anchors.fill: parent; onClicked: mpd.playPause() }
                }

                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: mocha.mauve
                    Text { anchors.centerIn: parent; text: "⏭"; color: "#ffffff"; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: mpd.next() }
                }
            }
        }
    }

    function formatTime(seconds) {
        var m = Math.floor(seconds / 60)
        var s = seconds % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }
}