.pragma library

// The pixel `wh01s17` wordmark of the theme's 07/08 wallpapers
// (themes/wh01s17/sources/pixel-art.py): 5x7 glyphs, one column apart,
// letters in the foreground and digits in the signal green.
var GLYPHS = {
  "w": [".....", ".....", "#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
  "h": ["#....", "#....", "#.##.", "##..#", "#...#", "#...#", "#...#"],
  "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
  "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
  "s": [".....", ".....", ".####", "#....", ".###.", "....#", "####."],
  "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."]
}

// Cells of `word` as [{x, y, digit}], plus its size in cells. Characters
// with no glyph leave a gap.
function wordmark(word) {
  var cells = []
  var text = String(word || "")
  for (var i = 0; i < text.length; i++) {
    var glyph = GLYPHS[text[i]]
    if (!glyph) continue
    var digit = /[0-9]/.test(text[i])
    for (var row = 0; row < glyph.length; row++)
      for (var col = 0; col < glyph[row].length; col++)
        if (glyph[row][col] === "#") cells.push({ x: i * 6 + col, y: row, digit: digit })
  }
  return { cells: cells, width: Math.max(0, text.length * 6 - 1), height: 7 }
}

// A failed attempt shakes the prompt in whole steps, 8-bit style.
var SHAKE = [-8, 8, -6, 6, -4, 4, -2, 0]

// The status tag at the prompt's edge.
function statusTag(authenticating, failure, attempts, dots) {
  if (authenticating) {
    var n = Math.max(0, Math.min(3, dots))
    return "[ AUTH " + "···".slice(0, n) + "   ".slice(n) + " ]"
  }
  if (failure) return attempts > 1 ? "[ DENIED x" + attempts + " ]" : "[ DENIED ]"
  return "[ ENTER ]"
}

if (typeof module !== "undefined") {
  module.exports = { GLYPHS: GLYPHS, wordmark: wordmark, SHAKE: SHAKE, statusTag: statusTag }
}
