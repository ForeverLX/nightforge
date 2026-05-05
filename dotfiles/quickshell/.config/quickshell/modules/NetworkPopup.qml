import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../services"

PanelWindow {
    id: window
    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }

    MatugenColors { id: mocha }

    readonly property string scriptsDir: "/home/ForeverLX/Github/nightforge/scripts/qs-network"

    // === STATE ===
    property bool ethPresent: false
    property bool wifiPresent: false
    property bool btPresent: false

    property string ethPower: "off"
    property string wifiPower: "off"
    property string btPower: "off"

    property var ethConnected: null
    property var wifiConnected: null
    property var btConnected: []
    property var wifiList: []
    property var btList: []

    property string activeMode: "wifi"
    property string connectingId: ""
    property string failedId: ""
    property string pendingPassword: ""
    property string pendingSsid: ""

    Timer { id: failClearTimer; interval: 4000; onTriggered: window.failedId = "" }
    Timer { id: busyTimeout; interval: 15000; onTriggered: { window.connectingId = ""; window.pendingSsid = ""; window.pendingPassword = "" } }

    function safeGet(obj, key, fallback) {
        if (!obj || typeof obj !== "object") return fallback !== undefined ? fallback : ""
        var v = obj[key]
        return v !== undefined && v !== null ? v : (fallback !== undefined ? fallback : "")
    }

    readonly property bool ethConnected_: ethConnected !== null
    readonly property bool wifiConnected_: wifiConnected !== null && wifiConnected.ssid !== undefined
    readonly property bool btConnected_: btConnected.length > 0

    // === SCRIPT-BASED POLLING ===
    function reloadAll() {
        ethPoller.running = false; ethPoller.running = true
        wifiPoller.running = false; wifiPoller.running = true
        btPoller.running = false; btPoller.running = true
    }

    Timer { interval: 5000; running: true; repeat: true; onTriggered: reloadAll() }

    // ETH Poller
    Process {
        id: ethPoller
        command: ["bash", window.scriptsDir + "/eth_panel_logic.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    window.ethPresent = d.present === true
                    window.ethPower = d.power || "off"
                    window.ethConnected = d.connected || null
                } catch(e) {}
            }
        }
    }

    // WiFi Poller
    Process {
        id: wifiPoller
        command: ["bash", window.scriptsDir + "/wifi_panel_logic.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    window.wifiPresent = d.present === true
                    window.wifiPower = d.power || "off"
                    window.wifiConnected = d.connected || null
                    window.wifiList = d.networks || []
                } catch(e) {}
            }
        }
    }

    // BT Poller
    Process {
        id: btPoller
        command: ["bash", window.scriptsDir + "/bluetooth_panel_logic.sh", "--status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    window.btPresent = d.present === true
                    window.btPower = d.power || "off"
                    window.btConnected = d.connected || []
                    window.btList = d.devices || []
                } catch(e) {}
            }
        }
    }

    // === ACTIONS ===
    function connectWifi(ssid, password) {
        window.connectingId = ssid
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', window)
        if (password && password !== "") {
            p.command = ["sh", "-c", "nmcli device wifi connect '" + ssid + "' password '" + password + "'"]
        } else {
            p.command = ["sh", "-c", "nmcli device wifi connect '" + ssid + "'"]
        }
        p.running = true
    }

    function disconnectWifi(ssid) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', window)
        p.command = ["sh", "-c", "nmcli connection down '" + ssid + "'"]
        p.running = true
    }

    function connectBt(mac) {
        window.connectingId = mac
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', window)
        p.command = ["bash", window.scriptsDir + "/bluetooth_panel_logic.sh", "--connect", mac]
        p.running = true
    }

    function disconnectBt(mac) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', window)
        p.command = ["bash", window.scriptsDir + "/bluetooth_panel_logic.sh", "--disconnect", mac]
        p.running = true
    }

    function toggleWifiPower() {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', window)
        p.command = ["sh", "-c", window.wifiPower === "on" ? "nmcli radio wifi off" : "nmcli radio wifi on"]
        p.running = true
    }

    function toggleBtPower() {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', window)
        p.command = ["bash", window.scriptsDir + "/bluetooth_panel_logic.sh", "--toggle"]
        p.running = true
    }

    // === DISMISS OVERLAY ===
    MouseArea {
        anchors.fill: parent
        onClicked: window.visible = false
    }

    // === UI ===
    Item {
        anchors.centerIn: parent
        width: 480; height: 420

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, 0.95)
        border.color: mocha.surface0; border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "\uD83C\uDF10 Network"; color: mocha.text; font.pixelSize: 16; font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "\u2715"; color: mocha.subtext0; font.pixelSize: 14
                    MouseArea { anchors.fill: parent; onClicked: popupDismiss() }
                }
            }

            // Tab bar: ETH | WiFi | BT
            RowLayout {
                Layout.fillWidth: true; spacing: 6

                // ETH tab
                Rectangle {
                    id: ethTab
                    Layout.fillWidth: true; height: 34; radius: 10
                    color: window.activeMode === "eth"
                        ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.3)
                        : mocha.surface0
                    opacity: window.ethPresent ? 1.0 : 0.4
                    Text { anchors.centerIn: parent; text: "\uD83D\uDDE1\uFE0F ETH"; color: mocha.text; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; enabled: window.ethPresent; onClicked: window.activeMode = "eth" }
                }

                // WiFi tab
                Rectangle {
                    Layout.fillWidth: true; height: 34; radius: 10
                    color: window.activeMode === "wifi"
                        ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.3)
                        : mocha.surface0
                    Text { anchors.centerIn: parent; text: "\uD83D\uDCF6 WiFi"; color: mocha.text; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; onClicked: window.activeMode = "wifi" }
                }

                // BT tab
                Rectangle {
                    Layout.fillWidth: true; height: 34; radius: 10
                    color: window.activeMode === "bt"
                        ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.3)
                        : mocha.surface0
                    opacity: window.btPresent ? 1.0 : 0.4
                    Text { anchors.centerIn: parent; text: "\uD83D\uDC1C BT"; color: mocha.text; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; enabled: window.btPresent; onClicked: window.activeMode = "bt" }
                }
            }

            // Power toggle row
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: activeMode === "eth" ? "LAN: " + (ethPower === "on" ? "Connected" : "Disconnected")
                         : activeMode === "wifi" ? "WiFi: " + (wifiPower === "on" ? "On" : "Off")
                         : "Bluetooth: " + (btPower === "on" ? "On" : "Off")
                    color: mocha.text; font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 60; height: 24; radius: 12
                    color: (activeMode === "wifi" ? wifiPower : btPower) === "on" ? mocha.green : mocha.surface1
                    visible: activeMode !== "eth"
                    Text {
                        anchors.centerIn: parent
                        text: (activeMode === "wifi" ? wifiPower : btPower) === "on" ? "ON" : "OFF"
                        color: "#fff"; font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: activeMode === "wifi" ? toggleWifiPower() : toggleBtPower()
                    }
                }
            }

            // Connected device info (WiFi)
            Rectangle {
                Layout.fillWidth: true
                height: connectedInfo.implicitHeight + 16
                radius: 10; color: mocha.surface0
                visible: activeMode === "wifi" && wifiConnected_ && wifiPower === "on"

                ColumnLayout {
                    id: connectedInfo
                    anchors.fill: parent; anchors.margins: 10
                    spacing: 4
                    Text { text: "\u26A1 Connected: " + safeGet(wifiConnected, "ssid"); color: mocha.green; font.pixelSize: 12; font.bold: true }
                    Text { text: "Signal: " + safeGet(wifiConnected, "signal") + "%"; color: mocha.subtext0; font.pixelSize: 11 }
                    Text { text: "IP: " + safeGet(wifiConnected, "ip", "N/A"); color: mocha.subtext0; font.pixelSize: 11 }
                    Text { text: "Freq: " + safeGet(wifiConnected, "freq", "N/A"); color: mocha.subtext0; font.pixelSize: 11; visible: safeGet(wifiConnected,"freq","") !== "" }
                    Rectangle {
                        width: 80; height: 26; radius: 8; color: mocha.red
                        Text { anchors.centerIn: parent; text: "Disconnect"; color: "#fff"; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; onClicked: disconnectWifi(safeGet(wifiConnected, "ssid")) }
                    }
                }
            }

            // Connected device info (ETH)
            Rectangle {
                Layout.fillWidth: true
                height: ethInfo.implicitHeight + 16
                radius: 10; color: mocha.surface0
                visible: activeMode === "eth" && ethConnected_ && ethPower === "on"

                ColumnLayout {
                    id: ethInfo
                    anchors.fill: parent; anchors.margins: 10
                    spacing: 4
                    Text { text: "\uD83D\uDDE1\uFE0F LAN: " + safeGet(ethConnected, "name"); color: mocha.green; font.pixelSize: 12; font.bold: true }
                    Text { text: "IP: " + safeGet(ethConnected, "ip", "N/A"); color: mocha.subtext0; font.pixelSize: 11 }
                    Text { text: "Speed: " + safeGet(ethConnected, "speed", "N/A"); color: mocha.subtext0; font.pixelSize: 11; visible: safeGet(ethConnected,"speed","") !== "" }
                    Text { text: "MAC: " + safeGet(ethConnected, "mac", "N/A"); color: mocha.subtext0; font.pixelSize: 11; visible: safeGet(ethConnected,"mac","") !== "" }
                }
            }

            // Available networks/devices list
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: 10; color: mocha.surface0; clip: true

                ListView {
                    anchors.fill: parent; anchors.margins: 6; spacing: 4
                    clip: true

                    model: {
                        if (activeMode === "wifi" && wifiPower === "on") return window.wifiList
                        if (activeMode === "bt" && btPower === "on") return window.btList
                        return []
                    }

                    delegate: Item {
                        width: parent ? parent.width : 0; height: 44

                        Rectangle {
                            id: netRow
                            anchors.fill: parent; radius: 8
                            color: ma.containsMouse ? mocha.surface1 : "transparent"
                            border.width: window.connectingId === safeGet(modelData,"ssid") || window.connectingId === safeGet(modelData,"id") ? 1 : 0
                            border.color: mocha.mauve

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: activeMode === "wifi"
                                        ? (parseInt(safeGet(modelData,"signal","0")) >= 80 ? "\uD83D\uDDA4" : parseInt(safeGet(modelData,"signal","0")) >= 40 ? "\uD83D\uDFE2" : "\uD83D\uDFE1")
                                        : "\uD83D\uDC1C"
                                    font.pixelSize: 14
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text {
                                        text: safeGet(modelData,"ssid") || safeGet(modelData,"name") || safeGet(modelData,"id","Unknown")
                                        color: mocha.text; font.pixelSize: 12; font.bold: true
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    Text {
                                        text: activeMode === "wifi"
                                            ? "Signal: " + safeGet(modelData,"signal","0") + "% | " + safeGet(modelData,"security","Open")
                                            : safeGet(modelData,"action","")
                                        color: mocha.subtext0; font.pixelSize: 10
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    text: activeMode === "wifi" || (activeMode === "bt" && (safeGet(modelData,"action") === "Connect" || safeGet(modelData,"action") === "Pair"))
                                        ? (window.connectingId === safeGet(modelData,"ssid") || window.connectingId === safeGet(modelData,"id") ? "..." : "+")
                                        : ""
                                    color: mocha.mauve; font.pixelSize: 14
                                    visible: text !== ""
                                }
                            }

                            MouseArea {
                                id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (activeMode === "wifi") {
                                        connectWifi(safeGet(modelData,"ssid") || safeGet(modelData,"id",""), "")
                                    } else if (activeMode === "bt" && (safeGet(modelData,"action") === "Connect" || safeGet(modelData,"action") === "Pair")) {
                                        connectBt(safeGet(modelData,"mac",""))
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: activeMode === "eth" ? (ethConnected_ ? "Connected via " + safeGet(ethConnected, "name", "LAN") : "No Ethernet")
                             : activeMode === "wifi" ? (wifiPower === "on" ? "No networks found" : "WiFi is off")
                             : (btPower === "on" ? "No devices found" : "Bluetooth is off")
                        color: mocha.subtext0; font.pixelSize: 12
                        visible: parent.count === 0
                    }
                }
            }
        }
    }
    }

    function popupDismiss() {
        window.visible = false
    }
}
