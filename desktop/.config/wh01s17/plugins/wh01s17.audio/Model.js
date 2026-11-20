function isPlaybackStream(node) {
  if (!node || !node.isStream) return false
  if (node.isSink === true) return true

  var mediaClass = String(node.type || "")
  return mediaClass.indexOf("Stream/Output/Audio") !== -1
    || mediaClass.indexOf("AudioOutStream") !== -1
    || mediaClass.indexOf("Output") !== -1
}

function isAudioSource(node) {
  if (!node) return false
  if (node.audio) return true

  var mediaClass = String(node.type || "")
  return mediaClass.indexOf("Audio/Source") !== -1
    || mediaClass.indexOf("AudioSource") !== -1
    || mediaClass.indexOf("Source") !== -1
}

// Project a node list to the primitive rows a Repeater model can hold. A row
// holding the PwNode itself is a QObject that Qt dereferences without a null
// check while it builds the delegate, and PipeWire deletes nodes outright, so a
// graph teardown segfaults the shell. Primitives cannot dangle, which is what
// closes that race -- not the check below, since the node usually dies after the
// snapshot is taken. That is also why filtering the list here never worked.
//
// The name rides along because PipeWire reuses object ids: without it a row
// could resolve to whatever inherited its id. PwNode.name is CONSTANT, so it
// identifies the node it was taken from for as long as that node lives.
function nodeRow(node) {
  if (!node) return null
  var id = node.id
  if (id === undefined || id === null) return null
  return { id: id, name: String(node.name || "") }
}

function rowSnapshot(list) {
  var values = list && list.length ? list : []
  var rows = []
  for (var i = 0; i < values.length; i++) {
    var row = nodeRow(values[i])
    if (row) rows.push(row)
  }
  return rows
}

function outputVolumeName(volume, muted) {
  if (muted) return "Muted"
  var p = Math.round(volume * 100)
  if (p === 0) return "Silenced"
  if (p >= 100) return "Concert hall"
  if (p >= 85) return "Party mode"
  if (p >= 70) return "Cranked up"
  if (p >= 50) return "Steady groove"
  if (p >= 30) return "Easy listening"
  if (p >= 15) return "Murmur"
  return "Whisper"
}

function parseSinkAvailability(raw) {
  var next = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line) continue
    var parts = line.split("\t")
    if (parts.length >= 2) next[parts[0]] = parts[1] !== "0"
  }
  return next
}

function friendlyDeviceLabel(text) {
  var label = String(text || "").trim()
  label = label.replace(/^sof-soundwire\s+/i, "")
  label = label.replace(/^built-?in audio\s+/i, "")
  label = label.replace(/\s+Output$/i, "")
  label = label.replace(/\s+Input$/i, "")
  label = label.replace(/\bMicrophones\b/g, "Microphone")
  return label
}

function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function nodeLabel(node) {
  if (!node) return "Unknown"
  var p = nodeProps(node)
  var nickname = friendlyDeviceLabel(node.nickname || node.nick || p["node.nick"] || p["device.profile.description"] || "")
  if (nickname) return nickname
  return friendlyDeviceLabel(node.description || p["node.description"] || node.name || "Unknown")
}

function isHeadphones(node) {
  if (!node) return false
  var p = nodeProps(node)
  var blob = String([
    node.name, node.description, node.nickname,
    p["device.icon-name"] || "",
    p["device.product.name"] || "",
    p["node.description"] || "",
    p["node.nick"] || ""
  ].join(" ")).toLowerCase()
  return blob.indexOf("headphone") !== -1
    || blob.indexOf("headset") !== -1
    || blob.indexOf("earbud") !== -1
    || blob.indexOf("earphone") !== -1
    || blob.indexOf("airpod") !== -1
}

