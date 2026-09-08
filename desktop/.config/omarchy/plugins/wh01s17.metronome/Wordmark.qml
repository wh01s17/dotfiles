import QtQuick
import qs.Commons

// The wh01s17 mark: three standing bars with two half-bars stepping down
// between them. Drawn from proportions rather than an image so it stays
// crisp at bar-icon size and takes the theme's accent like everything else.
//
// The geometry is expressed in units of 1/217th of the height, which is the
// mark's own grid: bars are 58 wide on an 89 pitch, 172 tall, and the two
// half-bars are 45 tall, inset 43 from their bar's left edge.
Item {
  id: root

  property color stroke: Color.accent
  property color fillColor: "transparent"
  property real strokeWidth: Math.max(1, Math.round(height / 40))
  // 0 = outline only, 1 = solid. The beat pulse animates this.
  property real fillStrength: 0

  readonly property real u: height / 217
  readonly property real barWidth: 58 * u
  readonly property real pitch: 89 * u
  readonly property real tallHeight: 172 * u
  readonly property real shortHeight: 45 * u
  readonly property real shortInset: 43 * u

  implicitWidth: height * (236 / 217)
  implicitHeight: 24
  width: implicitWidth

  Repeater {
    model: 3
    delegate: Rectangle {
      required property int index
      x: index * root.pitch
      y: 0
      width: root.barWidth
      height: root.tallHeight
      color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b,
                     root.fillColor.a * root.fillStrength)
      border.width: root.strokeWidth
      border.color: root.stroke
    }
  }

  Repeater {
    model: 2
    delegate: Rectangle {
      required property int index
      x: index * root.pitch + root.shortInset
      y: root.tallHeight
      width: root.barWidth
      height: root.shortHeight
      color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b,
                     root.fillColor.a * root.fillStrength)
      border.width: root.strokeWidth
      border.color: root.stroke
    }
  }
}
