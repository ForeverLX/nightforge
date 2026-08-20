import QtQuick

Canvas {
    id: canvas
    property color lineColor: "#89b4fa"
    property int lineWidth: 2
    property real amplitude: 20
    property real speed: 2
    property real frequency: 0.05

    property real _offset: 0
    property var _points: []
    property int _maxPoints: 0

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        if (_points.length < 2) return

        ctx.strokeStyle = lineColor
        ctx.lineWidth = lineWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        ctx.beginPath()
        ctx.moveTo(_points[0].x, _points[0].y)

        for (var i = 1; i < _points.length; i++) {
            ctx.lineTo(_points[i].x, _points[i].y)
        }
        ctx.stroke()
    }

    Timer {
        interval: 16  // ~60fps
        running: canvas.visible
        repeat: true
        onTriggered: {
            _offset += speed
            _maxPoints = Math.floor(width)

            var centerY = height / 2
            var newPoints = []

            for (var x = 0; x < _maxPoints; x += 2) {
                var y = centerY

                // Combine multiple sine waves for ECG-like pattern
                var wave1 = Math.sin((x + _offset) * frequency) * amplitude * 0.3
                var wave2 = Math.sin((x + _offset) * frequency * 2.3) * amplitude * 0.2
                var wave3 = Math.sin((x + _offset) * frequency * 0.7) * amplitude * 0.5

                // Add occasional spike (QRS-like)
                var spikePhase = ((x + _offset) * frequency * 0.3) % (Math.PI * 2)
                var spike = 0
                if (spikePhase > 0.1 && spikePhase < 0.4) {
                    spike = -Math.sin((spikePhase - 0.1) / 0.3 * Math.PI) * amplitude * 1.5
                }

                y += wave1 + wave2 + wave3 + spike
                newPoints.push({x: x, y: y})
            }

            _points = newPoints
            canvas.requestPaint()
        }
    }
}