function sinkGlyph(node) {
  if (!node) return "󰓃"
  if (isHeadphones(node)) return "󰋋"
  var p = nodeProps(node)
  var blob = String([
    node.name, node.description, node.nickname,
    p["device.icon-name"] || "",
    p["device.product.name"] || ""
  ].join(" ")).toLowerCase()
  if (blob.indexOf("bluetooth") !== -1) return "󰂯"
  if (blob.indexOf("hdmi") !== -1 || blob.indexOf("display") !== -1) return "󰍹"
  return "󰓃"
}

function sourceGlyph(node) {
  if (!node) return "󰍬"
  var p = nodeProps(node)
  var blob = String([
    node.name, node.description, node.nickname,
    p["device.icon-name"] || ""
  ].join(" ")).toLowerCase()
  if (blob.indexOf("headset") !== -1) return "󰋋"
  if (blob.indexOf("bluetooth") !== -1) return "󰂯"
  if (blob.indexOf("webcam") !== -1 || blob.indexOf("camera") !== -1) return "󰄀"
  return "󰍬"
}

function friendlyStreamLabel(label) {
  label = String(label || "").trim()
  if (!label) return ""

  var known = {
    "spotify": "Spotify"
  }
  var normalized = label.toLowerCase()
  return known[normalized] || label
}

function streamLabelKey(label) {
  return String(label || "").trim().toLowerCase()
}

function streamLabelIsGeneric(label) {
  return streamLabelKey(label) === "audio-src"
}

function rawStreamLabel(node) {
  if (!node) return ""
  var p = nodeProps(node)
  return p["application.name"]
    || node.description
    || p["media.name"]
    || p["node.name"]
    || node.name
}

function mprisPlayerLabel(player) {
  if (!player) return ""
  return friendlyStreamLabel(player.identity || player.desktopEntry || "")
}

function mprisPlayerIsProxy(player) {
  var dbusName = String(player && player.dbusName || "").toLowerCase()
  var desktopEntry = String(player && player.desktopEntry || "").toLowerCase()
  return dbusName.indexOf("playerctld") !== -1 || desktopEntry === "playerctld"
}

function streamRepresentsMprisPlayer(streamLabel, playerLabel) {
  var streamKey = streamLabelKey(friendlyStreamLabel(streamLabel))
  var playerKey = streamLabelKey(playerLabel)
  if (!streamKey || !playerKey) return false
  return streamKey === playerKey
    || streamKey.indexOf(playerKey) !== -1
    || playerKey.indexOf(streamKey) !== -1
}

function mprisLabelsFor(players, predicate) {
  var values = Array.isArray(players) ? players : []
  var playingCandidates = []
  var candidates = []
  var playingProxyCandidates = []
  var proxyCandidates = []

  for (var i = 0; i < values.length; i++) {
    var player = values[i]
    if (!player) continue
    if (!player.isPlaying && !player.canPlay) continue

    var playerLabel = mprisPlayerLabel(player)
    if (!playerLabel || !predicate(playerLabel)) continue

    if (mprisPlayerIsProxy(player)) {
      if (player.isPlaying) playingProxyCandidates.push(playerLabel)
      proxyCandidates.push(playerLabel)
    } else {
      if (player.isPlaying) playingCandidates.push(playerLabel)
      candidates.push(playerLabel)
    }
  }

  if (playingCandidates.length === 1) return playingCandidates[0]
  if (playingCandidates.length === 0 && playingProxyCandidates.length === 1) return playingProxyCandidates[0]
  if (candidates.length === 1) return candidates[0]
  if (candidates.length === 0 && proxyCandidates.length === 1) return proxyCandidates[0]
  return ""
}

function matchingMprisStreamLabel(label, players) {
  if (streamLabelIsGeneric(label)) return ""
  return mprisLabelsFor(players, function(playerLabel) {
    return streamRepresentsMprisPlayer(label, playerLabel)
  })
}

function unmatchedMprisStreamLabel(label, players, streams) {
  if (!streamLabelIsGeneric(label)) return ""

  return mprisLabelsFor(players, function(playerLabel) {
    var values = Array.isArray(streams) ? streams : []
    for (var i = 0; i < values.length; i++) {
      var stream = values[i]
      var streamLabel = rawStreamLabel(stream)
      if (!streamLabelIsGeneric(streamLabel) && streamRepresentsMprisPlayer(streamLabel, playerLabel))
        return false
    }
    return true
  })
}

