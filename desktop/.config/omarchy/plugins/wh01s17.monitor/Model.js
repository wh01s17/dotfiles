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

// ---- Display arrangement (extend layout) ----
// Rects live in Hyprland's logical space: position as reported, size is the
// mode divided by scale (swapped for 90/270 degree transforms).
function parseGeometry(raw) {
  var monitors = []
  try {
    monitors = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    monitors = []
  }
  if (!Array.isArray(monitors)) monitors = []

  var rects = []
  for (var i = 0; i < monitors.length; i++) {
    var m = monitors[i]
    if (!m || !m.name) continue
    var scale = Number(m.scale) > 0 ? Number(m.scale) : 1
    var w = Math.round(Number(m.width) / scale)
    var h = Math.round(Number(m.height) / scale)
    if (Number(m.transform) % 2 === 1) {
      var t = w
      w = h
      h = t
    }
    if (!(w > 0) || !(h > 0)) continue
    rects.push({
      name: String(m.name),
      x: Math.round(Number(m.x) || 0),
      y: Math.round(Number(m.y) || 0),
      w: w,
      h: h,
      enabled: m.disabled !== true,
      mirrored: String(m.mirrorOf || "none") !== "none"
    })
  }
  return rects
}

function overlapLength(a1, aLen, b1, bLen) {
  return Math.min(a1 + aLen, b1 + bLen) - Math.max(a1, b1)
}

function rectsOverlap(a, b) {
  return overlapLength(a.x, a.w, b.x, b.w) > 0 && overlapLength(a.y, a.h, b.y, b.h) > 0
}

// Starting rects for the editor: the live layout when every output is enabled
// and standing on its own, otherwise all of them side by side in name order
// with the internal panel first (mirrored or disabled outputs have no
// meaningful position).
function initialArrangement(rects, internal) {
  var list = (rects || []).map(function(r) {
    return { name: r.name, x: r.x, y: r.y, w: r.w, h: r.h }
  })
  var live = (rects || []).every(function(r) { return r.enabled && !r.mirrored })
  if (live) {
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        if (rectsOverlap(list[i], list[j])) live = false
      }
    }
  }
  if (live) return list

  list.sort(function(a, b) {
    if (a.name === internal) return -1
    if (b.name === internal) return 1
    return a.name < b.name ? -1 : 1
  })
  var x = 0
  for (var k = 0; k < list.length; k++) {
    list[k].x = x
    list[k].y = 0
    x += list[k].w
  }
  return list
}

function clamp(value, low, high) {
  return Math.max(low, Math.min(high, value))
}

// Where rects[index] lands when dropped at (x, y): flush against the closest
// side of another output, sharing at least part of that edge, and overlapping
// nobody. Cross-axis edges within `align` snap into line, like Windows does.
function snapPosition(rects, index, x, y) {
  var r = rects[index]
  var best = null
  var bestDistance = Infinity

  function consider(cx, cy) {
    var candidate = { x: Math.round(cx), y: Math.round(cy), w: r.w, h: r.h }
    for (var k = 0; k < rects.length; k++) {
      if (k !== index && rectsOverlap(candidate, rects[k])) return
    }
    var distance = Math.hypot(candidate.x - x, candidate.y - y)
    if (distance < bestDistance) {
      best = { x: candidate.x, y: candidate.y }
      bestDistance = distance
    }
  }

  function alignCross(value, start, length, ownLength) {
    var align = Math.min(length, ownLength) * 0.1
    var v = clamp(value, start - ownLength + 1, start + length - 1)
    if (Math.abs(v - start) < align) return start
    if (Math.abs(v + ownLength - (start + length)) < align) return start + length - ownLength
    return v
  }

  for (var i = 0; i < rects.length; i++) {
    if (i === index) continue
    var o = rects[i]
    var cy = alignCross(y, o.y, o.h, r.h)
    var cx = alignCross(x, o.x, o.w, r.w)
    consider(o.x + o.w, cy)
    consider(o.x - r.w, cy)
    consider(cx, o.y + o.h)
    consider(cx, o.y - r.h)
  }
  return best || { x: r.x, y: r.y }
}

// Side of `anchor` that `r` sits flush against, or "".
function touchingSide(r, anchor) {
  var xOverlap = overlapLength(r.x, r.w, anchor.x, anchor.w) > 0
  var yOverlap = overlapLength(r.y, r.h, anchor.y, anchor.h) > 0
  if (yOverlap && r.x === anchor.x + anchor.w) return "right"
  if (yOverlap && r.x + r.w === anchor.x) return "left"
  if (xOverlap && r.y === anchor.y + anchor.h) return "below"
  if (xOverlap && r.y + r.h === anchor.y) return "above"
  return ""
}

// Turn rects into `OUTPUT=ANCHOR,SIDE,OFFSET` lines (plus `root=OUTPUT`) that
// hypr/monitor_layout.lua resolves against the live sizes on every reload, so
// a later scale or resolution change keeps the outputs touching. OFFSET is the
// cross-axis distance between the two outputs' top/left edges.
function arrangementLines(rects, rootName) {
  var list = rects || []
  if (list.length === 0) return []
  var root = list[0]
  for (var i = 0; i < list.length; i++) {
    if (list[i].name === rootName) root = list[i]
  }

  var placed = [root]
  var lines = ["root=" + root.name]
  var pending = list.filter(function(r) { return r !== root })

  while (pending.length > 0) {
    var found = -1
    var line = ""
    for (var p = 0; p < pending.length && found < 0; p++) {
      for (var q = 0; q < placed.length; q++) {
        var side = touchingSide(pending[p], placed[q])
        if (side === "") continue
        var offset = side === "right" || side === "left"
          ? pending[p].y - placed[q].y
          : pending[p].x - placed[q].x
        line = pending[p].name + "=" + placed[q].name + "," + side + "," + offset
        found = p
        break
      }
    }
    // Nothing touches the placed group: hang the closest output off the root
    // to its right; the resolver keeps it adjacent.
    if (found < 0) {
      found = 0
      line = pending[0].name + "=" + root.name + ",right,0"
    }
    placed.push(pending[found])
    lines.push(line)
    pending.splice(found, 1)
  }
  return lines
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
    parseDisplays: parseDisplays,
    parseGeometry: parseGeometry,
    initialArrangement: initialArrangement,
    snapPosition: snapPosition,
    arrangementLines: arrangementLines
  }
}
