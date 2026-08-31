import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

WidgetButton {
  id: root

  property string moduleName: ""
  property var settings: ({})
  property string outputText: ""
  property string outputTooltip: ""
  property var outputClass: ""
  property var outputPanel: ({})
  property string pendingAction: ""
  property bool panelOpen: false

  readonly property bool panelEnabled: setting("panel", false) === true
  readonly property var panelData: outputPanel && typeof outputPanel === "object" ? outputPanel : ({})
  readonly property var panelRows: Array.isArray(panelData.rows) ? panelData.rows : []
  readonly property var panelActions: Array.isArray(panelData.actions) ? panelData.actions : []
  readonly property color panelForeground: bar ? bar.barForeground : Color.foreground
  readonly property color panelAccent: classColor()
  readonly property bool opened: panelOpen
  readonly property real openPanelIndicatorWidth: richLabel.visible ? richLabel.implicitWidth : 0
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function classes() {
    if (Array.isArray(outputClass)) return outputClass
    var value = String(outputClass || "")
    return value ? [value] : []
  }

  function hasClass(name) {
    return classes().indexOf(name) !== -1
  }

  function classColor() {
    var colors = setting("classColors", {})
    var values = classes()
    for (var index = 0; index < values.length; index++) {
      if (colors[values[index]]) return String(colors[values[index]])
    }
    if (colors.default) return String(colors.default)
    return bar ? bar.barForeground : "white"
  }

  function isDimmed() {
    var values = setting("dimClasses", [])
    if (!Array.isArray(values)) return false
    for (var index = 0; index < values.length; index++) {
      if (hasClass(String(values[index]))) return true
    }
    return false
  }

  function update(raw) {
    var value = String(raw || "").trim()
    if (!value) {
      outputText = ""
      outputTooltip = String(setting("tooltip", ""))
      outputClass = ""
      outputPanel = ({})
      return
    }

    var lines = value.split("\n")
    var data
    try {
      data = JSON.parse(lines[lines.length - 1])
    } catch (error) {
      data = { text: value }
    }

    outputText = data.text === undefined || data.text === null ? value : String(data.text)
    outputTooltip = data.tooltip === undefined || data.tooltip === null
      ? String(setting("tooltip", ""))
      : String(data.tooltip)
    outputClass = data.class || data.alt || ""
    outputPanel = data.panel && typeof data.panel === "object" ? data.panel : ({})
  }

  function refresh() {
    if (String(setting("exec", "")) && !statusProcess.running) statusProcess.running = true
  }

  function runAction(command) {
    var value = String(command || "")
    if (!value || actionProcess.running) return
    pendingAction = value
    actionProcess.running = true
  }

  function runPanelAction(action) {
    if (!action || action.enabled === false) return
    if (action.close === true) close()
    runAction(String(action.command || ""))
  }

  function open() {
    if (panelEnabled) panelOpen = true
  }

  function close() {
    panelOpen = false
  }

  function toggle() {
    panelOpen ? close() : open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  readonly property bool hasActions:
    String(setting("onClick", "")) !== ""
    || String(setting("onMiddleClick", "")) !== ""
    || String(setting("onRightClick", "")) !== ""
    || String(setting("onScrollUp", "")) !== ""
    || String(setting("onScrollDown", "")) !== ""

  text: outputText || String(setting("text", ""))
  tooltipText: outputTooltip || String(setting("tooltip", ""))
  foreground: classColor()
  useActiveColor: false
  dimmed: isDimmed()
  keepSpace: setting("keepSpace", false) === true
  horizontalMargin: Number(setting("horizontalMargin", 7.5))
  verticalPadding: Number(setting("verticalPadding", 6))
  fontSize: Number(setting("fontSize", 12))
  interactive: hasActions || tooltipText !== ""
  pressable: hasActions

  // WidgetButton's own label is locked to Text.PlainText (Omarchy 4.0.2), so
  // scripts that emit Pango markup (e.g. ctf-ip.sh's <font color='...'>
  // segments) would otherwise show the raw tags. Hide that label and paint
  // our own on top with StyledText, which still degrades to plain text for
  // modules that never emit markup.
  labelVisible: false
  fixedWidth: hasVisualContent ? richLabel.implicitWidth + scaledHorizontalMargin * 2 : -1

  Text {
    id: richLabel
    visible: root.hasVisualContent
    anchors.centerIn: parent
    text: root.text
    textFormat: Text.StyledText
    color: root.active && root.useActiveColor ? root.activeColor : root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  onPressed: function(button) {
    if (button === Qt.RightButton)
      runAction(setting("onRightClick", ""))
    else if (button === Qt.MiddleButton)
      runAction(setting("onMiddleClick", ""))
    else if (panelEnabled)
      toggle()
    else
      runAction(setting("onClick", ""))
  }

  onWheelMoved: function(delta) {
    runAction(delta > 0 ? setting("onScrollUp", "") : setting("onScrollDown", ""))
  }

  Process {
    id: statusProcess
    command: ["bash", "-lc", String(root.setting("exec", ""))]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.update(text)
    }
  }

  Process {
    id: actionProcess
    command: ["bash", "-lc", root.pendingAction]
    onExited: {
      root.pendingAction = ""
      refreshDelay.restart()
    }
  }

  Timer {
    interval: Math.max(1, Number(root.setting("interval", 5))) * 1000
    running: String(root.setting("exec", "")) !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshDelay
    interval: 150
    onTriggered: root.refresh()
  }

  onPanelEnabledChanged: if (!panelEnabled) close()
  onPanelOpenChanged: if (panelOpen) refresh()

  PopupCard {
    id: panel
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.panelOpen && root.panelEnabled
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(620))

    Column {
      id: panelColumn
      anchors.fill: parent
      spacing: Style.space(14)

      Item {
        width: parent.width
        implicitHeight: Math.max(Style.space(58), heroIcon.implicitHeight, heroCopy.implicitHeight, heroValue.implicitHeight)

        BorderSurface {
          id: heroIcon
          width: Style.space(54)
          height: width
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.panelAccent, Color.accent)
          borderSpec: Border.controlSpec("normal", root.panelAccent, Color.accent)

          Text {
            anchors.centerIn: parent
            text: String(root.panelData.icon || "󰋼")
            color: root.panelAccent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.display
          }
        }

        Column {
          id: heroCopy
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(14)
          anchors.right: heroValue.visible ? heroValue.left : parent.right
          anchors.rightMargin: heroValue.visible ? Style.space(12) : 0
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Text {
            width: parent.width
            text: String(root.panelData.title || root.moduleName || "Estado")
            color: root.panelForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            visible: text !== ""
            text: String(root.panelData.subtitle || "")
            color: Qt.darker(root.panelForeground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }

        Text {
          id: heroValue
          visible: text !== ""
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: String(root.panelData.headline || "")
          color: root.panelAccent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.displayLarge
          font.bold: true
        }
      }

      Item {
        readonly property real progress: {
          var value = Number(root.panelData.progress)
          return isFinite(value) ? Math.max(0, Math.min(1, value)) : -1
        }

        visible: progress >= 0
        width: parent.width
        implicitHeight: visible ? Style.space(7) : 0

        Rectangle {
          id: progressTrack
          anchors.fill: parent
          radius: height / 2
          color: Qt.rgba(root.panelForeground.r, root.panelForeground.g, root.panelForeground.b, 0.12)
        }

        Rectangle {
          anchors.left: progressTrack.left
          anchors.verticalCenter: progressTrack.verticalCenter
          height: progressTrack.height
          width: progressTrack.width * parent.progress
          radius: progressTrack.radius
          color: root.panelAccent

          Behavior on width {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
          }
        }
      }

      PanelSeparator {
        visible: root.panelRows.length > 0
        foreground: root.panelForeground
      }

      Column {
        width: parent.width
        visible: root.panelRows.length > 0
        spacing: Style.space(7)

        PanelSectionHeader {
          text: String(root.panelData.sectionTitle || "DETALLES")
          foreground: root.panelForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Repeater {
          model: root.panelRows

          BorderSurface {
            id: detailRow
            required property var modelData

            readonly property color accentColor: modelData && modelData.color
              ? String(modelData.color)
              : root.panelAccent

            width: parent.width
            implicitHeight: detailContent.implicitHeight + Style.space(12)
            radius: Style.cornerRadius
            color: Style.normalFillFor(accentColor, Color.accent)
            borderSpec: Border.controlSpec("normal", accentColor, Color.accent)

            Row {
              id: detailContent
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: detailRow.contentLeftInset + Style.space(10)
              anchors.rightMargin: detailRow.contentRightInset + Style.space(10)
              spacing: Style.space(10)

              Text {
                width: Style.space(24)
                anchors.verticalCenter: parent.verticalCenter
                text: String(detailRow.modelData.icon || "󰋼")
                color: detailRow.accentColor
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.icon
                horizontalAlignment: Text.AlignHCenter
              }

              Column {
                width: Math.max(0, parent.width - Style.space(34) - detailValue.width - parent.spacing * 2)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: String(detailRow.modelData.label || "")
                  color: root.panelForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: text !== ""
                  text: String(detailRow.modelData.detail || "")
                  color: Qt.darker(root.panelForeground, 1.5)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                id: detailValue
                width: Math.min(implicitWidth, detailContent.width * 0.48)
                anchors.verticalCenter: parent.verticalCenter
                text: String(detailRow.modelData.value || "—")
                color: detailRow.accentColor
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }
      }

      Text {
        visible: root.panelRows.length === 0 && text !== ""
        width: parent.width
        text: String(root.panelData.description || root.outputTooltip || "")
        color: root.panelForeground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }

      PanelSeparator {
        visible: root.panelActions.length > 0
        foreground: root.panelForeground
      }

      Column {
        width: parent.width
        visible: root.panelActions.length > 0
        spacing: Style.space(8)

        PanelSectionHeader {
          text: String(root.panelData.actionsTitle || "ACCIONES")
          foreground: root.panelForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Grid {
          id: actionGrid
          width: parent.width
          columns: 2
          spacing: Style.space(7)
          readonly property real cellWidth: (width - spacing) / columns

          Repeater {
            model: root.panelActions

            Button {
              required property var modelData
              width: actionGrid.cellWidth
              text: String(modelData.label || "")
              iconText: String(modelData.icon || "")
              foreground: root.panelForeground
              accent: root.panelAccent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              fontSize: Style.font.bodySmall
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              bordered: true
              active: modelData.active === true
              enabled: modelData.enabled !== false
              opacity: enabled ? 1 : 0.4
              onClicked: root.runPanelAction(modelData)
            }
          }
        }
      }
    }
  }
}
