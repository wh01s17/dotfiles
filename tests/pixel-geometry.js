// Pixel-mode geometry: staircase borders and bar blocks (Commons/PixelGeometry.js).
const fs = require("fs")
const vm = require("vm")
const assert = require("assert")
const path = require("path")

const source = path.join(__dirname, "../platform/.local/share/wh01s17/shell/Commons/PixelGeometry.js")
const sandbox = { module: { exports: {} } }
vm.runInNewContext(fs.readFileSync(source, "utf8").replace(/^\.pragma library\s*/, ""), sandbox)
const g = sandbox.module.exports

function paint(w, h, runs) {
  const grid = [...Array(h)].map(() => Array(w).fill(0))
  for (const r of runs)
    for (let y = r.y; y < r.y + r.h; y++)
      for (let x = r.x; x < r.x + r.w; x++) {
        assert(x >= 0 && x < w && y >= 0 && y < h, "run outside the box")
        grid[y][x] = 1
      }
  return grid
}

// A 20x16 box, two steps of 2 px, 1 px border.
const grid = paint(20, 16, g.pixelOutline(20, 16, 2, 2, 1))
assert.deepStrictEqual(grid[0].join(""), "00001111111111110000") // top edge starts after the corner
assert.strictEqual(grid[0][4], 1)  // riser of the first step
assert.strictEqual(grid[2][2], 1)  // tread of the second step
assert.strictEqual(grid[4][0], 1)  // the left edge begins below the staircase
assert.strictEqual(grid[0][0], 0)  // the corner itself is cut away
// Symmetric left/right and top/bottom.
for (let y = 0; y < 16; y++) assert.deepStrictEqual(grid[y], grid[y].slice().reverse())
assert.deepStrictEqual(grid[0], grid[15])
// No steps: a plain square border.
const square = paint(6, 4, g.pixelOutline(6, 4, 2, 0, 1))
assert.deepStrictEqual(square.map(r => r.join("")), ["111111", "100001", "100001", "111111"])

// Blocks fill the track exactly and never overlap.
const blocks = g.blockLayout(100, 6, 2)
assert.strictEqual(blocks[0].x, 0)
assert.strictEqual(blocks[blocks.length - 1].x + blocks[blocks.length - 1].w, 100)
for (let i = 1; i < blocks.length; i++) assert(blocks[i].x >= blocks[i - 1].x + blocks[i - 1].w)
assert.strictEqual(g.blockLayout(0, 6, 2).length, 0)

// Any reading above zero lights a block; full lights them all.
assert.strictEqual(g.litBlocks(0, 10), 0)
assert.strictEqual(g.litBlocks(0.001, 10), 1)
assert.strictEqual(g.litBlocks(0.5, 10), 5)
assert.strictEqual(g.litBlocks(2, 10), 10)
