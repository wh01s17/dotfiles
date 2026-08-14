import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

WidgetButton {
  id: root

  property string moduleName: ""
  property var settings: ({})
  property string outputText: ""
  property string outputTooltip: ""
  property var outputClass: ""
  property string pendingAction: ""

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

  onPressed: function(button) {
    if (button === Qt.RightButton)
      runAction(setting("onRightClick", ""))
    else if (button === Qt.MiddleButton)
      runAction(setting("onMiddleClick", ""))
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
}
