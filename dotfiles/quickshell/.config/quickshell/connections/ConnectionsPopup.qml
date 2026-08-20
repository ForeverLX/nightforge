import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PanelWindow {
    id: window
    visible: true
    color: "transparent"

    property string activeMode: "containers"

    QtObject {
        id: mocha
        readonly property color crust:       Qt.rgba(17/255, 17/255, 27/255, 1)
        readonly property color mantle:      Qt.rgba(24/255, 24/255, 37/255, 1)
        readonly property color base:        Qt.rgba(30/255, 30/255, 46/255, 1)
        readonly property color surface0:    Qt.rgba(49/255, 50/255, 68/255, 1)
        readonly property color surface1:    Qt.rgba(69/255, 71/255, 90/255, 1)
        readonly property color overlay0:    Qt.rgba(108/255, 112/255, 134/255, 1)
        readonly property color subtext0:    Qt.rgba(166/255, 173/255, 200/255, 1)
        readonly property color text:        Qt.rgba(205/255, 214/255, 244/255, 1)
        readonly property color blue:        Qt.rgba(137/255, 180/255, 250/255, 1)
        readonly property color green:       Qt.rgba(166/255, 227/255, 161/255, 1)
        readonly property color yellow:      Qt.rgba(249/255, 226/255, 175/255, 1)
        readonly property color red:         Qt.rgba(243/255, 139/255, 168/255, 1)
        readonly property color mauve:       Qt.rgba(203/255, 166/255, 247/255, 1)
        readonly property color teal:        Qt.rgba(148/255, 226/255, 213/255, 1)
    }

    readonly property var validModes: ["containers", "vms", "usb", "network", "ssh"]

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.90)
        radius: 18
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 50
            color: "transparent"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 20
                text: "Connections"
                color: mocha.text
                font.family: "JetBrains Mono"
                font.pixelSize: 16
                font.weight: Font.Bold
            }
        }

        StackLayout {
            id: contentStack
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: tabBar.top
            anchors.margins: 12
            currentIndex: validModes.indexOf(window.activeMode)

            ContainersTab {}
            VmsTab {}
            UsbTab {}
            NetworkTab {}
            SshTab {}
        }

        Rectangle {
            id: tabBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44
            color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.5)
            radius: 18

            Row {
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: [
                        { mode: "containers", icon: "\uF21A", label: "Containers" },
                        { mode: "vms", icon: "\uF109", label: "VMs" },
                        { mode: "usb", icon: "\uF287", label: "USB" },
                        { mode: "network", icon: "\uF1EB", label: "Network" },
                        { mode: "ssh", icon: "\uF17C", label: "SSH" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: tabText.implicitWidth + 20
                        height: 32
                        radius: 10
                        color: window.activeMode === modelData.mode ? mocha.mauve : "transparent"

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData.icon + " " + modelData.label
                            color: window.activeMode === modelData.mode ? mocha.base : mocha.subtext0
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: window.activeMode = modelData.mode
                        }
                    }
                }
            }
        }
    }

    component ContainersTab: Rectangle {
        color: "transparent"
        ListView {
            anchors.fill: parent; clip: true; model: containerModel; spacing: 6
            delegate: ConnectionRow {
                icon: "\uF21A"; name: model.name; status: model.status; detail: model.ports
                statusColor: model.status === "running" ? mocha.green : mocha.red
            }
        }
        ListModel { id: containerModel }
        Process {
            id: containerPoller
            command: ["bash", "-c", "podman ps --format '{{.Names}}|{{.Status}}|{{.Ports}}' 2>/dev/null || echo ''"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    containerModel.clear()
                    for (let line of text.trim().split("\n")) {
                        let p = line.split("|")
                        if (p.length >= 2) containerModel.append({name: p[0], status: p[1], ports: p[2] || ""})
                    }
                }
            }
        }
        Timer { interval: 5000; running: true; repeat: true; onTriggered: containerPoller.running = true }
    }

    component VmsTab: Rectangle {
        color: "transparent"
        ListView {
            anchors.fill: parent; clip: true; model: vmModel; spacing: 6
            delegate: ConnectionRow {
                icon: "\uF109"; name: model.name; status: model.state; detail: ""
                statusColor: model.state === "running" ? mocha.green : (model.state === "paused" ? mocha.yellow : mocha.overlay0)
            }
        }
        ListModel { id: vmModel }
        Process {
            id: vmPoller
            command: ["bash", "-c", "virsh list --all 2>/dev/null | tail -n +3 | awk '{print $2\"|\"$3}' || echo ''"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    vmModel.clear()
                    for (let line of text.trim().split("\n")) {
                        let p = line.split("|")
                        if (p.length >= 2 && p[0]) vmModel.append({name: p[0], state: p[1] || "shut off"})
                    }
                }
            }
        }
        Timer { interval: 5000; running: true; repeat: true; onTriggered: vmPoller.running = true }
    }

    component UsbTab: Rectangle {
        color: "transparent"
        ListView {
            anchors.fill: parent; clip: true; model: usbModel; spacing: 6
            delegate: ConnectionRow {
                icon: "\uF287"; name: model.name; status: model.bus; detail: ""
                statusColor: mocha.blue
            }
        }
        ListModel { id: usbModel }
        Process {
            id: usbPoller
            command: ["bash", "-c", "lsusb | awk '{$1=$2=$3=$4=$5=$6=\"\"; sub(/^ +/,\"\"); print}' | head -20 || echo ''"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    usbModel.clear()
                    for (let line of text.trim().split("\n")) {
                        if (line.trim()) usbModel.append({name: line.trim(), bus: "USB"})
                    }
                }
            }
        }
        Timer { interval: 10000; running: true; repeat: true; onTriggered: usbPoller.running = true }
    }

    component NetworkTab: Rectangle {
        color: "transparent"
        ListView {
            anchors.fill: parent; clip: true; model: netModel; spacing: 6
            delegate: ConnectionRow {
                icon: "\uF1EB"; name: model.iface; status: model.peers + " peers"; detail: model.handshake
                statusColor: model.peers > 0 ? mocha.green : mocha.overlay0
            }
        }
        ListModel { id: netModel }
        Process {
            id: netPoller
            command: ["bash", "-c", "for iface in $(wg show interfaces 2>/dev/null); do echo \"$iface|$(wg show $iface peers | wc -l)|$(wg show $iface latest-handshakes | awk '{print $2}' | sort -n | tail -1)\"; done || echo ''"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    netModel.clear()
                    for (let line of text.trim().split("\n")) {
                        let p = line.split("|")
                        if (p.length >= 2 && p[0]) {
                            let hs = p[2] ? (parseInt(p[2]) > 0 ? Math.floor(parseInt(p[2]) / 60) + "m ago" : "just now") : ""
                            netModel.append({iface: p[0], peers: parseInt(p[1]) || 0, handshake: hs})
                        }
                    }
                }
            }
        }
        Timer { interval: 10000; running: true; repeat: true; onTriggered: netPoller.running = true }
    }

    component SshTab: Rectangle {
        color: "transparent"
        ListView {
            anchors.fill: parent; clip: true; model: sshModel; spacing: 6
            delegate: ConnectionRow {
                icon: "\uF17C"; name: model.local; status: model.remote; detail: model.state
                statusColor: model.state === "ESTAB" ? mocha.green : mocha.yellow
            }
        }
        ListModel { id: sshModel }
        Process {
            id: sshPoller
            command: ["bash", "-c", "ss -tulpn | grep sshd | awk '{print $4\"|\"$5\"|\"$1}' | head -10 || echo ''"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    sshModel.clear()
                    for (let line of text.trim().split("\n")) {
                        let p = line.split("|")
                        if (p.length >= 2) sshModel.append({local: p[0], remote: p[1] || "", state: p[2] || ""})
                    }
                }
            }
        }
        Timer { interval: 5000; running: true; repeat: true; onTriggered: sshPoller.running = true }
    }

    component ConnectionRow: Rectangle {
        property string icon: ""; property string name: ""; property string status: ""
        property string detail: ""; property color statusColor: mocha.text
        width: parent.width; height: 36; radius: 8
        color: ma.containsMouse ? Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.6) : "transparent"

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 12; spacing: 10
            Text { anchors.verticalCenter: parent.verticalCenter; text: icon; color: mocha.subtext0; font.family: "Iosevka Nerd Font"; font.pixelSize: 13 }
            Text { anchors.verticalCenter: parent.verticalCenter; text: name; color: mocha.text; font.family: "JetBrains Mono"; font.pixelSize: 12; elide: Text.ElideRight; width: 140 }
            Text { anchors.verticalCenter: parent.verticalCenter; text: status; color: statusColor; font.family: "JetBrains Mono"; font.pixelSize: 11 }
            Text { anchors.verticalCenter: parent.verticalCenter; text: detail; color: mocha.subtext0; font.family: "JetBrains Mono"; font.pixelSize: 10; elide: Text.ElideRight; width: 100 }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true }
    }
}
