import QtQuick
import qs.Commons

// The bar mark: an analog metronome — a tapered case on a plinth with the
// pendulum rod and its sliding weight. The wh01s17 wordmark stays inside the
// panel; the bar gets something that reads as "metronome" at a glance.
//
// Drawn on a canvas from proportions of the height, so it stays crisp at
// bar-icon size and takes the theme colours. While running, the rod swings
// to the opposite side on every beat, taking one beat to get there.
Item {
  id: root

  property color stroke: Color.accent
  property color fillColor: "transparent"
  property real strokeWidth: Math.max(1.5, height / 10)
  // 0 = outline only, 1 = solid. The beat pulse animates this.
  property real fillStrength: 0
  property bool running: false
  // Increments once per beat; its parity picks the side the rod swings to.
  property int beatCount: 0
  property int bpm: 100

  // Resting lean, so the idle icon still reads as a metronome rather than a
  // triangle with a line through it.
  readonly property real restAngle: 18
  readonly property real swingAngle: 24
  property real angle: running ? (beatCount % 2 === 0 ? -swingAngle : swingAngle) : restAngle

  Behavior on angle {
    NumberAnimation {
      duration: root.running ? Math.round(60000 / Math.max(1, root.bpm)) : 180
      easing.type: Easing.InOutSine
    }
  }

  implicitWidth: Math.round(height * 0.86)
  implicitHeight: 24
  width: implicitWidth

  onStrokeChanged: canvas.requestPaint()
  onFillColorChanged: canvas.requestPaint()
  onFillStrengthChanged: canvas.requestPaint()
  onStrokeWidthChanged: canvas.requestPaint()
  onAngleChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: true
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      var w = width, h = height
      var lw = root.strokeWidth
      var half = lw / 2
      ctx.reset()
      ctx.lineWidth = lw
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.strokeStyle = root.stroke

      // Case: a trapezoid, narrow at the top, standing on the plinth.
      var topY = h * 0.08 + half
      var baseY = h * 0.80
      var topHalf = w * 0.13
      var baseHalf = w * 0.40 - half
      var cx = w / 2

      ctx.beginPath()
      ctx.moveTo(cx - topHalf, topY)
      ctx.lineTo(cx + topHalf, topY)
      ctx.lineTo(cx + baseHalf, baseY)
      ctx.lineTo(cx - baseHalf, baseY)
      ctx.closePath()
      ctx.fillStyle = Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b,
                              root.fillColor.a * root.fillStrength * 0.45)
      ctx.fill()
      ctx.stroke()

      // Plinth.
      ctx.strokeRect(half, baseY, w - lw, h - half - baseY)

      // Pendulum: pivots low in the case and reaches past its top.
      var pivotY = h * 0.70
      var length = h * 0.70
      var rad = root.angle * Math.PI / 180
      var tipX = cx + Math.sin(rad) * length
      var tipY = pivotY - Math.cos(rad) * length

      ctx.beginPath()
      ctx.moveTo(cx, pivotY)
      ctx.lineTo(tipX, tipY)
      ctx.stroke()

      // Sliding weight, a little over halfway up the rod.
      var t = 0.62
      var wx = cx + Math.sin(rad) * length * t
      var wy = pivotY - Math.cos(rad) * length * t
      var r = Math.max(lw * 1.3, h * 0.1)
      ctx.save()
      ctx.translate(wx, wy)
      ctx.rotate(rad)
      ctx.fillStyle = root.stroke
      ctx.fillRect(-r, -r * 0.8, r * 2, r * 1.6)
      ctx.restore()
    }
  }
}
