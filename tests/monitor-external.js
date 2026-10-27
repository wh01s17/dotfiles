const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const Model = require('../desktop/.config/omarchy/plugins/wh01s17.monitor/Model.js')

const displays = [
  { name: 'eDP-1', enabled: true },
  { name: 'HDMI-A-1', enabled: false },
  { name: 'DP-1', enabled: true },
  { name: 'LVDS-1', enabled: true },
  { name: 'unsafe"output', enabled: true }
]
assert.deepEqual(Model.externalDisplays(displays, 'eDP-1').map(d => d.name), ['HDMI-A-1', 'DP-1'])
assert.deepEqual(Model.externalSelection(displays, 'eDP-1', ['HDMI-A-1', 'DP-9']), ['HDMI-A-1'])
assert.deepEqual(Model.externalSelection(displays, 'eDP-1', []), ['DP-1'])
assert.deepEqual(Model.externalSelection(displays.map(d => ({ ...d, enabled: false })), 'eDP-1', []), ['HDMI-A-1'])
assert.deepEqual(Model.externalSelection([], 'eDP-1', ['DP-1']), [])

// Exercise the panel's actual selection handler: one output must remain and
// rapid input during Apply must not alter the in-flight selection.
const panel = fs.readFileSync('desktop/.config/omarchy/plugins/wh01s17.monitor/Panel.qml', 'utf8')
const source = panel.match(/^  function toggleExternal\(name\) \{[\s\S]*?^  \}/m)[0]
const root = { selectedExternals: ['DP-1'] }
Object.defineProperty(root, 'connectedSelection', {
  get() { return root.selectedExternals.filter(name => ['DP-1', 'HDMI-A-1'].includes(name)) }
})
const context = vm.createContext({ root, actionProc: { running: false } })
vm.runInContext(source, context)
context.toggleExternal('DP-1')
assert.deepEqual(Array.from(root.selectedExternals), ['DP-1'])
context.toggleExternal('HDMI-A-1')
assert.deepEqual(Array.from(root.selectedExternals), ['DP-1', 'HDMI-A-1'])
context.toggleExternal('DP-1')
assert.deepEqual(Array.from(root.selectedExternals), ['HDMI-A-1'])
context.actionProc.running = true
context.toggleExternal('DP-1')
assert.deepEqual(Array.from(root.selectedExternals), ['HDMI-A-1'])

// Run the actual persistence command against fake compositor commands, so
// these checks never switch the developer's physical displays.
vm.runInContext(panel.match(/^  function runLayout\([^\n]+\) \{[\s\S]*?^  \}/m)[0], context)
context.layoutOptions = ['extend', 'mirror', 'internal', 'external'].map(value => ({ value }))
root.internalMonitor = 'eDP-1'
root.savedExternals = ['HDMI-A-1']
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'monitor-external-'))
try {
  for (const name of ['hyprctl', 'omarchy-hyprland-monitor-internal', 'omarchy-hyprland-monitor-internal-mirror']) {
    fs.writeFileSync(path.join(temporary, name), '#!/bin/sh\nif [ "$1" = monitors ]; then echo "[]"; fi\nexit 0\n', { mode: 0o755 })
  }
  for (const kind of ['external', 'extend']) {
    context.actionProc.running = false
    context.runLayout(kind, 'keep', '')
    const [command, ...args] = context.actionProc.command
    const result = spawnSync(command, args, {
      env: { ...process.env, XDG_STATE_HOME: temporary, PATH: temporary + path.delimiter + process.env.PATH },
      encoding: 'utf8'
    })
    assert.equal(result.status, 0, result.stderr)
    assert.equal(fs.readFileSync(path.join(temporary, 'omarchy/monitor-layout.conf'), 'utf8'),
      `layout=${kind}\ninternal=eDP-1\nexternal=HDMI-A-1\n`)
  }
  context.actionProc.running = false
  root.selectedExternals = []
  context.runLayout('external', 'keep', '')
  assert.equal(context.actionProc.running, false)
} finally {
  fs.rmSync(temporary, { recursive: true, force: true })
}
console.log('External display selection passed')
