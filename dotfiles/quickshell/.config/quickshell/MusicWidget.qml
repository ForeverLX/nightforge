// NightForge MusicWidget
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components" as C

PanelWindow {
    id: root
    implicitWidth: 400; implicitHeight: 540
    exclusiveZone: 0; color: "transparent"; visible: false

    // ---- colors ----
    property color cBase: "#1e1e2e"
    property color cText: "#cdd6f4"
    property color cSubtext0: "#a6adc8"
    property color cMauve: "#cba6f7"
    property color cSurface0: "#313244"
    property color cSurface1: "#45475a"
    property color cOverlay0: "#6c7086"
    function a(c,a){ return Qt.rgba(c.r,c.g,c.b,a) }
    function fmt(s){
        if(!s||s<0)return"--:--";
        var m=Math.floor(s/60);
        var ss=Math.floor(s%60);
        return m+":"+String(ss).padStart(2,"0")
    }

    // ---- matugen colors ----
    MatugenColors {
        id: matugen
        onBaseChanged: if(base) root.cBase = base
        onTextChanged: if(text) root.cText = text
        onMauveChanged: if(mauve) root.cMauve = mauve
        onSubtext0Changed: if(subtext0) root.cSubtext0 = subtext0
        onSurface0Changed: if(surface0) root.cSurface0 = surface0
        onSurface1Changed: if(surface1) root.cSurface1 = surface1
        onOverlay0Changed: if(overlay0) root.cOverlay0 = overlay0
    }

    // ---- music state ----
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string artUrl: ""
    property real position: 0
    property real length: 0
    property bool isPlaying: false
    property var spectrum: []
    property var cavaVals: []
    property bool cavaRunning: false
    property string lastIpcMsg: ""

    // ---- IPC toggle ----
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            ipcPoll.running = false
            ipcPoll.running = true
        }
    }

    Process {
        id: ipcPoll
        command: ["cat", "/tmp/qs_music_state"]
        stdout: StdioCollector {
            onStreamFinished: {
                var msg = text.trim()
                if (!msg || msg === root.lastIpcMsg) return
                root.lastIpcMsg = msg
                if (msg === "toggle") root.visible = !root.visible
                else if (msg === "open") root.visible = true
                else if (msg === "close") root.visible = false
                clearProc.running = true
            }
        }
    }

    Process {
        id: clearProc
        command: ["sh", "-c", ": > /tmp/qs_music_state"]
        running: false
    }

    // ---- playerctl polling ----
    Process {
        id: pMeta
        command: ["sh", "-c", "playerctl metadata title 2>/dev/null; echo '|'; playerctl metadata artist 2>/dev/null; echo '|'; playerctl metadata album 2>/dev/null; echo '|'; playerctl metadata mpris:artUrl 2>/dev/null; echo '|'; playerctl metadata mpris:length 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()
                if (!raw) return
                var parts = raw.split("|")
                if (parts.length >= 1) root.trackTitle = parts[0].trim()
                if (parts.length >= 2) root.trackArtist = parts[1].trim()
                if (parts.length >= 3) root.trackAlbum = parts[2].trim()
                if (parts.length >= 4) root.artUrl = parts[3].trim()
                if (parts.length >= 5) {
                    var lm = parseInt(parts[4].trim())
                    root.length = lm ? lm / 1000000 : 0
                }
            }
        }
    }

    Process {
        id: pStatus
        command: ["playerctl", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isPlaying = (text.trim() === "Playing")
            }
        }
    }

    Process {
        id: pPos
        command: ["playerctl", "position"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseFloat(text.trim())
                if (!isNaN(v)) root.position = v
            }
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            pMeta.running = false; pMeta.running = true
            pStatus.running = false; pStatus.running = true
            pPos.running = false; pPos.running = true
        }
    }

    // ---- cava service ----
    Process {
        id: cavaCheck
        command: ["which", "cava"]
        running: false
        onExited: root.cavaRunning = (exitCode === 0)
    }

    Component.onCompleted: cavaCheck.running = true

    // Start/stop cava on visibility change
    onVisibleChanged: {
        if (visible) {
            cavaProc.running = true
        } else {
            cavaProc.running = false
            cavaVals = []
        }
    }

    Process {
        id: cavaProc
        running: false
        command: [
            "sh", "-c",
            "cat << 'CAVACONF' | cava -p /dev/stdin\n" +
            "[general]\n" +
            "framerate=25\nbars=24\nautosens=0\nsensitivity=30\n" +
            "lower_cutoff_freq=50\nhigher_cutoff_freq=12000\n\n" +
            "[output]\n" +
            "method=raw\nraw_target=/dev/stdout\ndata_format=ascii\n" +
            "channels=mono\nmono_option=average\n\n" +
            "[smoothing]\n" +
            "noise_reduction=35\nintegral=90\ngravity=95\nignore=2\nmonstercat=1.5\n" +
            "CAVACONF"
        ]
        onRunningChanged: { if (!running) root.cavaVals = [] }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(data) {
                if (data.length > 0) {
                    var parts = data.split(";")
                    if (parts.length >= 24) {
                        var vals = []
                        for (var i = 0; i < 24; i++) vals.push(parseInt(parts[i], 10) || 0)
                        root.cavaVals = vals
                    }
                }
            }
        }
    }

    Timer {
        interval: 60; running: true; repeat: true
        onTriggered: {
            var z = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            root.spectrum = root.cavaVals && root.cavaVals.length >= 24 ? root.cavaVals : z
            if (typeof spectrumCanvas !== 'undefined' && spectrumCanvas.available)
                spectrumCanvas.requestPaint()
        }
    }

    // ---- close ----
    Shortcut { sequence: "Escape"; onActivated: root.visible = false }

    // ---- backdrop ----
    Rectangle {
        anchors.fill: parent; radius: 20
        color: a(cBase, 0.88)
        border.width: 1; border.color: a(cText, 0.06)
    }

    // Close button
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10
        width: 26; height: 26; radius: 13; z: 10
        color: a(cSurface1, 0.7)
        border.width: 1; border.color: a(cOverlay0, 0.15)
        Text { anchors.centerIn: parent; text: "✕"; color: a(cText, 0.7); font.pixelSize: 12 }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onEntered: parent.color = a(cMauve, 0.25)
            onExited: parent.color = a(cSurface1, 0.7)
            onClicked: root.visible = false
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 8
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "♫ Now Playing"
            color: cMauve; font.pixelSize: 16; font.weight: Font.Bold; opacity: 0.85
        }

        // Album art + spectrum
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 220; height: 220

            Canvas {
                id: spectrumCanvas
                anchors.fill: parent; antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width/2, cy = height/2
                    var cols = [cMauve, cSubtext0, cMauve]
                    var vals = root.spectrum
                    for (var i = 0; i < 24; i++) {
                        var val = (vals && vals.length > i) ? Math.max(0.02, Math.min(1, vals[i]/100)) : 0.05
                        var angle = (i/24)*2*Math.PI - Math.PI/2
                        var h = 4 + val*40
                        ctx.beginPath()
                        ctx.moveTo(cx+65*Math.cos(angle), cy+65*Math.sin(angle))
                        ctx.lineTo(cx+(65+h)*Math.cos(angle), cy+(65+h)*Math.sin(angle))
                        ctx.strokeStyle = cols[i%3]
                        ctx.lineWidth = 3.5
                        ctx.lineCap = "round"
                        ctx.globalAlpha = 0.5 + val*0.5
                        ctx.stroke()
                    }
                }
            }

            // Glow ring
            Rectangle {
                anchors.centerIn: parent
                width: 136; height: 136; radius: 68
                color: "transparent"
                border.color: a(cMauve, 0.35); border.width: 3
            }

            // Album art container
            Item {
                id: albumArtContainer
                anchors.centerIn: parent
                width: 120; height: 120

                // Placeholder
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: a(cMauve, 0.1)
                    visible: activeArt.source == ""
                    Text {
                        anchors.centerIn: parent
                        text: "🎵"; font.pixelSize: 44; color: a(cMauve, 0.4)
                    }
                }

                // Clipped album art
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2; clip: true
                    Image {
                        id: activeArt
                        anchors.fill: parent
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }
                }

                // Bind image source to artUrl — cache-bust on track change
                property string resolvedArt: {
                    if (!root.artUrl) return ""
                    var path = root.artUrl.startsWith("file://") ? root.artUrl.substring(7) : root.artUrl
                    return path + "?t=" + artReloadToken
                }
                property int artReloadToken: 0
                onResolvedArtChanged: activeArt.source = resolvedArt

                Connections {
                    target: root
                    function onTrackTitleChanged() { albumArtContainer.artReloadToken++ }
                }

                // Rotation
                NumberAnimation on rotation {
                    running: root.isPlaying && activeArt.status === Image.Ready
                    from: 0; to: 360; duration: 8000; loops: Animation.Infinite
                }
                Behavior on scale { NumberAnimation { duration: 200 } }
                scale: albumClick.containsMouse ? 1.05 : 1

                // Click ripple
                MouseArea {
                    id: albumClick
                    anchors.fill: parent; hoverEnabled: true
                    onPressed: {
                        ripple.x = mouse.x - ripple.width/2
                        ripple.y = mouse.y - ripple.height/2
                        ripple.visible = true
                        rippleAnim.start()
                    }
                }
                Rectangle {
                    id: ripple
                    visible: false; width: 0; height: 0; radius: 100
                    color: Qt.rgba(1, 1, 1, 0.25)
                    NumberAnimation on width {
                        id: rippleAnim
                        from: 0; to: 200; duration: 400
                        onStopped: { ripple.visible = false; ripple.width = 0; ripple.height = 0 }
                    }
                    NumberAnimation on height {
                        from: 0; to: 200; duration: 400
                    }
                }
            }
        }

        // Track info
        Text {
            Layout.fillWidth: true
            text: root.trackTitle || "No track"
            color: cText; font.pixelSize: 15; font.weight: Font.Bold
            elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: {
                var parts = []
                if (root.trackArtist) parts.push(root.trackArtist)
                if (root.trackAlbum) parts.push(root.trackAlbum)
                return parts.length ? parts.join(" — ") : "Play some music!"
            }
            color: cSubtext0; font.pixelSize: 12
            elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        }

        // Progress bar
        Rectangle {
            Layout.fillWidth: true; height: 3; radius: 1.5
            color: a(cOverlay0, 0.3)
            Rectangle {
                height: parent.height; radius: 1.5; color: cMauve
                width: root.length > 0 ? (root.position/root.length)*parent.width : 0
                Behavior on width { SmoothedAnimation { velocity: 200 } }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: fmt(root.position); color: cSubtext0; font.pixelSize: 10 }
            Item { Layout.fillWidth: true }
            Text { text: fmt(root.length); color: cSubtext0; font.pixelSize: 10 }
        }

        // Controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter; spacing: 14
            C.CtrlBtn {
                text: "⏮"; cmd: "playerctl previous"
                btnColor: cText; btnBg: cSurface1; btnAccent: cMauve; btnOutline: cOverlay0
            }
            C.CtrlBtn {
                text: root.isPlaying ? "⏸" : "▶"
                btnW: 54; btnH: 54; btnR: 27; btnFs: 22
                cmd: "playerctl play-pause"
                btnColor: cText; btnBg: cSurface1; btnAccent: cMauve; btnOutline: cOverlay0
            }
            C.CtrlBtn {
                text: "⏭"; cmd: "playerctl next"
                btnColor: cText; btnBg: cSurface1; btnAccent: cMauve; btnOutline: cOverlay0
            }
        }
    }
}
