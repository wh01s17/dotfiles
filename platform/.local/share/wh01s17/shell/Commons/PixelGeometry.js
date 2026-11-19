.pragma library

// Pixel-mode geometry, pure functions shared by BorderSurface and PixelBar.

// The border of a w x h box whose corners are a staircase of `steps` cells of
// `unit` px, as a list of {x, y, w, h} runs of `bw` px. Band k of the shape
// (k = 0 at the top) starts `(steps - k) * unit` in from each side; each band
// adds one vertical riser and, below the first, one tread.
function pixelOutline(w, h, unit, steps, bw) {
  w = Math.round(Number(w) || 0)
  h = Math.round(Number(h) || 0)
  unit = Math.max(1, Math.round(Number(unit) || 1))
  steps = Math.max(0, Math.round(Number(steps) || 0))
  bw = Math.max(1, Math.round(Number(bw) || 1))
  if (w <= 0 || h <= 0) return []

  var corner = steps * unit
  var runs = []
  function add(x, y, rw, rh) {
    if (rw > 0 && rh > 0) runs.push({ x: x, y: y, w: rw, h: rh })
  }
  // A run in the top-left corner, mirrored into the other three.
  function mirrored(x, y, rw, rh) {
    add(x, y, rw, rh)
    add(w - x - rw, y, rw, rh)
    add(x, h - y - rh, rw, rh)
    add(w - x - rw, h - y - rh, rw, rh)
  }

  add(corner, 0, w - 2 * corner, bw)
  add(corner, h - bw, w - 2 * corner, bw)
  add(0, corner, bw, h - 2 * corner)
  add(w - bw, corner, bw, h - 2 * corner)

  for (var k = 0; k < steps; k++) {
    var x = (steps - k) * unit
    mirrored(x, k * unit, bw, unit)              // riser of band k
    mirrored(x - unit, (k + 1) * unit, unit, bw) // tread of band k + 1
  }
  return runs
}

// Blocks for a bar `length` px long: cells of `cell` px with `gap` px between,
// stretched so the last block ends flush with the track.
function blockLayout(length, cell, gap) {
  length = Math.max(0, Number(length) || 0)
  cell = Math.max(1, Number(cell) || 1)
  gap = Math.max(0, Number(gap) || 0)
  if (length <= 0) return []
  var count = Math.max(1, Math.floor((length + gap) / (cell + gap)))
  var size = (length - gap * (count - 1)) / count
  var blocks = []
  for (var i = 0; i < count; i++) {
    var start = Math.round(i * (size + gap))
    var end = Math.round(i * (size + gap) + size)
    blocks.push({ x: start, w: Math.max(1, end - start) })
  }
  return blocks
}

// How many of `count` blocks a 0..1 value lights. Any value above zero lights
// at least one, so a small reading never looks empty.
function litBlocks(value, count) {
  var v = Math.max(0, Math.min(1, Number(value) || 0))
  if (v <= 0 || count <= 0) return 0
  return Math.max(1, Math.min(count, Math.round(v * count)))
}

if (typeof module !== "undefined") {
  module.exports = { pixelOutline: pixelOutline, blockLayout: blockLayout, litBlocks: litBlocks }
}
