import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omarchy.monitor"
  ipcTarget: "omarchy.monitor"
  manageIpc: false

  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the brightness + state methods below.
  property int brightnessPercent: 0
  property int pendingBrightnessPercent: 0
  property bool brightnessSetQueued: false
  property bool brightnessAvailable: false
  property string internalMonitor: ""
  property string externalMonitor: ""
  property string focusedMonitor: ""
  property bool internalEnabled: false
  property bool mirrorEnabled: false
  property string monitorScale: ""
  property var displays: []
  property int enabledDisplayCount: 0

  // name -> { options, current } for every connected output, refreshed from
  // `hyprctl monitors all -j` alongside the rest of the panel state.
  property var monitorModes: ({})
  // Mode chosen in the combobox while the change is in flight, so the trigger
  // label doesn't snap back during the reload round-trip.
  property string pendingMode: ""

  readonly property var focusedModeOptions: {
    var entry = monitorModes ? monitorModes[focusedMonitor] : null
    return entry && entry.options ? entry.options : []
  }
  readonly property string focusedModeValue: {
    var entry = monitorModes ? monitorModes[focusedMonitor] : null
    return entry && entry.current ? String(entry.current) : ""
  }
  readonly property string effectiveModeValue: pendingMode !== "" ? pendingMode : focusedModeValue
  readonly property string focusedModeLabel: {
    var value = effectiveModeValue
    var options = focusedModeOptions
    for (var i = 0; i < options.length; i++) {
      if (String(options[i].value) === value) return String(options[i].label)
    }
    return value
  }
  readonly property string focusedModeSummary: {
    if (focusedMonitor === "") return focusedModeLabel
    if (focusedModeLabel === "") return focusedMonitor
    return focusedMonitor + " · " + focusedModeLabel
  }

  // Display layout saved in monitor-layout.conf, which survives reloads and
  // reboots. Machine profiles only place the outputs, so no file means extend.
  readonly property var layoutOptions: [
    { value: "extend", label: "Extend" },
    { value: "mirror", label: "Mirror" },
    { value: "internal", label: "Laptop" },
    { value: "external", label: "External" }
  ]
  property string savedLayout: "extend"
  // Layout picked while the reload is in flight, so the pill doesn't snap back.
  property string pendingLayout: ""
  readonly property string activeLayout: pendingLayout !== "" ? pendingLayout : savedLayout
  readonly property bool layoutAvailable: internalMonitor !== "" && displays.length > 1

  // Extend arrangement editor, opened by right-clicking Extend. Rects are in
  // Hyprland's logical space ({ name, x, y, w, h }); monitorGeometry is the
  // live layout from `hyprctl monitors all -j`.
  property var monitorGeometry: []
  property bool arrangeOpen: false
  property var arrangeRects: []

  // Carry sub-notch touchpad deltas between wheel events.
  property real wheelAccumulator: 0

  // Cursor model shared by keyboard and mouse. Sections:
  //   "brightness" - single slider row, selectedIndex = -1 sentinel
  //                  (mirrors Audio's slider rows). Only present if a
  //                  controllable backlight was detected.
  //   "layout"     - extend/mirror/laptop/external pills; a horizontal row
  //                  like "scale". Only present with a laptop panel plus at
  //                  least one other output.
  //   "scale"      - 6 Button scale presets; treated as a single
  //                  horizontal row from j/k's perspective. h/l moves
  //                  between presets, identical to bluetooth's header.
  //   "monitors"   - vertical display row list for enabling/disabling displays;
  //                  j/k walks each row.
  // Mouse hover on a target updates root state via the components' `hovered`
  // signal so keyboard cursor and pointer share one highlight.
  readonly property var scalePresets: ["1", "1.25", "1.6", "2", "3", "4"]
  readonly property var scaleValues: {
    for (var i = 0; i < displays.length; i++) {
      var display = displays[i]
      if (display && display.focused)
        return Model.availableScales(scalePresets, display.width, display.height)
    }
    return scalePresets
  }
  property string focusSection: "scale"
  property int selectedIndex: 0
  property bool cursorActive: false

  readonly property var visibleSections: {
    var list = []
    if (brightnessAvailable) list.push("brightness")
    if (focusedModeOptions.length > 0) list.push("resolution")
    list.push("scale")
    if (displays.length > 1) list.push("monitors")
    if (layoutAvailable) list.push("layout")
    return list
  }

  function sectionCount(section) {
    if (section === "brightness") return 0  // only the slider sentinel at -1
    if (section === "resolution") return 0  // lone combobox, sentinel at -1
    if (section === "layout") return layoutOptions.length
    if (section === "scale") return scaleValues.length
    if (section === "monitors") return displays.length
    return 0
  }

  function sectionIsSingleRow(section) {
    // Brightness and resolution are lone controls; layout and scale pills sit
    // horizontally.
    return section === "brightness" || section === "resolution" || section === "layout" || section === "scale"
  }

  function sectionFirstIndex(section) {
    if (section === "brightness" || section === "resolution") return -1
    return 0
  }

  function moveCursor(delta) {
    var sections = visibleSections
    if (!sections || sections.length === 0) return
    var sIdx = sections.indexOf(focusSection)
    if (sIdx < 0) {
      focusSection = sections[0]
      selectedIndex = sectionFirstIndex(focusSection)
      return
    }
    var inSingleRow = sectionIsSingleRow(focusSection)
    var max = inSingleRow ? 0 : sectionCount(focusSection) - 1

    if (delta > 0) {
      if (!inSingleRow && selectedIndex < max) { selectedIndex = selectedIndex + 1; return }
      if (sIdx < sections.length - 1) {
        focusSection = sections[sIdx + 1]
        selectedIndex = sectionFirstIndex(focusSection)
      }
    } else {
      if (!inSingleRow && selectedIndex > 0) { selectedIndex = selectedIndex - 1; return }
      if (sIdx > 0) {
        var prev = sections[sIdx - 1]
        focusSection = prev
        // Coming up from below — land on the last navigable row of the prev
        // section, or its sentinel for single-row sections.
        selectedIndex = sectionIsSingleRow(prev) ? sectionFirstIndex(prev) : sectionCount(prev) - 1
      }
    }
  }

  // h/l: in the layout and scale sections, walks the pill row; everywhere
  // else, no-op because adjustBrightness handles horizontal motion on the
  // brightness slider.
  function moveCursorH(delta) {
    if (focusSection !== "layout" && focusSection !== "scale") return
    var count = sectionCount(focusSection)
    var next = selectedIndex + delta
    if (next < 0) next = 0
    if (next > count - 1) next = count - 1
    selectedIndex = next
  }

  function adjustBrightness(delta) {
    if (focusSection !== "brightness") return
    if (!brightnessAvailable) return
    setBrightness(root.brightnessPercent + delta)
  }

  function activateCursor() {
    if (focusSection === "resolution") {
      modeDropdown.toggle()
      return
    }
    if (focusSection === "layout" && selectedIndex >= 0 && selectedIndex < layoutOptions.length) {
      setLayout(layoutOptions[selectedIndex].value)
      return
    }
    if (focusSection === "scale" && selectedIndex >= 0 && selectedIndex < scaleValues.length) {
      setScale(scaleValues[selectedIndex])
      return
    }
    if (focusSection === "monitors" && selectedIndex >= 0 && selectedIndex < displays.length) {
      var d = displays[selectedIndex]
      if (d) toggleDisplay(d.name, d.enabled)
    }
    // brightness: no separate action; the slider value is the action.
  }

  function clampCursor() {
    var sections = visibleSections
    if (!sections || !sections.length) return
    if (sections.indexOf(focusSection) < 0) {
      focusSection = sections[0]
      selectedIndex = sectionFirstIndex(focusSection)
      return
    }
    var count = sectionCount(focusSection)
    if (sectionIsSingleRow(focusSection)) {
      // Brightness/resolution use the -1 sentinel; layout/scale clamp into pills.
      if (focusSection === "brightness" || focusSection === "resolution") selectedIndex = -1
      else if (selectedIndex < 0 || selectedIndex >= count) selectedIndex = 0
      return
    }
    if (count === 0) {
      var sIdx = sections.indexOf(focusSection)
      focusSection = sIdx > 0 ? sections[sIdx - 1] : sections[0]
      selectedIndex = sectionFirstIndex(focusSection)
      return
    }
    if (selectedIndex > count - 1) selectedIndex = count - 1
    if (selectedIndex < 0) selectedIndex = 0
  }

  // Keep the keyboard-focused row inside the viewport when the panel grows
  // taller than its allotted height (lots of displays). Mirrors audio's
  // ensureCursorVisible helper.
  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var pt = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = pt.y
    var bottom = top + (item.height || 0)
    var viewTop = flick.contentY
    var viewBottom = viewTop + flick.height
    var margin = 6
    if (top < viewTop + margin) flick.contentY = Math.max(0, top - margin)
    else if (bottom > viewBottom - margin)
      flick.contentY = bottom + margin - flick.height
  }

  function brightnessIpc(percent) {
    var value = Number(percent)
    root.setBrightness(value)
    return "got " + root.pendingBrightnessPercent
  }

  function stateIpc() {
    return JSON.stringify({
      brightness: root.brightnessPercent,
      brightnessAvailable: root.brightnessAvailable,
      focusedMonitor: root.focusedMonitor,
      layout: root.activeLayout,
      resolution: root.focusedModeLabel,
      scale: root.monitorScale,
      displays: root.displays
    })
  }

  IpcHandler {
    target: "omarchy.monitor"

    function brightness(percent: string): string { return root.brightnessIpc(percent) }
    function state(): string { return root.stateIpc() }
    function open() { root.open() }
    function close() { root.close() }
    function toggle() { root.toggle() }
    function show() { root.open() }
    function hide() { root.close() }
    function arrange() {
      root.open()
      root.openArrangement()
    }
  }

  function refresh() {
    if (!stateProc.running) stateProc.running = true
    if (!modesProc.running) modesProc.running = true
    if (!layoutProc.running) layoutProc.running = true
  }

  function setBrightness(value) {
    var percent = Model.clampBrightness(value)
    root.brightnessPercent = percent
    root.pendingBrightnessPercent = percent

    if (setBrightnessProc.running) {
      root.brightnessSetQueued = true
      return
    }

    root.brightnessSetQueued = false
    setBrightnessProc.command = ["omarchy-brightness-display", "--no-osd", "--monitor", root.focusedMonitor, percent + "%"]
    setBrightnessProc.running = true
  }

  function previewBrightness(value) {
    root.brightnessPercent = Model.clampBrightness(value)
    brightnessDebounce.restart()
  }

  function showBrightnessOsd(percent) {
    if (!bar || !bar.shell) return
    bar.shell.summon("omarchy.osd", JSON.stringify({
      icon: "brightness",
      value: percent
    }))
  }

  function normalizeScale(scale) {
    return Model.normalizeScale(scale)
  }

  function activeScaleIndex() {
    for (var i = 0; i < displays.length; i++) {
      var display = displays[i]
      if (display && display.focused)
        return Model.matchingScaleIndex(scaleValues, monitorScale, display.width, display.height)
    }
    return -1
  }

  function effectiveScale(scale) {
    for (var i = 0; i < displays.length; i++) {
      var display = displays[i]
      if (display && display.focused)
        return Model.cleanScale(scale, display.width, display.height)
    }
    return normalizeScale(scale)
  }

  // Playful mood-name for a given brightness percent. Bands intentionally
  // span ~10–20 points so casual tweaks change the label, while small
  // nudges within one band don't.
  function brightnessName(percent) {
    return Model.brightnessName(percent)
  }

  function updateDisplays(displaysJson) {
    var parsed = Model.parseDisplays(displaysJson)
    root.displays = parsed.displays
    root.enabledDisplayCount = parsed.enabledDisplayCount
  }

  function toggleDisplay(name, enabled) {
    if (!name) return
    if (enabled && root.enabledDisplayCount <= 1) return

    actionProc.command = ["hyprctl", "keyword", "monitor", name + (enabled ? ",disable" : ",preferred,auto,auto")]
    if (!actionProc.running) actionProc.running = true
  }

  // Persist the chosen mode for this output, then reload so monitors.lua
  // re-applies every rule with the new geometry (positions included) instead
  // of leaving a one-off `hyprctl keyword` that the next reload would undo.
  function setMode(mode) {
    var name = String(root.focusedMonitor || "")
    var value = String(mode || "")
    // Both land inside the shell snippet below, so only plain connector names
    // and WxH@rate values may pass.
    if (!/^[A-Za-z0-9._-]+$/.test(name)) return
    if (!/^[0-9]+x[0-9]+@[0-9.]+$/.test(value)) return
    if (value === root.focusedModeValue) return

    root.pendingMode = value
    actionProc.command = ["bash", "-c",
      'dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"; ' +
      'mkdir -p "$dir" || exit 1; ' +
      'file="$dir/monitor-modes.conf"; ' +
      'tmp=$(mktemp "$file.XXXXXX") || exit 1; ' +
      'if [ -f "$file" ]; then grep -v "^' + name + '=" "$file" >>"$tmp"; fi; ' +
      'printf "%s=%s\\n" "' + name + '" "' + value + '" >>"$tmp"; ' +
      'mv "$tmp" "$file" && hyprctl reload']
    if (!actionProc.running) actionProc.running = true
  }

  function setScale(scale) {
    // The stock command records the focused output and applies it live. Reload
    // afterwards so the user monitor profile restores its scale-aware layout.
    actionProc.command = ["bash", "-c", "omarchy-hyprland-monitor-scaling " + scale + " && hyprctl reload"]
    if (!actionProc.running) actionProc.running = true
  }

  // Layouts are applied by ~/.config/hypr/monitor_layout.lua on reload.
  // External-only also goes through Omarchy's internal-monitor-disable toggle:
  // the clamshell watcher re-enables the laptop panel every 2s unless that
  // toggle is set. Omarchy's own mirror toggle is cleared so it can't fight
  // the chosen layout.
  function setLayout(layout) {
    if (String(layout || "") === root.activeLayout) return
    runLayout(layout, "keep", "")
  }

  // arrangementAction: "keep" leaves monitor-arrangement.conf alone, "write"
  // replaces it with `arrangement`, "clear" drops it so the profile's own
  // placement returns.
  function runLayout(layout, arrangementAction, arrangement) {
    var value = String(layout || "")
    var internal = String(root.internalMonitor || "")
    var valid = false
    for (var i = 0; i < layoutOptions.length; i++) {
      if (layoutOptions[i].value === value) valid = true
    }
    if (!valid || !/^[A-Za-z0-9._-]+$/.test(internal)) return

    root.pendingLayout = value
    actionProc.command = ["bash", "-c",
      'dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"; ' +
      'file="$dir/monitor-layout.conf"; ' +
      'omarchy-hyprland-monitor-internal-mirror off >/dev/null; ' +
      'mkdir -p "$dir" && printf "layout=%s\\ninternal=%s\\n" "$1" "$2" >"$file.tmp" && mv "$file.tmp" "$file" || exit 1; ' +
      'arr="$dir/monitor-arrangement.conf"; ' +
      'if [ "$3" = write ]; then printf "%s\\n" "$4" >"$arr.tmp" && mv "$arr.tmp" "$arr" || exit 1; ' +
      'elif [ "$3" = clear ]; then rm -f "$arr"; fi; ' +
      // An output leaving mirror mode on a reload stays hidden from clients
      // (no bar, no wallpaper, unknown to grim). Switching it off first makes
      // the reload bring it back as a fresh output.
      'if [ "$1" != mirror ]; then ' +
      'for m in $(hyprctl monitors all -j | jq -r \'.[] | select(.mirrorOf != "none" and .disabled != true) | .name | select(test("^[A-Za-z0-9._-]+$"))\'); do ' +
      'hyprctl eval "hl.monitor({ output = \\"$m\\", disabled = true })" >/dev/null; unmirrored=1; done; ' +
      '[ -n "$unmirrored" ] && sleep 1; fi; ' +
      'if [ "$1" = external ]; then hyprctl reload >/dev/null && omarchy-hyprland-monitor-internal off; ' +
      'else omarchy-hyprland-monitor-internal on; hyprctl reload >/dev/null; fi',
      "bash", value, internal, arrangementAction, arrangement]
    if (!actionProc.running) actionProc.running = true
  }

  function openArrangement() {
    root.arrangeRects = Model.initialArrangement(root.monitorGeometry, root.internalMonitor)
    root.arrangeOpen = root.arrangeRects.length > 1
    if (root.arrangeOpen) Qt.callLater(function() { root.ensureCursorVisible(arrangeEditor) })
  }

  // Snap a dropped display against its neighbours, like Windows does.
  function moveArranged(index, x, y) {
    var rects = root.arrangeRects.map(function(r) {
      return { name: r.name, x: r.x, y: r.y, w: r.w, h: r.h }
    })
    if (index < 0 || index >= rects.length) return
    var spot = Model.snapPosition(rects, index, x, y)
    rects[index].x = spot.x
    rects[index].y = spot.y
    root.arrangeRects = rects
  }

  function applyArrangement() {
    var lines = Model.arrangementLines(root.arrangeRects, root.internalMonitor)
    // Lines land in a file monitor_layout.lua parses; only plain connector
    // names and integers may pass.
    for (var i = 0; i < lines.length; i++) {
      if (!/^(root=[A-Za-z0-9._-]+|[A-Za-z0-9._-]+=[A-Za-z0-9._-]+,(right|left|above|below),-?[0-9]+)$/.test(lines[i])) return
    }
    root.arrangeOpen = false
    root.pendingLayout = "extend"
    runLayout("extend", "write", lines.join("\n"))
  }

  function resetArrangement() {
    root.arrangeOpen = false
    root.pendingLayout = "extend"
    runLayout("extend", "clear", "")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  // KeyboardPanel primes focus at open-time, so SUPER-bound IPC summons land
  // with j/k ready to navigate. Keep a default landing point, but don't paint
  // the cursor until hover or the first navigation key.
  onOpenedChanged: {
    if (opened) {
      refresh()
      if (brightnessAvailable) {
        focusSection = "brightness"
        selectedIndex = -1
      } else {
        focusSection = "scale"
        selectedIndex = 0
      }
      cursorActive = false
      arrangeOpen = false
    }
  }

  onBrightnessAvailableChanged: clampCursor()
  onFocusedModeOptionsChanged: clampCursor()
  onDisplaysChanged: clampCursor()
  onScaleValuesChanged: clampCursor()
  onVisibleSectionsChanged: clampCursor()

  // Only poll while the panel is open; the bar glyph tracks monitor count via
  // Quickshell.screens, and open-time refresh + Component.onCompleted cover the
  // rest. External brightness changes are reflected whenever the panel is open.
  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: stateProc
    command: ["omarchy-monitor-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        var brightness = String(lines[0] || "").trim()
        root.brightnessAvailable = brightness !== "unavailable" && brightness !== ""
        root.brightnessPercent = root.brightnessAvailable ? Math.max(0, Math.min(100, parseInt(brightness, 10))) : 0
        root.internalMonitor = String(lines[1] || "").trim()
        root.externalMonitor = String(lines[2] || "").trim()
        root.internalEnabled = String(lines[3] || "").trim() !== ""
        root.mirrorEnabled = String(lines[4] || "").trim() === root.externalMonitor && root.externalMonitor !== ""
        root.focusedMonitor = String(lines[5] || "").trim()
        root.monitorScale = root.normalizeScale(String(lines[6] || "").trim())
        root.updateDisplays(String(lines[7] || "[]").trim())
      }
    }
  }

  Process {
    id: modesProc
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.monitorModes = Model.parseMonitorModes(text)
        root.monitorGeometry = Model.parseGeometry(text)
        // Whatever the reload settled on is authoritative now; drop the
        // optimistic label even if the mode didn't take.
        root.pendingMode = ""
      }
    }
  }

  Process {
    id: layoutProc
    command: ["bash", "-c", 'cat "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/monitor-layout.conf" 2>/dev/null']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var match = String(text || "").match(/^layout=(\w+)\s*$/m)
        root.savedLayout = match ? match[1] : "extend"
        root.pendingLayout = ""
      }
    }
  }

  Timer {
    id: brightnessDebounce
    interval: 180
    repeat: false
    onTriggered: root.setBrightness(root.brightnessPercent)
  }

  Process {
    id: setBrightnessProc
    stdout: StdioCollector { waitForEnd: true }
    // Do NOT call refresh() after a brightness set completes. The local
    // brightnessPercent we just wrote is authoritative; re-reading via
    // `omarchy-brightness-display` races the hardware/driver and can
    // return an empty string, which the parser then coerces to 0 —
    // visible as a "bounce to zero" after h/l keypresses. External
    // brightness changes are still picked up by the 5s periodic refresh,
    // the open-time refresh, and Component.onCompleted.
    onRunningChanged: {
      if (running) return
      if (root.brightnessSetQueued) {
        root.setBrightness(root.pendingBrightnessPercent)
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Quickshell.screens.length > 1 ? "󰍺" : "󰍹"
    tooltipText: {
      var scale = Screen.devicePixelRatio
      var scaleText = isFinite(scale) && scale > 0
        ? " · escala " + (Math.round(scale * 100) / 100)
        : ""
      var lines = [String(Screen.name || "?") + " · "
        + Math.round(Screen.width) + "×" + Math.round(Screen.height) + scaleText]
      var others = []
      var screens = Quickshell.screens || []
      for (var i = 0; i < screens.length; i++) {
        var s = screens[i]
        if (!s || String(s.name || "") === String(Screen.name || "")) continue
        others.push(String(s.name || "?") + " · " + Math.round(s.width) + "×" + Math.round(s.height))
      }
      if (others.length > 0) lines.push("Otras · " + others.join(", "))
      return lines.join("\n")
    }
    onPressed: function(b) { root.toggle() }
    onWheelMoved: function(delta) {
      if (!root.brightnessAvailable) return
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      root.setBrightness(root.brightnessPercent + wheel.steps * 5)
      root.showBrightnessOsd(root.brightnessPercent)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    // The arrangement editor needs room for its canvas and buttons.
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(root.arrangeOpen ? 840 : 560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // While the mode popup owns the keys, freeze the panel cursor so j/k
      // inside the list doesn't also walk the sections behind it.
      blocked: modeDropdown.popupOpen
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) {
          if (root.focusSection === "brightness") root.adjustBrightness(dx * 5)
          else root.moveCursorH(dx)
        }
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // ---------- Hero: display icon · title/status ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              text: root.displays.length > 1 ? "󰍺" : "󰍹"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Display"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                id: heroLabel
                text: {
                  if (root.brightnessAvailable) {
                    return root.brightnessName(brightnessSlider.dragging ? brightnessSlider.liveValue : root.brightnessPercent).toUpperCase()
                  }
                  return "FIXED BRIGHTNESS"
                }
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          // ---------- Brightness ----------
          PanelSeparator {
            visible: root.brightnessAvailable
            foreground: root.bar.foreground
          }

          Column {
            visible: root.brightnessAvailable
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(brightnessHeader.implicitHeight, brightnessPercent.implicitHeight)

              PanelSectionHeader {
                id: brightnessHeader
                text: "BRIGHTNESS"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: brightnessPercent
                text: Math.round(brightnessSlider.dragging ? brightnessSlider.liveValue : root.brightnessPercent) + "%"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              id: brightnessRow
              width: parent.width
              height: brightnessSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "brightness" && root.selectedIndex === -1
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(brightnessRow)
              foreground: root.bar.foreground
              outline: true

              PanelSlider {
                id: brightnessSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 1
                maximum: 100
                step: 1
                value: root.brightnessPercent
                integer: true
                onMoved: function(v) { root.previewBrightness(v) }
                onReleased: function(v) {
                  brightnessDebounce.stop()
                  root.setBrightness(v)
                }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.focusSection = "brightness"
                  root.selectedIndex = -1
                }
              }
            }
          }

          // ---------- Resolution ----------
          PanelSeparator {
            visible: root.focusedModeOptions.length > 0
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: root.focusedModeOptions.length > 0

            Item {
              width: parent.width
              implicitHeight: Math.max(resolutionHeader.implicitHeight, resolutionMonitor.implicitHeight)

              PanelSectionHeader {
                id: resolutionHeader
                text: "RESOLUTION"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              // Like SCALE, this only ever targets the focused output.
              Text {
                id: resolutionMonitor
                text: root.focusedModeSummary
                visible: root.focusedModeSummary !== ""
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Dropdown {
              id: modeDropdown
              width: parent.width
              showLabel: false
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              options: root.focusedModeOptions
              hasCursor: root.cursorActive && root.focusSection === "resolution" && root.selectedIndex === -1
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(modeDropdown)
              onChanged: function(value) { root.setMode(value) }
              onHovered: function(isHovered) {
                if (!isHovered) return
                root.cursorActive = true
                root.focusSection = "resolution"
                root.selectedIndex = -1
              }
            }

            // Selecting inside the popup writes Dropdown.value directly, which
            // would clobber a plain binding — a Binding element re-asserts the
            // live mode once the reload lands.
            Binding {
              target: modeDropdown
              property: "value"
              value: root.effectiveModeValue
            }
          }

          // ---------- Scale ----------
          PanelSeparator {
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(10)

            Item {
              width: parent.width
              implicitHeight: Math.max(scaleHeader.implicitHeight, scaleMonitor.implicitHeight)

              PanelSectionHeader {
                id: scaleHeader
                text: "SCALE"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              // Name the monitor SCALE targets, since it only applies to the
              // focused one.
              Text {
                id: scaleMonitor
                text: root.focusedMonitor
                // Only worth naming when more than one display is in play.
                visible: root.focusedMonitor !== "" && root.enabledDisplayCount > 1
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Grid {
              id: scaleRow
              width: parent.width
              columns: root.scaleValues.length
              spacing: Style.spacing.xs

              readonly property real cellWidth: root.scaleValues.length > 0
                ? (width - spacing * (columns - 1)) / columns
                : 0

              Repeater {
                model: root.scaleValues

                ScalePill {
                  required property string modelData
                  required property int index

                  scaleValue: modelData
                  scaleIndex: index
                  width: scaleRow.cellWidth
                }
              }
            }
          }

          // ---------- Monitors ----------
          PanelSeparator {
            visible: root.displays.length > 1
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.displays.length > 1

            PanelSectionHeader {
              text: "DISPLAYS"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Repeater {
              model: root.displays

              MonitorRow {
                required property var modelData
                required property int index

                width: panelColumn.width
                display: modelData
                rowIndex: index
              }
            }
          }

          // ---------- Layout ----------
          PanelSeparator {
            visible: root.layoutAvailable
            foreground: root.bar.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.layoutAvailable

            PanelSectionHeader {
              text: "LAYOUT"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Grid {
              id: layoutRow
              width: parent.width
              columns: root.layoutOptions.length
              spacing: Style.spacing.xs

              readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

              Repeater {
                model: root.layoutOptions

                LayoutPill {
                  required property var modelData
                  required property int index

                  layoutValue: modelData.value
                  text: modelData.label
                  layoutIndex: index
                  width: layoutRow.cellWidth
                }
              }
            }

            // Windows-style arrangement: drag the numbered displays, drop
            // snaps them flush against a neighbour, Apply saves and extends.
            Column {
              id: arrangeEditor
              width: parent.width
              spacing: Style.space(8)
              visible: root.arrangeOpen

              Rectangle {
                id: arrangeCanvas
                width: parent.width
                height: Style.space(170)
                color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.05)
                clip: true

                readonly property real pad: Style.space(14)
                readonly property var bounds: {
                  var rects = root.arrangeRects
                  if (!rects || rects.length === 0) return { x: 0, y: 0, w: 1, h: 1 }
                  var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
                  for (var i = 0; i < rects.length; i++) {
                    minX = Math.min(minX, rects[i].x)
                    minY = Math.min(minY, rects[i].y)
                    maxX = Math.max(maxX, rects[i].x + rects[i].w)
                    maxY = Math.max(maxY, rects[i].y + rects[i].h)
                  }
                  return { x: minX, y: minY, w: maxX - minX, h: maxY - minY }
                }
                readonly property real k: Math.min((width - pad * 2) / bounds.w, (height - pad * 2) / bounds.h)
                readonly property real ox: (width - bounds.w * k) / 2 - bounds.x * k
                readonly property real oy: (height - bounds.h * k) / 2 - bounds.y * k

                Repeater {
                  model: root.arrangeRects

                  ArrangeTile {
                    required property var modelData
                    required property int index

                    rect: modelData
                    tileIndex: index
                  }
                }
              }

              Row {
                anchors.right: parent.right
                spacing: Style.spacing.xs

                Button {
                  text: "Reset"
                  tooltipText: "Back to the machine profile's placement"
                  fontSize: Style.font.caption
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  bordered: true
                  onClicked: root.resetArrangement()
                }

                Button {
                  text: "Cancel"
                  fontSize: Style.font.caption
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  bordered: true
                  onClicked: root.arrangeOpen = false
                }

                Button {
                  text: "Apply"
                  fontSize: Style.font.caption
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  bordered: true
                  active: true
                  onClicked: root.applyArrangement()
                }
              }
            }
          }

          Item {
            width: parent.width
            height: Style.space(4)
          }
        }
      }
    }
  }

  component ScalePill: Button {
    id: pill
    required property string scaleValue
    required property int scaleIndex

    text: root.effectiveScale(scaleValue) + "x"
    fontSize: Style.font.caption
    foreground: root.bar.foreground
    fontFamily: root.bar.fontFamily
    horizontalPadding: Style.spacing.sm
    verticalPadding: Style.spacing.controlPaddingY
    bordered: true

    active: root.activeScaleIndex() === scaleIndex
    hasCursor: root.cursorActive && root.focusSection === "scale" && root.selectedIndex === scaleIndex

    onClicked: root.setScale(scaleValue)
    onHovered: function(isHovered) {
      if (!isHovered) return
      root.cursorActive = true
      root.focusSection = "scale"
      root.selectedIndex = pill.scaleIndex
    }
  }

  component LayoutPill: Button {
    id: layoutPill
    required property string layoutValue
    required property int layoutIndex

    fontSize: Style.font.caption
    foreground: root.bar.foreground
    fontFamily: root.bar.fontFamily
    horizontalPadding: Style.spacing.sm
    verticalPadding: Style.spacing.controlPaddingY
    bordered: true

    active: root.activeLayout === layoutValue
    hasCursor: root.cursorActive && root.focusSection === "layout" && root.selectedIndex === layoutIndex

    tooltipText: layoutValue === "extend" ? "Right-click to arrange displays" : ""

    onClicked: root.setLayout(layoutValue)
    onRightClicked: if (layoutValue === "extend") root.openArrangement()
    onHovered: function(isHovered) {
      if (!isHovered) return
      root.cursorActive = true
      root.focusSection = "layout"
      root.selectedIndex = layoutPill.layoutIndex
    }
  }

  component ArrangeTile: Rectangle {
    id: tile
    required property var rect
    required property int tileIndex

    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property real grabX: 0
    property real grabY: 0

    x: dragging ? dragX : arrangeCanvas.ox + rect.x * arrangeCanvas.k
    y: dragging ? dragY : arrangeCanvas.oy + rect.y * arrangeCanvas.k
    z: dragging ? 1 : 0
    width: rect.w * arrangeCanvas.k
    height: rect.h * arrangeCanvas.k
    color: dragging || tileMouse.containsMouse
      ? Style.selectedFillFor(root.bar.foreground, Color.accent)
      : Style.hoverFillFor(root.bar.foreground, Color.accent)
    border.color: dragging ? Color.accent : root.bar.foreground
    border.width: 1

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -Style.space(4)
      text: String(tile.tileIndex + 1)
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Math.max(Style.font.body, Math.min(tile.height * 0.4, Style.font.display))
      font.bold: true
    }

    Text {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(3)
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width - Style.space(6)
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      text: tile.rect.name
      color: Qt.darker(root.bar.foreground, 1.3)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: tileMouse
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      onPressed: function(mouse) {
        var p = mapToItem(arrangeCanvas, mouse.x, mouse.y)
        tile.grabX = p.x - tile.x
        tile.grabY = p.y - tile.y
        tile.dragX = tile.x
        tile.dragY = tile.y
        tile.dragging = true
      }
      onPositionChanged: function(mouse) {
        if (!tile.dragging) return
        var p = mapToItem(arrangeCanvas, mouse.x, mouse.y)
        tile.dragX = p.x - tile.grabX
        tile.dragY = p.y - tile.grabY
      }
      onReleased: {
        if (!tile.dragging) return
        var lx = (tile.dragX - arrangeCanvas.ox) / arrangeCanvas.k
        var ly = (tile.dragY - arrangeCanvas.oy) / arrangeCanvas.k
        tile.dragging = false
        root.moveArranged(tile.tileIndex, lx, ly)
      }
      onCanceled: tile.dragging = false
    }
  }

  component MonitorRow: CursorSurface {
    id: monitorRow
    required property var display
    required property int rowIndex

    readonly property bool isFocused: display && display.focused
    readonly property bool canToggle: display && (!display.enabled || root.enabledDisplayCount > 1)

    hasCursor: root.cursorActive && root.focusSection === "monitors" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(monitorRow)
    current: isFocused
    foreground: root.bar.foreground
    fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
    currentFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
    implicitHeight: monitorInner.implicitHeight + Style.spacing.xl
    opacity: canToggle ? 1.0 : 0.45

    Row {
      id: monitorInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: "󰍹"
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: monitorRow.display.name + (monitorRow.display.focused ? " · focused" : "")
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - Style.space(14) - Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: monitorRow.display.enabled ? "󰄬" : ""
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.subtitle
        width: Style.space(14)
        horizontalAlignment: Text.AlignRight
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: monitorRow.canToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "monitors"
        root.selectedIndex = monitorRow.rowIndex
      }
      onClicked: if (monitorRow.canToggle) root.toggleDisplay(monitorRow.display.name, monitorRow.display.enabled)
    }
  }
}
