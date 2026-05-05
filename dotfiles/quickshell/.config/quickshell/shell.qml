// Quickshell - NightForge Modular Shell Entry Point (StackView Architecture)
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "modules"
import "services"

Scope {
    id: root

    // === SERVICES ===
    MatugenColors { id: matugenColors }
    MpdClient { id: mpdClient }
    VpnStatus { id: vpnStatus }
    PodmanStatus { id: podmanStatus }

    // === PER-SCREEN BAR ===
    // Keep existing Bar for now (Subagent 2 will rewrite it)
    Bar { id: bar }

    // === FULL-SCREEN OVERLAY ===
    // Single PanelWindow on Overlay layer. All widgets live here.
    PanelWindow {
        id: overlay
        visible: stackView.depth > 0  // only visible when a widget is open
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nightforge-overlay"
        anchors { top: true; bottom: true; left: true; right: true }

        MatugenColors { id: mocha }

        // Darkened background — click to dismiss
        Rectangle {
            id: bgDim
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)
            opacity: overlay.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                onClicked: { stackView.clear(); root.clearWidgetState() }
            }
        }

        // Escape key handler
        Keys.onEscapePressed: { stackView.clear(); root.clearWidgetState() }
        focus: true

        // StackView for widgets
        StackView {
            id: stackView
            anchors.centerIn: parent
            // Size animates based on current item — this creates the "morph" effect
            width: currentItem ? currentItem.implicitWidth || currentItem.width : 0
            height: currentItem ? currentItem.implicitHeight || currentItem.height : 0

            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

            // Transitions
            pushEnter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.92; to: 1.0; duration: 400; easing.type: Easing.OutBack }
            }
            pushExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200; easing.type: Easing.InCubic }
            }
            popEnter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
            }
            popExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200; easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; from: 1.0; to: 0.92; duration: 300; easing.type: Easing.InCubic }
            }
        }
    }

    // === OSD (separate PanelWindow for WlrLayershell reasons) ===
    OSD {
        id: osd
        visible: false
    }

    // === IPC SYSTEM ===
    // Reads /tmp/qs_widget_state — commands written by keybinds or bar
    // Format: "widgetname" (toggle), "close", "osd:type:label:value"
    property string currentWidget: ""

    Process {
        id: ipcPoll
        command: ["sh", "-c", "[ -f /tmp/qs_widget_state ] && content=$(head -1 /tmp/qs_widget_state) && [ -n \"$content\" ] && > /tmp/qs_widget_state && echo \"$content\" || echo ''"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var cmd = text.trim()
                if (cmd === "") return
                root.handleIpc(cmd)
            }
        }
    }

    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: ipcPoll.running = true
    }

    // Also listen via inotifywait for instant response (optional enhancement)
    Process {
        id: ipcWatch
        command: ["sh", "-c", "while inotifywait -e modify /tmp/qs_widget_state 2>/dev/null; do cat /tmp/qs_widget_state; done"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                if (!data || data.trim() === "") return
                // Clear the file after reading
                var clearProc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
                clearProc.command = ["sh", "-c", "> /tmp/qs_widget_state"]
                clearProc.running = true
                root.handleIpc(data.trim())
            }
        }
    }

    // === WIDGET REGISTRY ===
    // Map widget names to their QML components and service dependencies
    property var widgetRegistry: ({
        "controlcenter": { comp: "modules/widgets/ControlCenterWidget.qml", services: { mpd: mpdClient, vpn: vpnStatus, podman: podmanStatus } },
        "music":         { comp: "modules/widgets/MusicWidget.qml",         services: { mpd: mpdClient } },
        "wallpaper":     { comp: "modules/widgets/WallpaperWidget.qml",     services: {} },
        "network":       { comp: "modules/widgets/NetworkWidget.qml",       services: {} },
        "statusmonitor": { comp: "modules/widgets/StatusMonitorWidget.qml", services: {} },
        "monitor":       { comp: "modules/widgets/MonitorWidget.qml",       services: {} }
    })

    // === IPC HANDLER ===
    function handleIpc(cmd) {
        if (cmd === "close") {
            stackView.clear()
            currentWidget = ""
            return
        }
        if (cmd.startsWith("osd:")) {
            var parts = cmd.split(":")
            if (parts.length >= 4) {
                osd.show(parts[1], parts[2], parseInt(parts[3]))
            }
            return
        }
        if (cmd === "launcher") {
            var fuzzelProc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
            fuzzelProc.command = ["fuzzel"]
            fuzzelProc.running = true
            return
        }

        // Widget toggle
        var entry = widgetRegistry[cmd]
        if (!entry) return

        if (currentWidget === cmd) {
            // Toggle off
            stackView.pop()
            currentWidget = stackView.depth > 0 ? stackView.currentItem.widgetName || "" : ""
        } else {
            // Push new widget
            var comp = Qt.createComponent(entry.comp)
            if (comp.status === Component.Ready) {
                var props = entry.services || {}
                props.widgetName = cmd
                stackView.push(comp, props)
                currentWidget = cmd
            } else if (comp.status === Component.Error) {
                console.log("Error loading " + entry.comp + ": " + comp.errorString())
            }
        }
    }

    function clearWidgetState() {
        currentWidget = ""
    }
}
