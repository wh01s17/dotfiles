pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// The metronome itself: one click track, one engine process, one set of
// settings, shared by every bar surface. The widget files are views onto
// this — the bar puts one instance of the widget on each monitor, and all of
// them have to agree about the tempo and beat where they can all be seen.
//
// Timing is not kept here either. metronome-engine.py synthesises the click
// sample by sample and reports each pulse as it becomes audible; QML would
// drift by whole milliseconds under load, which a musician hears at once.
Item {
  id: core

  // ------------------------------------------------------------- settings

  property int bpm: 100
  property int beats: 4
  property string subdivision: "1/4"
  property real volume: 0.7
  property bool accentDownbeat: true
  property bool settingsLoaded: false

  // --------------------------------------------------------- live state

  property bool running: false
  property int currentBeat: 0
  property int currentPulse: 0
  property real beatPulse: 0
  property var tapTimes: []

  // The widget instance that can reach shell.json. Whichever surface loads
  // first claims it; they are interchangeable.
  property var host: null

  readonly property string enginePath: String(Qt.resolvedUrl("metronome-engine.py")).replace("file://", "")
  readonly property string signature: bpm + " BPM · " + beats + "/4 · " + Model.subdivisionLabel(subdivision)

  // ------------------------------------------------------------- settings

  // Read once rather than bound: a binding would be broken by the first
  // control the user touches and then silently reset on the next write back
  // to shell.json.
  function loadSettings(settings) {
    if (settingsLoaded || !settings) return
    function read(key, fallback) {
      var value = settings[key]
      return value === undefined || value === null ? fallback : value
    }
    bpm = Model.clampBpm(read("bpm", 100))
    beats = Math.max(1, Math.min(16, Math.round(Number(read("beats", 4)))))
    var sub = read("subdivision", "1/4")
    subdivision = Model.isSubdivision(sub) ? sub : "1/4"
    volume = Math.max(0, Math.min(1, Number(read("volume", 0.7))))
    accentDownbeat = read("accent", true) === true
    settingsLoaded = true
  }

  function persist() {
    if (host && typeof host.persistSettings === "function")
      host.persistSettings({
        bpm: core.bpm,
        beats: core.beats,
        subdivision: core.subdivision,
        volume: Math.round(core.volume * 100) / 100,
        accent: core.accentDownbeat
      })
  }

  // -------------------------------------------------------------- actions

  function setBpm(value) {
    var next = Model.clampBpm(value)
    if (next === bpm) return
    bpm = next
    pushState()
    persistTimer.restart()
  }

  function nudgeBpm(delta) { setBpm(bpm + delta) }

  function setBeats(value) {
    var next = Math.max(1, Math.min(16, Math.round(value)))
    if (next === beats) return
    beats = next
    if (currentBeat >= beats) currentBeat = 0
    pushState()
    persistTimer.restart()
  }

  function setSubdivision(value) {
    if (value === subdivision || !Model.isSubdivision(value)) return
    subdivision = value
    pushState()
    persistTimer.restart()
  }

  function setVolume(value) {
    volume = Math.max(0, Math.min(1, value))
    pushState()
    persistTimer.restart()
  }

  function toggleAccent() {
    accentDownbeat = !accentDownbeat
    pushState()
    persistTimer.restart()
  }

  function start() {
    if (running) return
    running = true
    currentBeat = 0
    currentPulse = 0
    idleTimer.stop()
    if (!engine.running) engine.running = true
    pushState()
  }

  function stop() {
    if (!running) return
    running = false
    beatPulse = 0
    pushState()
    // Keep the engine — and with it the audio stream — alive for a while
    // after a stop. Rebuilding the stream costs a setup the user hears as a
    // late first click, and starting and stopping in quick succession is the
    // normal way a metronome gets used.
    idleTimer.restart()
  }

  function togglePlay() { running ? stop() : start() }

  function tap() {
    var result = Model.tapTempo(tapTimes, Date.now())
    tapTimes = result.taps
    if (result.bpm > 0) setBpm(result.bpm)
    if (!running) start()
  }

  // Every control writes the whole state, so a change that lands while the
  // engine is still starting is never lost to a partial update.
  function pushState() {
    if (!engine.running) return
    engine.write(JSON.stringify({
      running: core.running,
      bpm: core.bpm,
      beats: core.beats,
      subdivision: core.subdivision,
      volume: core.volume,
      accent: core.accentDownbeat
    }) + "\n")
  }

  function handleEvent(line) {
    var event = {}
    try { event = JSON.parse(line) } catch (e) { return }
    if (event.e !== "beat") return
    core.currentBeat = event.beat
    core.currentPulse = event.pulse
    if (event.downbeat) pulseAnimation.restart()
  }

  // --------------------------------------------------------------- engine

  Process {
    id: engine
    command: ["python3", core.enginePath]
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { core.handleEvent(line) } }
    stderr: SplitParser { onRead: function(line) { console.warn("wh01s17.metronome:", line) } }
    onRunningChanged: if (running) Qt.callLater(core.pushState)
    onExited: {
      if (!core.running) return
      // The engine died mid-play (no audio server, killed by hand). Show
      // stopped rather than pretend to still be keeping time.
      core.running = false
      core.beatPulse = 0
    }
  }

  Timer {
    id: idleTimer
    interval: 20000
    onTriggered: if (!core.running) engine.running = false
  }

  Timer {
    id: persistTimer
    interval: 400
    onTriggered: core.persist()
  }

  SequentialAnimation {
    id: pulseAnimation
    PropertyAction { target: core; property: "beatPulse"; value: 1 }
    NumberAnimation {
      target: core; property: "beatPulse"
      to: 0; duration: 240; easing.type: Easing.OutCubic
    }
  }

  Component.onDestruction: engine.running = false
}
