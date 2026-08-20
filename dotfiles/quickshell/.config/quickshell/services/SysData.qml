import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    // === EXPOSED PROPERTIES ===
    property int cpuPercent: 0
    property int ramPercent: 0
    property real ramGb: 0.0
    property int tempCelsius: 0

    // === DELTA CPU TRACKING ===
    property int _prevIdle: 0
    property int _prevTotal: 0

    // === SUBSCRIBER LIFECYCLE ===
    // Start/stop polling based on subscriber count.
    // Call subscribe() when a widget becomes visible,
    // unsubscribe() when it hides.
    property int subscribers: 0

    function subscribe() {
        subscribers++;
        if (subscribers === 1) {
            fetchTimer.restart();
            fetchProc.running = true;
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            fetchTimer.stop();
            fetchProc.running = false;
        }
    }

    // === POLLING ===
    Timer {
        id: fetchTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: { fetchProc.running = false; fetchProc.running = true; }
    }

    Process {
        id: fetchProc
        running: false
        command: ["sh", "-c",
            "head -1 /proc/stat; " +
            "free | grep '^Mem:'; " +
            "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                var lines = text.trim().split("\n");

                // --- CPU (delta-based) ---
                if (lines.length >= 1) {
                    var cpuParts = lines[0].trim().split(/\s+/);
                    if (cpuParts.length >= 8 && cpuParts[0] === "cpu") {
                        var idle = parseInt(cpuParts[4]) + parseInt(cpuParts[5]);
                        var total = 0;
                        for (var i = 1; i < 8; i++) total += parseInt(cpuParts[i]) || 0;
                        if (root._prevTotal > 0 && total > root._prevTotal) {
                            var deltaIdle = idle - root._prevIdle;
                            var deltaTotal = total - root._prevTotal;
                            root.cpuPercent = Math.min(100, Math.max(0, Math.round(100 * (1 - deltaIdle / deltaTotal))));
                        }
                        root._prevIdle = idle;
                        root._prevTotal = total;
                    }
                }

                // --- RAM ---
                if (lines.length >= 2) {
                    var memLine = lines[1].trim();
                    if (memLine.indexOf("Mem:") !== -1 || memLine.indexOf("Mem") !== -1) {
                        var memParts = memLine.split(/\s+/);
                        if (memParts.length >= 3) {
                            var memTotal = parseInt(memParts[1]) || 1;
                            var memUsed  = parseInt(memParts[2]) || 0;
                            root.ramGb = memUsed / 1048576.0;
                            root.ramPercent = Math.round(100 * memUsed / memTotal);
                        }
                    }
                }

                // --- Temperature ---
                if (lines.length >= 3) {
                    var tempVal = parseInt(lines[2].trim());
                    if (!isNaN(tempVal)) root.tempCelsius = Math.round(tempVal / 1000);
                }
            }
        }
    }
}
