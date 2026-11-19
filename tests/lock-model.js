// The lock screen's pixel wordmark and status tags (plugins/wh01s17.lock/LockModel.js).
const fs = require("fs")
const vm = require("vm")
const assert = require("assert")
const path = require("path")

const source = path.join(__dirname, "../desktop/.config/wh01s17/plugins/wh01s17.lock/LockModel.js")
const sandbox = { module: { exports: {} } }
vm.runInNewContext(fs.readFileSync(source, "utf8").replace(/^\.pragma library\s*/, ""), sandbox)
const m = sandbox.module.exports

// Same glyphs as the 07/08 wallpapers (themes/wh01s17/sources/pixel-art.py).
const art = fs.readFileSync(path.join(__dirname, "../desktop/.config/wh01s17/themes/wh01s17/sources/pixel-art.py"), "utf8")
for (const [ch, rows] of Object.entries(m.GLYPHS))
  assert(art.includes(`"${ch}": ${JSON.stringify(rows).replace(/,/g, ", ")}`), `glyph ${ch} differs from pixel-art.py`)

const mark = m.wordmark("wh01s17")
assert.strictEqual(mark.width, 41)
assert.strictEqual(mark.height, 7)
for (const c of mark.cells) assert(c.x >= 0 && c.x < mark.width && c.y >= 0 && c.y < 7)
assert(mark.cells.some(c => c.digit) && mark.cells.some(c => !c.digit))
assert.strictEqual(m.wordmark("w?").width, 11) // unknown characters leave a gap

assert.strictEqual(m.statusTag(false, false, 0, 0), "[ ENTER ]")
assert.strictEqual(m.statusTag(true, false, 0, 2), "[ AUTH ··  ]")
assert.strictEqual(m.statusTag(true, false, 0, 0).length, m.statusTag(true, false, 0, 3).length)
assert.strictEqual(m.statusTag(false, true, 1, 0), "[ DENIED ]")
assert.strictEqual(m.statusTag(false, true, 3, 0), "[ DENIED x3 ]")
assert.strictEqual(m.SHAKE[m.SHAKE.length - 1], 0) // the shake ends where it started