function streamLabel(node, players, streams) {
  if (!node) return "Stream"
  var label = rawStreamLabel(node)
  return friendlyStreamLabel(matchingMprisStreamLabel(label, players)
    || unmatchedMprisStreamLabel(label, players, streams)
    || label) || "Stream"
}

function streamRepresentsPlayer(node, player, players, streams) {
  if (!node || !player) return false
  var playerLabel = mprisPlayerLabel(player)
  if (!playerLabel) return false

  var label = rawStreamLabel(node)
  if (!streamLabelIsGeneric(label)) return streamRepresentsMprisPlayer(label, playerLabel)
  return streamRepresentsMprisPlayer(streamLabel(node, players, streams), playerLabel)
}

// Profiles a card must be on for the Mezcla virtual microphone to work
// (~/.config/pipewire/pipewire.conf.d/20-mezcla.conf reads the EVO 8's inputs
// one by one, which only the Pro Audio profile exposes).
var REQUIRED_PROFILES = {
  "alsa_card.usb-Audient_EVO8-00": "pro-audio"
}

function profileName(name) {
  return name === "pro-audio" ? "Pro Audio" : name
}

function cardLabel(name, description, profiles) {
  var desc = String(description || name || "")
  if (/built-?in/i.test(desc)) return "Integrado"
  var allHdmi = profiles.length > 0
  for (var i = 0; i < profiles.length; i++)
    if (profiles[i].name !== "pro-audio" && !/hdmi/i.test(profiles[i].name)) allHdmi = false
  if (allHdmi) return "HDMI"
  return friendlyDeviceLabel(desc)
}

// ALSA offers every channel layout it can probe (the EVO 8 lists 25), almost
// all of them useless. Keep what a person would actually pick, already sorted
// by priority by the helper:
//   Pro Audio    -- every input and output as its own channel
//   Estándar     -- the best regular profile (input + output if one exists)
//   Solo salida  -- the best output-only one, when Estándar has inputs too
// plus whatever is active now, so the current state is always visible.
function curateProfiles(profiles, active) {
  var picked = []
  var seen = {}
  function add(p, label) {
    if (!p || seen[p.name]) return
    seen[p.name] = true
    picked.push({ name: p.name, label: label })
  }

  var pro = null, duplex = null, output = null
  for (var i = 0; i < profiles.length; i++) {
    var p = profiles[i]
    if (p.name === "pro-audio") { if (!pro) pro = p; continue }
    if (!duplex && p.sinks > 0 && p.sources > 0) duplex = p
    if (!output && p.sinks > 0 && p.sources === 0) output = p
  }

  add(pro, "Pro Audio")
  if (duplex) {
    add(duplex, "Estándar")
    add(output, "Solo salida")
  } else {
    add(output, "Estándar")
  }
  for (var j = 0; j < profiles.length; j++)
    if (profiles[j].name === active) add(profiles[j], profiles[j].description)
  return picked
}

// Card profiles come from wh01s17-audio-card-profiles as JSON, because the
// Pipewire service only exposes nodes. Anything malformed reads as "no cards"
// so the section simply hides instead of breaking the panel.
function parseCardProfiles(raw) {
  var data
  try {
    data = JSON.parse(String(raw || "").trim() || "[]")
  } catch (e) {
    return []
  }
  if (!Array.isArray(data)) return []

  var cards = []
  for (var i = 0; i < data.length; i++) {
    var c = data[i]
    if (!c || !c.name || !Array.isArray(c.profiles)) continue
    var raw_profiles = []
    for (var j = 0; j < c.profiles.length; j++) {
      var p = c.profiles[j]
      if (!p || !p.name) continue
      raw_profiles.push({
        name: String(p.name),
        description: String(p.description || p.name),
        sinks: Number(p.sinks) || 0,
        sources: Number(p.sources) || 0
      })
    }
    var active = String(c.active || "")
    var profiles = curateProfiles(raw_profiles, active)
    if (profiles.length < 2) continue
    var name = String(c.name)
    cards.push({
      name: name,
      description: cardLabel(name, c.description, raw_profiles),
      active: active,
      required: REQUIRED_PROFILES[name] || "",
      profiles: profiles
    })
  }
  return cards
}

