import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window

    property var notifModel
    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    // --- Colors ---
    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve
    readonly property color red: _theme.red
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color green: _theme.green
    readonly property color teal: _theme.teal
    readonly property color blue: _theme.blue

    // --- State ---
    property string currentUserName: ""
    property bool dndEnabled: false
    property bool isDesktop: false
    property bool hasBacklight: false
    property real sysVolume: 0
    property bool sysMuted: false
    property real sysBrightness: 0
    property var collapsedGroups: ({})

    function toggleGroup(name) {
        var t = Object.assign({}, collapsedGroups);
        t[name] = !t[name];
        collapsedGroups = t;
    }
    function isCollapsed(name) { return collapsedGroups[name] === true; }

    // --- Desktop / backlight detection ---
    Process {
        command: ["sh", "-c", "test -d /sys/class/power_supply/BAT* 2>/dev/null && echo 'laptop' || echo 'desktop'"]
        running: true
        stdout: StdioCollector { onStreamFinished: window.isDesktop = this.text.trim() === "desktop" }
    }
    Process {
        command: ["sh", "-c", "ls /sys/class/backlight/* 2>/dev/null | head -1 || echo ''"]
        running: true
        stdout: StdioCollector { onStreamFinished: window.hasBacklight = this.text.trim() !== "" }
    }

    // --- System data polling ---
    Process {
        id: sysPoller; running: true
        command: ["sh", "-c", "echo \"" + (
            "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '0';" +
            "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'Unknown';" +
            "powerprofilesctl get 2>/dev/null || echo 'balanced';" +
            "awk '{print int($1/3600)\\\"h \\\"int(($1%3600)/60)\\\"m\\\"}' /proc/uptime 2>/dev/null || echo '0h 0m';" +
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100),($3==\\\"[MUTED]\\\"?\\\"off\\\":\\\"on\\\")}' || echo '0 on';" +
            "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4,1,length($4)-1)}' || echo '0'"
        ) + "\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(";");
                if (parts.length >= 6) {
                    window.sysVolume = parseFloat(parts[4].split(" ")[0]) || 0;
                    window.sysMuted = parts[4].indexOf("off") >= 0;
                    window.sysBrightness = parseFloat(parts[5]) || 0;
                }
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: sysPoller.running = true }

    // --- Main UI ---
    Rectangle {
        anchors.fill: parent
        color: window.base

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: window.s(16)
            spacing: window.s(12)

            // --- Header ---
            RowLayout {
                Layout.fillWidth: true
                spacing: window.s(8)
                Text {
                    text: "󰨇  Notifications"
                    font.family: "JetBrains Mono"; font.pixelSize: window.s(13); font.weight: Font.Black
                    color: window.text
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    id: dndBtn; width: window.s(28); height: window.s(28); radius: window.s(8)
                    color: dndMa.containsMouse ? window.surface1 : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰂛"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(14)
                        color: window.dndEnabled ? window.red : window.overlay0
                    }
                    MouseArea {
                        id: dndMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: window.dndEnabled = !window.dndEnabled
                    }
                }
            }

            // --- Notification List ---
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: window.s(200); clip: true

                ListView {
                    anchors.fill: parent; spacing: window.s(6); clip: true
                    model: window.notifModel
                    delegate: notifDelegate
                }

                Text {
                    anchors.centerIn: parent
                    text: "No notifications"
                    font.family: "JetBrains Mono"; font.pixelSize: window.s(12)
                    color: window.overlay0
                    visible: !window.notifModel || window.notifModel.count === 0
                }
            }

            // --- Separator ---
            Rectangle {
                Layout.fillWidth: true; height: 1; color: window.surface1
            }

            // --- Brightness Slider ---
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: window.s(48)
                radius: window.s(14); color: window.surface0
                border.color: window.surface1; border.width: 1
                visible: window.hasBacklight

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: window.s(12); spacing: window.s(4)
                    RowLayout { Layout.fillWidth: true; spacing: window.s(10)
                        Text { text: "󰃟"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18); color: window.text }
                        Rectangle { Layout.fillWidth: true; height: window.s(16); radius: window.s(8); color: window.surface1; clip: true
                            Rectangle { width: parent.width * (window.sysBrightness / 100); height: parent.height; radius: window.s(8); color: window.blue }
                        }
                        Text { text: Math.round(window.sysBrightness) + "%"; font.family: "JetBrains Mono"; font.pixelSize: window.s(10); color: window.subtext0 }
                    }
                }
            }

            // --- Power Actions ---
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: window.s(50)
                spacing: window.s(8)

                Repeater {
                    model: ListModel {
                        ListElement { cmd: "gtklock -d"; icon: ""; baseColor: "mauve" }
                        ListElement { cmd: "niri msg action quit"; icon: "󰍃"; baseColor: "peach" }
                        ListElement { cmd: "gtklock -d && systemctl suspend"; icon: "ᶻ 𝗓 𝗓"; baseColor: "blue" }
                        ListElement { cmd: "systemctl reboot"; icon: "󰜉"; baseColor: "yellow" }
                        ListElement { cmd: "systemctl poweroff -i"; icon: ""; baseColor: "red" }
                    }
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: window.s(12)
                        color: ma.containsMouse ? window.surface1 : window.surface0
                        border.color: ma.containsMouse ? window[baseColor] : window.surface2
                        border.width: ma.containsMouse ? 2 : 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        scale: ma.pressed ? 0.95 : (ma.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: icon; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(22)
                            color: ma.containsMouse ? window[baseColor] : window.subtext0
                        }
                        MouseArea {
                            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["sh", "-c", cmd]);
                                Quickshell.execDetached(["sh", "-c", "echo 'close' > /tmp/qs_widget_state"]);
                            }
                        }
                    }
                }
            }

            // --- Re-Theme Button ---
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: window.s(32); radius: window.s(10)
                color: rtMa.containsMouse ? window.surface1 : "transparent"
                border.color: window.surface2; border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                RowLayout {
                    anchors.centerIn: parent; spacing: window.s(8)
                    Text { text: "󰸉"; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(14); color: window.subtext0 }
                    Text { text: "Refresh theme"; font.family: "JetBrains Mono"; font.pixelSize: window.s(10); color: window.subtext0 }
                }
                MouseArea {
                    id: rtMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["sh", "-c", Quickshell.env("HOME") + "/.config/quickshell/scripts/wallpaper/matugen_reload.sh"])
                }
            }

            // --- Power Profiles ---
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: window.s(36); spacing: window.s(6)
                visible: false  // hidden for now, enable later

                Repeater {
                    model: ListModel {
                        ListElement { name: "performance"; icon: "󰓅"; hint: "Boost per fl" }
                        ListElement { name: "balanced"; icon: "󰖣"; hint: "Default" }
                        ListElement { name: "power-saver"; icon: "󰾆"; hint: "Energy save" }
                    }
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: window.s(10)
                        color: ma.containsMouse ? window.surface1 : window.surface0
                        Text {
                            anchors.centerIn: parent
                            text: icon; font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(14)
                            color: ma.containsMouse ? window.subtext0 : window.overlay0
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true
                            onClicked: Quickshell.execDetached(["sh", "-c", "powerprofilesctl set " + name])
                        }
                    }
                }
            }
        }
    }

    // --- Notification Delegate ---
    Component {
        id: notifDelegate
        Rectangle {
            width: parent ? parent.width : 0; height: notifBody.height + window.s(30); radius: window.s(10)
            color: window.surface0; border.color: window.surface1; border.width: 1

            ColumnLayout {
                id: notifBody; anchors.fill: parent; anchors.margins: window.s(10); spacing: window.s(4)
                RowLayout {
                    Layout.fillWidth: true; spacing: window.s(6)
                    Rectangle { width: window.s(6); height: window.s(6); radius: window.s(3); color: window.teal; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: model.appName || "System"; font.family: "JetBrains Mono"; font.pixelSize: window.s(10); font.weight: Font.Bold; color: window.subtext1; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { text: model.summary || ""; font.family: "JetBrains Mono"; font.pixelSize: window.s(10); color: window.overlay0; elide: Text.ElideRight; visible: model.body }
                }
                Text { text: model.body || model.summary || ""; font.family: "JetBrains Mono"; font.pixelSize: window.s(11); color: window.text; wrapMode: Text.WordWrap; Layout.fillWidth: true; visible: text !== "" }
            }
        }
    }
}
