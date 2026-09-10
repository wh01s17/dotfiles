function clampBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 1
  return Math.max(1, Math.min(100, Math.round(n)))
}

function normalizeScale(scale) {
  var n = parseFloat(String(scale || ""))
  if (!isFinite(n)) return ""
  return String(Math.round(n * 100) / 100)
}

function gcd(a, b) {
  while (b) {
    var remainder = a % b
    a = b
    b = remainder
  }
  return a
}

function cleanScale(scale, width, height) {
  var requested = Number(scale)
  var modeWidth = Number(width)
  var modeHeight = Number(height)
  if (!isFinite(requested) || !isFinite(modeWidth) || !isFinite(modeHeight)
      || requested <= 0 || modeWidth <= 0 || modeHeight <= 0) return ""

  var divisor = gcd(Math.round(modeWidth * 120), Math.round(modeHeight * 120))
  var scaleUnits = Math.round(requested * 120)
  if (scaleUnits > divisor) scaleUnits = divisor
  while (divisor % scaleUnits !== 0) scaleUnits++
  return normalizeScale(scaleUnits / 120)
}

function matchingScaleIndex(scales, currentScale, width, height) {
  var current = Number(currentScale)
  if (!Array.isArray(scales) || !isFinite(current)) return -1

  var bestIndex = -1
  var bestDistance = Infinity
  var normalizedCurrent = normalizeScale(current)
  for (var i = 0; i < scales.length; i++) {
    if (cleanScale(scales[i], width, height) !== normalizedCurrent) continue

    var distance = Math.abs(Number(scales[i]) - current)
    if (distance < bestDistance) {
      bestIndex = i
      bestDistance = distance
    }
  }
  return bestIndex
}

function availableScales(scales, width, height) {
  if (!Array.isArray(scales) || Number(width) <= 0 || Number(height) <= 0) return scales || []

  var byEffectiveScale = {}
  for (var i = 0; i < scales.length; i++) {
    var requested = Number(scales[i])
    var effective = Number(cleanScale(requested, width, height))

    if (!isFinite(requested) || !isFinite(effective)) continue

    var key = normalizeScale(effective)
    var existing = byEffectiveScale[key]
    if (!existing || Math.abs(requested - effective) < existing.distance) {
      byEffectiveScale[key] = {
        value: String(scales[i]),
        index: i,
        distance: Math.abs(requested - effective)
      }
    }
  }

  return Object.keys(byEffectiveScale)
    .map(function(key) { return byEffectiveScale[key] })
    .sort(function(a, b) { return a.index - b.index })
    .map(function(candidate) { return candidate.value })
}

// ---- Display modes (resolution + refresh) ----
// Hyprland reports availableModes as "1920x1080@59.94Hz" strings. Parse them
// into structured options so the panel can render a combobox and hand the
// exact mode string back to `hyprctl`.
function parseMode(text) {
  var match = String(text || "").trim().match(/^(\d+)x(\d+)@([0-9.]+)/i)
  if (!match) return null

  var width = parseInt(match[1], 10)
  var height = parseInt(match[2], 10)
  var refresh = parseFloat(match[3])
  if (!isFinite(width) || !isFinite(height) || !isFinite(refresh)) return null
  if (width <= 0 || height <= 0 || refresh <= 0) return null

  return {
    value: width + "x" + height + "@" + refresh,
    label: width + "\u00d7" + height + " \u00b7 " + Math.round(refresh) + " Hz",
    width: width,
    height: height,
    refresh: refresh
  }
}

// One entry per visually distinct mode: several driver modes can round to the
// same "1920x1080 · 60 Hz" label, and offering them twice helps nobody.
function modeOptions(availableModes, width, height, refresh) {
  var raw = Array.isArray(availableModes) ? availableModes.slice() : []
  var active = parseMode(width + "x" + height + "@" + refresh)
  if (active) raw.push(active.value)

  var seen = {}
  var options = []
  for (var i = 0; i < raw.length; i++) {
    var mode = parseMode(raw[i])
    if (!mode) continue

    var key = mode.width + "x" + mode.height + "@" + Math.round(mode.refresh)
    if (seen[key]) continue
    seen[key] = true
    options.push(mode)
  }

  return options.sort(function(a, b) {
    return (b.width * b.height - a.width * a.height) || (b.refresh - a.refresh)
  })
}

// Match the live mode against the offered options. Refresh rates drift between
// what the driver advertises and what Hyprland reports, so pick the closest
// rate among options of the same resolution.
function currentModeValue(options, width, height, refresh) {
  var w = Number(width)
  var h = Number(height)
  var r = Number(refresh)
  if (!Array.isArray(options) || !isFinite(w) || !isFinite(h)) return ""

  var best = ""
  var bestDistance = Infinity
  for (var i = 0; i < options.length; i++) {
    var option = options[i]
    if (option.width !== w || option.height !== h) continue

    var distance = isFinite(r) ? Math.abs(option.refresh - r) : 0
    if (distance < bestDistance) {
      best = option.value
      bestDistance = distance
    }
  }
  return best
}

// name -> { options, current } for every connected output.
function parseMonitorModes(raw) {
  var monitors = []
  try {
    monitors = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    monitors = []
  }
  if (!Array.isArray(monitors)) monitors = []

  var byName = {}
  for (var i = 0; i < monitors.length; i++) {
    var monitor = monitors[i]
    if (!monitor || !monitor.name) continue

    var options = modeOptions(monitor.availableModes, monitor.width, monitor.height, monitor.refreshRate)
    byName[String(monitor.name)] = {
      options: options,
      current: currentModeValue(options, monitor.width, monitor.height, monitor.refreshRate)
    }
  }
  return byName
}

function brightnessName(percent) {
  var p = Math.round(percent)
  if (p >= 95) return "Sun blast"
  if (p >= 80) return "Solar flare"
  if (p >= 65) return "Golden hour"
  if (p >= 45) return "Even day"
  if (p >= 30) return "Soft glow"
  if (p >= 20) return "Lamp light"
  if (p >= 10) return "Candlelit"
  return "Night owl"
}

function parseDisplays(raw) {
  var displays = []
  try {
    displays = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    displays = []
  }
  if (!Array.isArray(displays)) displays = []

  var count = 0
  for (var i = 0; i < displays.length; i++) {
    if (displays[i] && displays[i].enabled) count++
  }

  return {
    displays: displays,
    enabledDisplayCount: count
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    clampBrightness: clampBrightness,
    normalizeScale: normalizeScale,
    cleanScale: cleanScale,
    matchingScaleIndex: matchingScaleIndex,
    availableScales: availableScales,
    parseMode: parseMode,
    modeOptions: modeOptions,
    currentModeValue: currentModeValue,
    parseMonitorModes: parseMonitorModes,
    brightnessName: brightnessName,
    parseDisplays: parseDisplays
  }
}
