import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Metronome for the bar. The mark in the bar beats along with the click, so
// the widget is its own downbeat when the panel is closed.
//
// State, settings, and the engine process live in MetronomeCore — the bar
// puts one of these on every monitor and they all have to agree. This file
// is the view: the bar mark, the panel, and the controls.
//
// Left click opens the panel, right click starts and stops without opening
// it, middle click taps the tempo, and the wheel over the mark nudges it.
Panel {
  id: root
  moduleName: "wh01s17.metronome"
  ipcTarget: "wh01s17.metronome"
  manageIpc: false

  readonly property var core: MetronomeCore
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accentColor: Color.accent
  readonly property color backgroundColor: bar ? bar.background : Color.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The core has no route to shell.json; whichever surface comes up first
  // lends it this one.
  function persistSettings(values) {
    if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function") return
    root.settings = Object.assign({}, root.settings, values)
    bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  onSettingsChanged: core.loadSettings(settings)

  Component.onCompleted: {
    if (!core.host) core.host = root
    core.loadSettings(settings)
  }

  Component.onDestruction: if (core.host === root) core.host = null

  IpcHandler {
    target: "wh01s17.metronome"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function play(): void { root.core.start() }
    function pause(): void { root.core.stop() }
    function togglePlay(): void { root.core.togglePlay() }
    function tap(): void { root.core.tap() }
    function setBpm(value: string): void { root.core.setBpm(parseInt(value, 10)) }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ------------------------------------------------------------ bar mark

  Component {
    id: markComponent

    Wordmark {
      anchors.centerIn: parent
      height: Math.round(parent.height * 0.86)
      stroke: root.core.running ? root.accentColor : root.foreground
      fillColor: root.accentColor
      fillStrength: root.core.beatPulse
      opacity: root.core.running ? 1.0 : 0.85

      Behavior on opacity { NumberAnimation { duration: 150 } }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: markComponent
    tooltipText: root.core.running ? "Metronome · " + root.core.signature : "Metronome"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.core.togglePlay()
      else if (b === Qt.MiddleButton) root.core.tap()
      else root.toggle()
    }
    onWheelMoved: function(delta) { root.core.nudgeBpm(delta > 0 ? 1 : -1) }
  }

  // --------------------------------------------------------------- panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(388))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.core.nudgeBpm(dx)
        else if (dy !== 0) root.core.nudgeBpm(dy > 0 ? -5 : 5)
      }
      onActivateRequested: root.core.togglePlay()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "t") root.core.tap()
        else if (text === "a") root.core.toggleAccent()
        else if (text === "[") root.core.setBeats(root.core.beats - 1)
        else if (text === "]") root.core.setBeats(root.core.beats + 1)
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(13)

        // ------------------------------------------------------- header
        Item {
          width: parent.width
          implicitHeight: Math.max(headerMark.height, headerLabels.implicitHeight)

          Wordmark {
            id: headerMark
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: Style.space(28)
            stroke: root.accentColor
            fillColor: root.accentColor
            fillStrength: root.core.beatPulse
          }

          Column {
            id: headerLabels
            anchors.left: headerMark.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)

            Text {
              textFormat: Text.PlainText
              text: "METRONOME"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              font.letterSpacing: 3
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.core.signature
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // --------------------------------------------- dial and steppers
        Item {
          width: parent.width
          // The scale stops 40 degrees short of the bottom, so the last
          // sliver of the dial's box is air. Don't reserve column space for
          // it or the beat bars float away from the gauge.
          implicitHeight: Math.round(dial.height * 0.88)

          Column {
            id: leftSteppers
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: Math.round(dial.height * 0.22)
            spacing: Style.space(7)

            Repeater {
              model: [-10, -5, -1]

              delegate: Button {
                required property var modelData
                text: String(modelData)
                bordered: true
                foreground: root.foreground
                background: root.backgroundColor
                accent: root.accentColor
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                horizontalPadding: Style.space(9)
                verticalPadding: Style.space(5)
                onClicked: root.core.nudgeBpm(Number(modelData))
              }
            }
          }

          TempoDial {
            id: dial
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: Math.min(Style.space(238), parent.width - Style.space(112))
            height: width
            foreground: root.foreground
            accent: root.accentColor
            fontFamily: root.fontFamily
            bpm: root.core.bpm
            running: root.core.running
            pulse: root.core.beatPulse
            onBpmRequested: function(value) { root.core.setBpm(value) }
            onToggleRequested: root.core.togglePlay()
          }

          Column {
            id: rightSteppers
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: Math.round(dial.height * 0.22)
            spacing: Style.space(7)

            Repeater {
              model: [10, 5, 1]

              delegate: Button {
                required property var modelData
                text: "+" + modelData
                bordered: true
                foreground: root.foreground
                background: root.backgroundColor
                accent: root.accentColor
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                horizontalPadding: Style.space(9)
                verticalPadding: Style.space(5)
                onClicked: root.core.nudgeBpm(Number(modelData))
              }
            }
          }
        }

        // ---------------------------------------------------- beat bars
        //
        // The readout is cut from the same shapes as the mark: the accented
        // downbeat stands full height, the rest are half-bars, and the beat
        // being played is filled. Clicking one sets the bar length.
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)
          height: Style.space(28)

          Repeater {
            model: root.core.beats

            delegate: Rectangle {
              required property int index
              readonly property bool downbeat: index === 0
              readonly property bool current: root.core.running && root.core.currentBeat === index

              width: Style.space(13)
              height: downbeat ? Style.space(28) : Style.space(17)
              anchors.verticalCenter: parent.verticalCenter
              color: current
                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b,
                          downbeat ? 0.9 : 0.55)
                : "transparent"
              border.width: Math.max(1, Style.space(1))
              border.color: current
                ? root.accentColor
                : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3)

              Behavior on color { ColorAnimation { duration: 80 } }
              Behavior on border.color { ColorAnimation { duration: 80 } }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.core.setBeats(index + 1)
              }
            }
          }
        }

        // ----------------------------------------------- tap / bar length
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Button {
            text: "TAP"
            bordered: true
            foreground: root.foreground
            background: root.backgroundColor
            accent: root.accentColor
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            horizontalPadding: Style.space(20)
            onClicked: root.core.tap()
          }

          Button {
            text: "−"
            bordered: true
            foreground: root.foreground
            background: root.backgroundColor
            accent: root.accentColor
            fontFamily: root.fontFamily
            onClicked: root.core.setBeats(root.core.beats - 1)
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: root.core.beats + "/4"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Button {
            text: "+"
            bordered: true
            foreground: root.foreground
            background: root.backgroundColor
            accent: root.accentColor
            fontFamily: root.fontFamily
            onClicked: root.core.setBeats(root.core.beats + 1)
          }

          Button {
            text: "ACCENT"
            bordered: true
            selected: root.core.accentDownbeat
            foreground: root.foreground
            background: root.backgroundColor
            accent: root.accentColor
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            onClicked: root.core.toggleAccent()
          }
        }

        PanelSeparator { foreground: root.foreground }

        // --------------------------------------------------- subdivisions
        Grid {
          width: parent.width
          columns: 3
          columnSpacing: Style.space(7)
          rowSpacing: Style.space(7)

          Repeater {
            model: Model.SUBDIVISIONS

            delegate: Button {
              required property var modelData

              text: modelData.label + "  " + modelData.pattern
              bordered: true
              selected: root.core.subdivision === modelData.value
              foreground: root.foreground
              background: root.backgroundColor
              accent: root.accentColor
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              implicitWidth: (column.width - Style.space(14)) / 3
              onClicked: root.core.setSubdivision(modelData.value)
            }
          }
        }

        // ---------------------------------------------------------- level
        Item {
          width: parent.width
          implicitHeight: levelSlider.implicitHeight

          Text {
            id: levelLabel
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "LEVEL"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }

          PanelSlider {
            id: levelSlider
            bar: root.bar
            anchors.left: levelLabel.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            minimum: 0
            maximum: 1
            step: 0.05
            value: root.core.volume
            fillColor: root.accentColor
            knobColor: root.accentColor
            onMoved: function(value) { root.core.setVolume(value) }
            onReleased: function(value) { root.core.setVolume(value) }
          }
        }
      }
    }
  }
}
