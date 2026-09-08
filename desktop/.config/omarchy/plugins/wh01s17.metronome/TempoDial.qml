import QtQuick
import qs.Commons
import "Model.js" as Model

// Tempo dial. The scale is built from discrete tick marks rather than a
// painted arc: ticks take the theme's colors directly, cost nothing to
// repaint when the tempo moves, and give the gauge the squared-off look the
// rest of this widget is cut from.
//
// The whole face is one control — drag vertically or scroll to change the
// tempo, click the hub to start and stop.
Item {
  id: root

  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  property int bpm: 100
  property bool running: false
  // Lights the hub for one beat; the panel pokes this on every downbeat.
  property real pulse: 0

  readonly property int minimum: Model.MIN_BPM
  readonly property int maximum: Model.MAX_BPM
  readonly property int tickStep: 5
  readonly property int tickCount: (maximum - minimum) / tickStep + 1
  readonly property int majorEvery: 4          // one label per 20 BPM
  readonly property real sweep: 280            // degrees of scale
  readonly property real startAngle: -sweep / 2

  signal bpmRequested(int value)
  signal toggleRequested()

  implicitWidth: 200
  implicitHeight: 200

  readonly property real radius: Math.min(width, height) / 2
  readonly property real minorLength: radius * 0.062
  readonly property real majorLength: radius * 0.12
  readonly property real hubSize: Math.round(radius * 0.86)

  function angleFor(value) {
    var t = (value - minimum) / Math.max(1, maximum - minimum)
    return startAngle + t * sweep
  }

  // --------------------------------------------------------------- scale

  Repeater {
    model: root.tickCount

    delegate: Item {
      required property int index
      readonly property int value: root.minimum + index * root.tickStep
      readonly property bool major: index % root.majorEvery === 0
      readonly property bool reached: value <= root.bpm

      width: Math.max(1, Math.round(root.radius * (major ? 0.028 : 0.016)))
      height: root.radius
      x: root.width / 2 - width / 2
      y: root.height / 2 - root.radius
      transformOrigin: Item.Bottom
      rotation: root.angleFor(value)

      Rectangle {
        width: parent.width
        height: parent.major ? root.majorLength : root.minorLength
        y: 0
        color: parent.reached ? root.accent : root.foreground
        opacity: parent.reached ? (parent.major ? 1.0 : 0.75) : 0.18

        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
      }
    }
  }

  // Scale labels sit inside the ticks. Positioned by trigonometry so they
  // stay upright instead of tipping over with their tick.
  Repeater {
    model: Math.floor((root.tickCount - 1) / root.majorEvery) + 1

    delegate: Text {
      required property int index
      readonly property int value: root.minimum + index * root.majorEvery * root.tickStep
      readonly property real radians: root.angleFor(value) * Math.PI / 180
      readonly property real ring: root.radius - root.majorLength - root.radius * 0.145

      textFormat: Text.PlainText
      text: String(value)
      color: value <= root.bpm ? root.accent : root.foreground
      opacity: value <= root.bpm ? 0.9 : 0.35
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      x: root.width / 2 + Math.sin(radians) * ring - width / 2
      y: root.height / 2 - Math.cos(radians) * ring - height / 2

      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
  }

  // ----------------------------------------------------------------- hub

  Rectangle {
    id: hub
    anchors.centerIn: parent
    width: root.hubSize
    height: root.hubSize
    radius: width / 2
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b,
                   0.06 + 0.22 * root.pulse)
    border.width: Math.max(1, Math.round(root.radius * 0.014))
    border.color: root.running
      ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45 + 0.55 * root.pulse)
      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3)

    Behavior on color { ColorAnimation { duration: 90 } }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(1)

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.running ? "STOP" : "START"
        color: root.running ? root.accent : root.foreground
        opacity: 0.75
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 2
      }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: String(root.bpm)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Math.round(Style.font.displayLarge * 1.15)
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: Model.tempoName(root.bpm).toUpperCase()
        color: root.accent
        opacity: 0.8
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.4
      }
    }
  }

  // ------------------------------------------------------------- gesture

  MouseArea {
    id: face
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    property real anchorY: 0
    property int anchorBpm: 0
    property bool dragging: false

    onPressed: function(mouse) {
      anchorY = mouse.y
      anchorBpm = root.bpm
      dragging = false
    }

    onPositionChanged: function(mouse) {
      if (!pressed) return
      var delta = anchorY - mouse.y
      if (!dragging && Math.abs(delta) < 4) return
      dragging = true
      // A full dial height of travel covers the whole range; the pointer
      // never has to leave the widget to get from 40 to 240.
      var span = Math.max(60, root.height)
      var next = Model.clampBpm(anchorBpm + Math.round(delta / span * (root.maximum - root.minimum)))
      if (next !== root.bpm) root.bpmRequested(next)
    }

    onReleased: {
      if (dragging) { dragging = false; return }
      // Only the hub toggles: a click out on the scale would otherwise start
      // the click track when the user meant to grab the dial.
      var dx = mouseX - root.width / 2
      var dy = mouseY - root.height / 2
      if (Math.sqrt(dx * dx + dy * dy) <= root.hubSize / 2) root.toggleRequested()
    }

    onWheel: function(wheel) {
      var step = (wheel.modifiers & Qt.ShiftModifier) ? 5 : 1
      root.bpmRequested(Model.clampBpm(root.bpm + (wheel.angleDelta.y > 0 ? step : -step)))
    }
  }
}
