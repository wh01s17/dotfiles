import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "core.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      // Numbers only: the focused workspace in accent over a short pixel
      // bar, occupied ones in the bar foreground, empty ones dimmed.
      Item {
        id: slot
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property color ink: root.bar ? root.bar.barForeground : Colors.foreground

        Layout.preferredWidth: root.vertical ? root.barSize : Style.space(18)
        Layout.preferredHeight: root.vertical ? Style.space(20) : root.barSize

        Text {
          id: label
          anchors.centerIn: parent
          text: slot.modelData === 10 ? "0" : String(slot.modelData)
          color: slot.focused ? Colors.accent : slot.ink
          opacity: slot.focused || slot.occupied || mouse.containsMouse ? 1 : 0.35
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          renderType: Text.NativeRendering
        }

        Rectangle {
          anchors.horizontalCenter: label.horizontalCenter
          anchors.top: label.bottom
          width: slot.focused ? Style.space(8) : 0
          height: Style.space(2)
          color: Colors.accent
          Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        // A MouseArea, like WidgetButton's, so the press is not lost to the
        // bar's drag-to-reorder handling.
        readonly property bool tooltipHovered: mouse.containsMouse
        readonly property int windows: workspace ? workspace.toplevels.values.length : 0

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusWorkspace(slot.modelData)
          onEntered: if (root.bar) root.bar.showTooltip(slot, "Escritorio " + (slot.modelData === 10 ? "0" : slot.modelData)
            + (slot.windows === 1 ? " · 1 ventana" : slot.windows > 1 ? " · " + slot.windows + " ventanas" : " · vacío"))
          onExited: if (root.bar) root.bar.hideTooltip(slot)
        }
      }
    }
  }
}
