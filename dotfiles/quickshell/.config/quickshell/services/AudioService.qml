// Audio Service — Pipewire via QML Process polling
// Replaces pactl/wpctl scripts with structured QML service
pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property real volume: 0
    property bool muted: false
    property string defaultSink: ""
    property string defaultSource: ""
    property var sinks: []
    property var sources: []

    // Poll audio state
    Process { id: volProc; command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2*100, $3}'"]
        stdout: StdioCollector { onStreamFinished: { var p = this.text.trim().split(" "); root.volume = parseFloat(p[0]) || 0; root.muted = p[1] === "[MUTED]"; } }
    }
    Process { id: sinkProc; command: ["bash", "-c", "pactl list sinks short | awk '{print $2}'"]
        stdout: StdioCollector { onStreamFinished: { root.sinks = this.text.trim().split("\n").filter(function(x){return x!==""}); } }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: { volProc.running=false;volProc.running=true;sinkProc.running=false;sinkProc.running=true; } }

    function toggleMute() { Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]); }
    function setVolume(v) { Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", String(v/100)]); }
    function incrementVolume(amount) { setVolume(root.volume + amount); }
    function decrementVolume(amount) { setVolume(root.volume - amount); }
    function cycleSink() { Quickshell.execDetached(["pactl", "set-default-sink"]); }
}
