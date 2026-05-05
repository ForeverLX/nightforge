import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../../components"
import "../../services"

Item {
    id: root
    property string widgetName: "music"
    property var mpd

    implicitWidth: 680
    implicitHeight: 600

    MatugenColors { id: mocha }

    GlassPanel {
        anchors.fill: parent
        matugen: mocha
        glassRadius: 20

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // Inline media header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 48; height: 48; radius: 8
                    color: mocha.surface0
                    Image {
                        anchors.fill: parent
                        source: mpd && mpd.albumArt ? mpd.albumArt : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: mpd && mpd.albumArt !== ""
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\uD83C\uDFB5"
                        font.pixelSize: 20
                        visible: !mpd || mpd.albumArt === ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: mpd && mpd.track ? mpd.track : "No track"
                        color: mocha.text
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: mpd && mpd.artist ? mpd.artist : "Unknown artist"
                        color: mocha.subtext0
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Large album art
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 280; height: 280; radius: 16
                color: mocha.surface0
                Image {
                    anchors.fill: parent
                    source: mpd && mpd.albumArt ? mpd.albumArt : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: mpd && mpd.albumArt !== ""
                }
                Text {
                    anchors.centerIn: parent
                    text: "\uD83C\uDFB5"
                    font.pixelSize: 80
                    visible: !mpd || mpd.albumArt === ""
                }
            }

            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: mpd && mpd.track ? mpd.track : "No track"
                    color: mocha.text
                    font.pixelSize: 18
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: mpd && mpd.artist ? mpd.artist : "Unknown artist"
                    color: mocha.subtext0
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: mpd && mpd.album ? mpd.album : ""
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
                    width: parent.width * (mpd && mpd.total > 0 ? mpd.elapsed / mpd.total : 0)
                    height: parent.height
                    radius: 3
                    color: mocha.mauve
                }
            }

            Text {
                text: formatTime(mpd ? mpd.elapsed : 0) + " / " + formatTime(mpd ? mpd.total : 0)
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
                    color: mocha.surface1
                    Text { anchors.centerIn: parent; text: "\u23EE"; color: mocha.text; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: mpd.prev() }
                }
                Rectangle {
                    width: 56; height: 56; radius: 28
                    color: mocha.mauve
                    Text {
                        anchors.centerIn: parent
                        text: (mpd && mpd.playing) ? "\u23F8" : "\u25B6"
                        color: "#ffffff"
                        font.pixelSize: 22
                    }
                    MouseArea { anchors.fill: parent; onClicked: mpd.playPause() }
                }
                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: mocha.surface1
                    Text { anchors.centerIn: parent; text: "\u23ED"; color: mocha.text; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: mpd.next() }
                }
            }
        }
    }

    function formatTime(seconds) {
        var s = seconds || 0
        var m = Math.floor(s / 60)
        var sec = s % 60
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }
}
