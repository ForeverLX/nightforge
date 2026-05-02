import QtQuick 2.15
import Quickshell
import Quickshell.Io

Item {
    visible: false
    property bool playing: false
    property string track: ""
    property string artist: ""
    property string album: ""
    property int elapsed: 0
    property int total: 0
    property string albumArt: ""

    function play() { runMpc(["play"]) }
    function pause() { runMpc(["pause"]) }
    function toggle() { runMpc(["toggle"]) }
    function playPause() { runMpc(["toggle"]) }
    function next() { runMpc(["next"]) }
    function prev() { runMpc(["prev"]) }

    function runMpc(args) {
        var proc = mpcCmdComponent.createObject(MpdClient)
        proc.command = ["mpc"].concat(args)
        proc.running = true
    }

    Component {
        id: mpcCmdComponent
        Process { command: []; running: false }
    }

    Process {
        id: statusPoll
        command: ["sh", "-c", "mpc -f 'ARTIST=[%artist%] TITLE=[%title%] ALBUM=[%album%] TIME=[%time%]' current && echo '---SEPARATOR---' && mpc status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                parseOutput(text)
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: statusPoll.running = true
    }

    function parseOutput(output) {
        var parts = output.split('---SEPARATOR---')
        var currentLine = parts[0] ? parts[0].trim() : ""
        var statusBlock = parts[1] ? parts[1].trim() : ""

        // Parse bracketed metadata: ARTIST=[...] TITLE=[...] ALBUM=[...] TIME=[...]
        var artistMatch = currentLine.match(/ARTIST=\[([^\]]*)\]/)
        var titleMatch = currentLine.match(/TITLE=\[([^\]]*)\]/)
        var albumMatch = currentLine.match(/ALBUM=\[([^\]]*)\]/)
        artist = artistMatch ? artistMatch[1] : ""
        track = titleMatch ? titleMatch[1] : ""
        album = albumMatch ? albumMatch[1] : ""

        var lines = statusBlock.split('\n')
        playing = false
        elapsed = 0
        total = 0

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line.indexOf('[playing]') !== -1) {
                playing = true
            } else if (line.indexOf('[paused]') !== -1) {
                playing = false
            }

            var timeMatch = line.match(/(\d+:\d+)\/(\d+:\d+)/)
            if (timeMatch) {
                elapsed = parseTime(timeMatch[1])
                total = parseTime(timeMatch[2])
            }
        }
    }

    function parseTime(t) {
        var p = t.split(':')
        if (p.length === 2) {
            return parseInt(p[0]) * 60 + parseInt(p[1])
        }
        return 0
    }
}
