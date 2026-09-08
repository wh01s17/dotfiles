.pragma library

// Tempo vocabulary, subdivision table, and the pure helpers the panel leans
// on. Kept out of the QML so the widget file stays layout.

var MIN_BPM = 40
var MAX_BPM = 240

var TEMPO_MARKS = [
  { upTo: 24,  name: "Larghissimo" },
  { upTo: 40,  name: "Grave" },
  { upTo: 60,  name: "Largo" },
  { upTo: 66,  name: "Larghetto" },
  { upTo: 76,  name: "Adagio" },
  { upTo: 108, name: "Andante" },
  { upTo: 120, name: "Moderato" },
  { upTo: 156, name: "Allegro" },
  { upTo: 176, name: "Vivace" },
  { upTo: 200, name: "Presto" },
  { upTo: 999, name: "Prestissimo" }
]

// value is what the engine understands; pulses drives the beat readout.
var SUBDIVISIONS = [
  { value: "1/4",   label: "1/4",   pattern: "·",      pulses: 1 },
  { value: "1/8",   label: "1/8",   pattern: "··",     pulses: 2 },
  { value: "1/8t",  label: "1/8T",  pattern: "···",    pulses: 3 },
  { value: "swing", label: "SWING", pattern: "· ·",    pulses: 2 },
  { value: "1/16",  label: "1/16",  pattern: "····",   pulses: 4 },
  { value: "1/16t", label: "1/16T", pattern: "······", pulses: 6 }
]

function tempoName(bpm) {
  for (var i = 0; i < TEMPO_MARKS.length; i++)
    if (bpm <= TEMPO_MARKS[i].upTo) return TEMPO_MARKS[i].name
  return "Prestissimo"
}

function clampBpm(bpm) {
  var n = Math.round(Number(bpm))
  if (!isFinite(n)) return 100
  return Math.max(MIN_BPM, Math.min(MAX_BPM, n))
}

function subdivisionLabel(value) {
  for (var i = 0; i < SUBDIVISIONS.length; i++)
    if (SUBDIVISIONS[i].value === value) return SUBDIVISIONS[i].label
  return "1/4"
}

function pulsesPerBeat(value) {
  for (var i = 0; i < SUBDIVISIONS.length; i++)
    if (SUBDIVISIONS[i].value === value) return SUBDIVISIONS[i].pulses
  return 1
}

// Tap tempo. Taps more than two seconds apart start a fresh measurement —
// past that gap the user is setting a new tempo, not continuing one. The
// average of the retained intervals is steadier than the last one alone.
function tapTempo(taps, now) {
  var kept = []
  for (var i = 0; i < taps.length; i++)
    if (now - taps[i] < 2000) kept.push(taps[i])
  kept.push(now)
  if (kept.length > 6) kept = kept.slice(kept.length - 6)
  if (kept.length < 2) return { taps: kept, bpm: 0 }
  var span = kept[kept.length - 1] - kept[0]
  if (span <= 0) return { taps: kept, bpm: 0 }
  var average = span / (kept.length - 1)
  return { taps: kept, bpm: clampBpm(60000 / average) }
}

function isSubdivision(value) {
  for (var i = 0; i < SUBDIVISIONS.length; i++)
    if (SUBDIVISIONS[i].value === value) return true
  return false
}