function activeProfileLabel(card) {
  if (!card) return ""
  for (var i = 0; i < card.profiles.length; i++)
    if (card.profiles[i].name === card.active) return card.profiles[i].label
  return card.active || "Off"
}

// Non-empty when the card is off the profile the Mezcla routing needs.
function profileWarning(card) {
  if (!card || !card.required || card.active === card.required) return ""
  return "Requiere " + profileName(card.required)
}

// Flatten cards into the primitive rows the panel's Repeater holds: one row per
// card, followed by its profiles when that card is the expanded one. Keyboard
// navigation indexes this list directly, so expanding a card shifts the rows
// below it exactly as they appear on screen.
function profileRows(cards, expandedCard) {
  var values = Array.isArray(cards) ? cards : []
  var rows = []
  for (var i = 0; i < values.length; i++) {
    var card = values[i]
    var expanded = card.name === expandedCard
    var warning = profileWarning(card)
    rows.push({
      kind: "card",
      card: card.name,
      profile: "",
      label: card.description,
      detail: warning || activeProfileLabel(card),
      warning: !!warning,
      expanded: expanded,
      active: false
    })
    if (!expanded) continue
    for (var j = 0; j < card.profiles.length; j++) {
      var p = card.profiles[j]
      rows.push({
        kind: "profile",
        card: card.name,
        profile: p.name,
        label: p.label,
        detail: "",
        warning: false,
        expanded: false,
        active: p.name === card.active
      })
    }
  }
  return rows
}

function withActiveProfile(cards, cardName, profileName) {
  var values = Array.isArray(cards) ? cards : []
  var next = []
  for (var i = 0; i < values.length; i++) {
    var c = values[i]
    next.push(c.name === cardName
      ? { name: c.name, description: c.description, active: profileName,
          required: c.required, profiles: c.profiles }
      : c)
  }
  return next
}

if (typeof module !== "undefined") {
  module.exports = {
    parseCardProfiles: parseCardProfiles,
    curateProfiles: curateProfiles,
    cardLabel: cardLabel,
    activeProfileLabel: activeProfileLabel,
    profileWarning: profileWarning,
    profileRows: profileRows,
    withActiveProfile: withActiveProfile,
    isPlaybackStream: isPlaybackStream,
    isAudioSource: isAudioSource,
    nodeRow: nodeRow,
    rowSnapshot: rowSnapshot,
    outputVolumeName: outputVolumeName,
    parseSinkAvailability: parseSinkAvailability,
    friendlyDeviceLabel: friendlyDeviceLabel,
    nodeProps: nodeProps,
    nodeLabel: nodeLabel,
    isHeadphones: isHeadphones,
    sinkGlyph: sinkGlyph,
    sourceGlyph: sourceGlyph,
    friendlyStreamLabel: friendlyStreamLabel,
    streamLabelKey: streamLabelKey,
    streamLabelIsGeneric: streamLabelIsGeneric,
    rawStreamLabel: rawStreamLabel,
    mprisPlayerLabel: mprisPlayerLabel,
    mprisPlayerIsProxy: mprisPlayerIsProxy,
    streamRepresentsMprisPlayer: streamRepresentsMprisPlayer,
    mprisLabelsFor: mprisLabelsFor,
    matchingMprisStreamLabel: matchingMprisStreamLabel,
    unmatchedMprisStreamLabel: unmatchedMprisStreamLabel,
    streamLabel: streamLabel,
    streamRepresentsPlayer: streamRepresentsPlayer
  }
}
