import QtQuick
import qs.Commons

// A 0..1 reading drawn as blocks, for pixel mode: lit blocks in `fillColor`,
// the rest in `trackColor`. Sliders and meters use it in place of a rounded
// track when Style.pixelMode is on.
Item {
  id: root

  property real value: 0
  property color fillColor: Colors.foreground
  property color trackColor: Util.alpha(Colors.foreground, 0.15)
  // A block is `cell` px long with `gap` px between blocks; both default to
  // multiples of the theme's pixel unit so bars and corners share one grid.
  property real cell: Math.max(2, Style.pixelUnit * 3)
  property real gap: Math.max(1, Style.pixelUnit)

  readonly property var blocks: Util.blockLayout(width, cell, gap)
  readonly property int lit: Util.litBlocks(value, blocks.length)

  Repeater {
    model: root.blocks
    Rectangle {
      required property var modelData
      required property int index
      x: modelData.x
      width: modelData.w
      height: root.height
      color: index < root.lit ? root.fillColor : root.trackColor
    }
  }
}
