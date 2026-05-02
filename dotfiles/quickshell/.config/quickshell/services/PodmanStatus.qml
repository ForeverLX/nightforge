import QtQuick 2.15
import Quickshell
import Quickshell.Io

Item {
    visible: false
    property int count: 0
    property var containers: []
    property string lastLogs: ""

    function stopContainer(id) { runCmd(["podman", "stop", id]) }
    function startContainer(id) { runCmd(["podman", "start", id]) }

    function logsContainer(id) {
        var proc = logComponent.createObject(PodmanStatus)
        proc.command = ["podman", "logs", "--tail", "50", id]
        proc.running = true
    }

    function runCmd(cmd) {
        var proc = cmdComponent.createObject(PodmanStatus)
        proc.command = cmd
        proc.running = true
    }

    Component {
        id: cmdComponent
        Process { command: []; running: false }
    }

    Component {
        id: logComponent
        Process {
            command: []
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    PodmanStatus.lastLogs = text
                }
            }
        }
    }

    Process {
        id: poll
        command: ["podman", "ps", "--format", "json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (Array.isArray(data)) {
                        containers = data.map(function(c) {
                            return {
                                name: (c.Names && c.Names[0]) || c.Name || c.name || "unknown",
                                image: c.Image || c.image || "unknown",
                                status: c.State || c.status || c.Status || "unknown",
                                id: (c.Id || c.ID || c.id || "").substring(0, 12)
                            }
                        })
                        count = containers.length
                    } else {
                        containers = []
                        count = 0
                    }
                } catch(e) {
                    console.log("PodmanStatus parse error:", e)
                    containers = []
                    count = 0
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: poll.running = true
    }
}
