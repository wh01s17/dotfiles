import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

// wh01s17: the W mark replaces the wh01s17 glyph in this frozen copy.
BarWidget {
  id: root
  moduleName: "core.menu"

  readonly property real markHeight: Math.round(Style.font.body * 1.25)
  readonly property real markWidth: Math.round(markHeight * 336 / 304)

  // A terminal cursor blinks after the W while notification popups are on
  // screen, the way a prompt waits for input.
  readonly property var notificationService: bar?.shell?.firstPartyServiceFor("core.notifications")
  readonly property bool notifying: !!notificationService && notificationService.popupCount > 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    horizontalMargin: 7.5
    fixedWidth: root.vertical ? -1 : root.markWidth + scaledHorizontalMargin * 2
    tooltipText: "Menú"
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("wh01s17-shell shell toggle core.menu '{\"menu\":\"root\"}'")
    }

    Shape {
      anchors.centerIn: parent
      width: root.markWidth
      height: root.markHeight
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        readonly property real unit: root.markHeight / 304
        fillColor: "transparent"
        strokeColor: Colors.accent
        strokeWidth: 1.4
        joinStyle: ShapePath.MiterJoin
        scale: Qt.size(unit, unit)
        PathSvg { path: "M0 0h80v240H0zm128 0h80v240h-80zm128 0h80v240h-80zM64 240h80v64H64zm128 0h80v64h-80z" }
      }
    }

    Rectangle {
      id: cursor
      visible: root.notifying && !root.vertical
      x: (parent.width + root.markWidth) / 2 + Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(3)
      height: root.markHeight
      color: Colors.accent

      Timer {
        running: cursor.visible
        interval: 530
        repeat: true
        onTriggered: cursor.opacity = cursor.opacity > 0 ? 0 : 1
        onRunningChanged: cursor.opacity = 1
      }
    }
  }
}
