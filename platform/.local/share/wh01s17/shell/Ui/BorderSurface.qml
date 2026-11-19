import QtQuick
import QtQuick.Effects
import qs.Commons
import "../Commons/BorderGeometry.js" as Geometry

// Rectangle-compatible surface with wh01s17 border specs. Uses native
// Rectangle.border for cheap flat/uniform borders and BorderOverlay for
// gradients or per-side widths.
//
// In pixel mode (Style.pixelMode) the corners are a staircase instead of a
// curve: the fill is cut to that shape and a uniform border is drawn as
// pixel steps. Surfaces too small for a step, or that opt out with
// `pixelCorners: false`, keep their square or rounded look.
Rectangle {
  id: root

  property var borderSpec: Border.none()
  property real padding: 0
  property real topPadding: padding
  property real rightPadding: padding
  property real bottomPadding: padding
  property real leftPadding: padding
  property bool pixelCorners: true
  // Whole-number multiple of the theme's pixel unit, for surfaces drawn at an
  // integer scale (the lock screen on a 4K output).
  property int pixelScale: 1

  readonly property real borderTop: Border.top(borderSpec)
  readonly property real borderRight: Border.right(borderSpec)
  readonly property real borderBottom: Border.bottom(borderSpec)
  readonly property real borderLeft: Border.left(borderSpec)
  readonly property real contentTopInset: borderTop + topPadding
  readonly property real contentRightInset: borderRight + rightPadding
  readonly property real contentBottomInset: borderBottom + bottomPadding
  readonly property real contentLeftInset: borderLeft + leftPadding
  readonly property bool usesOverlayBorder: Border.needsOverlay(borderSpec)

  // Steps that fit: a small chip gets a shallower staircase, a tiny one none.
  readonly property int pixelUnit: Math.max(1, Style.pixelUnit) * Math.max(1, pixelScale)
  readonly property int pixelStepCount: Math.max(0, Math.min(Style.pixelSteps,
    Math.floor(Math.min(width, height) / (3 * pixelUnit))))
  readonly property bool pixelShaped: Style.pixelMode && pixelCorners && pixelStepCount > 0
  readonly property bool pixelBorder: pixelShaped && Border.canUseNative(borderSpec)
    && Border.uniformWidth(borderSpec) > 0
  // A gradient (or per-side) border keeps its overlay for the straight edges;
  // only the steps are added, each pixel run in the gradient's color there.
  readonly property bool pixelOverlaySteps: pixelShaped && usesOverlayBorder && Border.top(borderSpec) > 0
  readonly property var pixelRuns: pixelBorder || pixelOverlaySteps
    ? Util.pixelOutline(width, height, pixelUnit, pixelStepCount, Border.top(borderSpec))
    : []

  function mixColor(a, b, f) {
    var ca = Qt.lighter(a, 1.0)
    var cb = Qt.lighter(b, 1.0)
    return Qt.rgba(ca.r + (cb.r - ca.r) * f, ca.g + (cb.g - ca.g) * f,
                   ca.b + (cb.b - ca.b) * f, ca.a + (cb.a - ca.a) * f)
  }

  function pixelRunColor(run) {
    var g = borderSpec ? borderSpec.gradient : null
    if (!g || !g.enabled || !g.colors || g.colors.length === 0) return Border.color(borderSpec)
    var e = Geometry.gradientEndpoints(width, height, g.angle || 0)
    var dx = e.x2 - e.x1
    var dy = e.y2 - e.y1
    var len = dx * dx + dy * dy
    var t = len > 0 ? ((run.x + run.w / 2 - e.x1) * dx + (run.y + run.h / 2 - e.y1) * dy) / len : 0
    t = Math.max(0, Math.min(1, t))
    var n = g.colors.length
    if (n === 1) return g.colors[0]
    var pos = t * (n - 1)
    var i = Math.min(n - 2, Math.floor(pos))
    return mixColor(g.colors[i], g.colors[i + 1], pos - i)
  }

  border.color: Border.canUseNative(borderSpec) ? Border.color(borderSpec) : "transparent"
  border.width: Border.canUseNative(borderSpec) && !pixelBorder ? Border.uniformWidth(borderSpec) : 0

  layer.enabled: pixelShaped
  layer.effect: MultiEffect {
    maskEnabled: true
    maskSource: pixelMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0
  }

  // The staircase as a mask: one band per step, each narrower than the last
  // toward the top and bottom edges.
  Item {
    id: pixelMask
    width: root.width
    height: root.height
    visible: false
    layer.enabled: root.pixelShaped

    Repeater {
      model: root.pixelShaped ? root.pixelStepCount + 1 : 0
      Rectangle {
        required property int index
        readonly property real inset: (root.pixelStepCount - index) * root.pixelUnit
        x: inset
        y: index * root.pixelUnit
        width: Math.max(0, root.width - 2 * inset)
        height: Math.max(0, root.height - 2 * y)
        color: "white"
      }
    }
  }

  // The border along the staircase, as runs of pixels.
  // The first four runs are the straight edges, which an overlay already draws.
  Repeater {
    model: root.pixelOverlaySteps ? root.pixelRuns.slice(4) : root.pixelRuns
    Rectangle {
      required property var modelData
      x: modelData.x
      y: modelData.y
      z: 100001
      width: modelData.w
      height: modelData.h
      color: root.pixelOverlaySteps ? root.pixelRunColor(modelData) : Border.color(root.borderSpec)
    }
  }

  Loader {
    anchors.fill: parent
    active: root.usesOverlayBorder

    sourceComponent: BorderOverlay {
      anchors.fill: parent
      radius: root.radius
      borderSpec: root.borderSpec
    }
  }
}
