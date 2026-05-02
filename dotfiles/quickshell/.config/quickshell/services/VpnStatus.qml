import QtQuick 2.15
import Quickshell
import Quickshell.Io

Item {
    visible: false
    property bool connected: false
    property string statusText: "Down"

    function connect() { runCmd(["pkexec", "wg-quick", "up", "wg0"]) }
    function disconnect() { runCmd(["pkexec", "wg-quick", "down", "wg0"]) }
    function toggle() { connected ? disconnect() : connect() }

    function runCmd(cmd) {
        var proc = cmdComponent.createObject(VpnStatus)
        proc.command = cmd
        proc.running = true
    }

    Component {
        id: cmdComponent
        Process {
            command: []
            running: false
        }
    }

    Process {
        id: poll
        command: ["sh", "-c", "wg show wg0 2>/dev/null | grep -q 'interface' && echo 'Up' || echo 'Down'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = text.trim()
                connected = txt === "Up"
                statusText = connected ? "Up" : "Down"
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: poll.running = true
    }
}
