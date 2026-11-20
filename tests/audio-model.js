// Card-profile helpers of the audio panel (plugins/wh01s17.audio/Model.js).
const fs = require("fs")
const vm = require("vm")
const assert = require("assert")
const path = require("path")

const source = path.join(__dirname, "../desktop/.config/wh01s17/plugins/wh01s17.audio/Model.js")
const sandbox = { module: { exports: {} } }
vm.runInNewContext(fs.readFileSync(source, "utf8"), sandbox)
const m = sandbox.module.exports
// Arrays built inside the vm sandbox carry its prototypes; compare as JSON.
const same = (a, b) => assert.strictEqual(JSON.stringify(a), JSON.stringify(b))

const EVO = "alsa_card.usb-Audient_EVO8-00"
const prof = (name, description, sinks, sources) => ({ name, description, sinks, sources })

// As wh01s17-audio-card-profiles prints them: available, not "off", by priority.
const raw = JSON.stringify([
  {
    name: EVO, description: "EVO8", active: "pro-audio",
    profiles: [
      prof("output:analog-surround-21+input:analog-surround-21", "Analog Surround 2.1 Output + Analog Surround 2.1 Input", 1, 1),
      prof("output:analog-surround-21+input:analog-surround-41", "Analog Surround 2.1 Output + Analog Surround 4.1 Input", 1, 1),
      prof("output:analog-surround-21", "Analog Surround 2.1 Output", 1, 0),
      prof("input:analog-surround-21", "Analog Surround 2.1 Input", 0, 1),
      prof("pro-audio", "Pro Audio", 1, 1)
    ]
  },
  {
    name: "alsa_card.pci-0000_01_00.1", description: "GP106 High Definition Audio Controller", active: "output:hdmi-stereo",
    profiles: [
      prof("output:hdmi-stereo", "Digital Stereo (HDMI) Output", 1, 0),
      prof("output:hdmi-stereo-extra1", "Digital Stereo (HDMI 2) Output", 1, 0),
      prof("pro-audio", "Pro Audio", 1, 0)
    ]
  },
  {
    name: "alsa_card.pci-0000_00_1f.3", description: "Built-in Audio", active: "output:analog-stereo+input:analog-stereo",
    profiles: [
      prof("output:analog-stereo+input:analog-stereo", "Analog Stereo Duplex", 1, 1),
      prof("output:analog-stereo", "Analog Stereo Output", 1, 0),
      prof("pro-audio", "Pro Audio", 1, 1)
    ]
  },
  { name: "lonely", description: "One profile", active: "a", profiles: [prof("a", "A", 1, 0)] },
  { description: "no name", profiles: [] }
])

// Malformed input hides the section rather than throwing.
assert.strictEqual(m.parseCardProfiles("").length, 0)
assert.strictEqual(m.parseCardProfiles("not json").length, 0)
assert.strictEqual(m.parseCardProfiles("{}").length, 0)

const cards = m.parseCardProfiles(raw)
same(cards.map(c => c.description), ["EVO8", "HDMI", "Integrado"]) // single-profile and nameless cards dropped

// The 25-ish ALSA layouts collapse to the profiles a person would pick.
const evo = cards[0]
same(evo.profiles.map(p => [p.label, p.name]), [
  ["Pro Audio", "pro-audio"],
  ["Estándar", "output:analog-surround-21+input:analog-surround-21"],
  ["Solo salida", "output:analog-surround-21"]
])
same(cards[1].profiles.map(p => p.label), ["Pro Audio", "Estándar"]) // no duplex: best output is Estándar
same(cards[2].profiles.map(p => p.label), ["Pro Audio", "Estándar", "Solo salida"])

// An active profile outside the curated set is still listed, by its own name.
const odd = m.curateProfiles(JSON.parse(raw)[0].profiles, "output:analog-surround-21+input:analog-surround-41")
same(odd[odd.length - 1], { name: "output:analog-surround-21+input:analog-surround-41", label: "Analog Surround 2.1 Output + Analog Surround 4.1 Input" })

// Collapsed: one row per card, carrying the active profile as its detail.
let rows = m.profileRows(cards, "")
same(rows.map(r => [r.kind, r.label, r.detail, r.warning]), [
  ["card", "EVO8", "Pro Audio", false],
  ["card", "HDMI", "Estándar", false],
  ["card", "Integrado", "Estándar", false]
])

// Expanded: the card's profiles follow it, with the active one marked.
rows = m.profileRows(cards, EVO)
same(rows.slice(1, 4).map(r => [r.kind, r.label, r.active]), [
  ["profile", "Pro Audio", true],
  ["profile", "Estándar", false],
  ["profile", "Solo salida", false]
])

// Leaving Pro Audio on the EVO 8 breaks the Mezcla routing: the card row warns.
const switched = m.withActiveProfile(cards, EVO, "output:analog-surround-21+input:analog-surround-21")
assert.strictEqual(cards[0].active, "pro-audio") // input untouched
const warned = m.profileRows(switched, "")[0]
assert.strictEqual(warned.warning, true)
assert.strictEqual(warned.detail, "Requiere Pro Audio")
assert.strictEqual(m.profileWarning(cards[1]), "") // cards without a requirement never warn

console.log("audio-model: ok")
