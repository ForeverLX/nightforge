import QtQuick

Canvas {
    id: chart
    property color lineColor: "#89b4fa"
    property color fillColor: "#89b4fa"
    property real fillOpacity: 0.15
    property int lineWidth: 2
    property var dataPoints: []
    property int maxPoints: 60

    onDataPointsChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        if (dataPoints.length < 2) return

        var stepX = width / (maxPoints - 1)
        var points = []

        for (var i = 0; i < dataPoints.length; i++) {
            var x = width - ((dataPoints.length - 1 - i) * stepX)
            var y = height - (dataPoints[i] / 100 * height)
            points.push({x: x, y: y})
        }

        // Fill area under line
        ctx.fillStyle = fillColor
        ctx.globalAlpha = fillOpacity
        ctx.beginPath()
        ctx.moveTo(points[0].x, height)
        for (var j = 0; j < points.length; j++) {
            ctx.lineTo(points[j].x, points[j].y)
        }
        ctx.lineTo(points[points.length - 1].x, height)
        ctx.closePath()
        ctx.fill()
        ctx.globalAlpha = 1.0

        // Draw line
        ctx.strokeStyle = lineColor
        ctx.lineWidth = lineWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()
        ctx.moveTo(points[0].x, points[0].y)
        for (var k = 1; k < points.length; k++) {
            ctx.lineTo(points[k].x, points[k].y)
        }
        ctx.stroke()
    }
}
