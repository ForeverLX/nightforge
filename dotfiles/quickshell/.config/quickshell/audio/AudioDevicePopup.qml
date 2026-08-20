import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    QtObject {
        id: _theme
        readonly property color base: "#1e1e2e"
        readonly property color mantle: "#181825"
        readonly property color crust: "#11111b"
        readonly property color text: "#cdd6f4"
        readonly property color subtext0: "#a6adc8"
        readonly property color surface0: "#313244"
        readonly property color surface1: "#45475a"
        readonly property color surface2: "#585b70"
        readonly property color overlay0: "#6c7086"
        readonly property color green: "#a6e3a1"
        readonly property color red: "#f38ba8"
        readonly property color teal: "#94e2d5"
    }

    property var sinks: []
    property string defaultSink: ""

    Process {
        id: sinkPoller; running: true
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/audio-dev-list.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var list = [];
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("|");
                    if (parts.length >= 2) {
                        var active = parts[0].charAt(0) === ">";
                        var name = active ? parts[0].substring(1) : parts[0];
                        list.push({ name: name, desc: parts[1], active: active });
                    }
                }
                root.sinks = list;
            }
        }
    }
    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { sinkPoller.running = false; sinkPoller.running = true; } }

    Rectangle {
        anchors.fill: parent
        radius: s(14)
        color: _theme.mantle
        border.color: _theme.surface1; border.width: 1

        ColumnLayout {
            anchors.fill: parent; anchors.margins: s(12); spacing: s(8)

            Text {
                text: "󰓃  Audio Output"; font.family: "JetBrains Mono"; font.pixelSize: s(13); font.weight: Font.Black
                color: _theme.text; Layout.fillWidth: true
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: _theme.surface1 }

            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: s(4)
                model: root.sinks

                delegate: Rectangle {
                    width: parent ? parent.width : 0; height: s(40); radius: s(10)
                    color: ma.containsMouse ? _theme.surface1 : (modelData.active ? _theme.surface0 : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: s(10); spacing: s(8)
                        Text {
                            text: modelData.active ? "󰄾" : "󰄱"
                            font.family: "Iosevka Nerd Font"; font.pixelSize: s(14)
                            color: modelData.active ? _theme.green : _theme.overlay0
                        }
                        Text {
                            text: modelData.desc
                            font.family: "JetBrains Mono"; font.pixelSize: s(12)
                            color: modelData.active ? _theme.text : _theme.subtext0
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", "pactl set-default-sink " + modelData.name]);
                            Quickshell.execDetached(["sh", "-c", "echo 'close' > /tmp/qs_widget_state"]);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "No audio sinks detected"; font.family: "JetBrains Mono"; font.pixelSize: s(11)
                    color: _theme.overlay0; visible: parent.count === 0
                }
            }
        }
    }
}
