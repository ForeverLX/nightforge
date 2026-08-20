// NightForge CavaService — ported from DMS
// Runs cava as subprocess, provides real-time spectrum values
pragma Singleton
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<int> values: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    property int refCount: 0
    property bool cavaAvailable: false

    // Check if cava is installed
    Process {
        id: cavaCheck
        command: ["which", "cava"]
        running: false
        onExited: function(code) {
            root.cavaAvailable = code === 0;
        }
    }

    Component.onCompleted: {
        cavaCheck.running = true;
    }

    // Cava subprocess with raw output parsing
    Process {
        id: cavaProcess
        running: root.cavaAvailable && root.refCount > 0

        command: ["sh", "-c",
            "cat <<'CAVACONF' | cava -p /dev/stdin\n" +
            "[general]\nframerate=25\nbars=24\nautosens=0\nsensitivity=30\n" +
            "lower_cutoff_freq=50\nhigher_cutoff_freq=12000\n\n" +
            "[output]\nmethod=raw\nraw_target=/dev/stdout\ndata_format=ascii\n" +
            "channels=mono\nmono_option=average\n\n" +
            "[smoothing]\nnoise_reduction=35\nintegral=90\ngravity=95\n" +
            "ignore=2\nmonstercat=1.5\nCAVACONF"
        ]

        onRunningChanged: {
            if (!running) {
                root.values = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                if (root.refCount > 0 && data.length > 0) {
                    var parts = data.split(";");
                    if (parts.length >= 24) {
                        var vals = [];
                        for (var i = 0; i < 24; i++) {
                            vals.push(parseInt(parts[i], 10) || 0);
                        }
                        root.values = vals;
                    }
                }
            }
        }
    }
}
