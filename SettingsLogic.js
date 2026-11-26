// Settings logic for TinyHand options (UserDefaults; Sources/TinyHand/Preferences.swift)

var FADE_OPTIONS = [3, 6, 10, 0]
var INTERACT_KEYS = ["alt", "ctrl", "super", "off"]
var SIZE_MIN = 0.08
var SIZE_MAX = 0.20

function togglePinned(pinned, id) {
  var list = Array.isArray(pinned) ? pinned.slice() : []
  var idx = list.indexOf(id)
  if (idx >= 0) {
    if (list.length > 1) list.splice(idx, 1)
    return list
  }
  if (list.length < 8) list.push(id)
  return list
}

function nextFade(current) {
  var idx = FADE_OPTIONS.indexOf(current)
  if (idx < 0 || idx === FADE_OPTIONS.length - 1) return FADE_OPTIONS[0]
  return FADE_OPTIONS[idx + 1]
}

function nextInteractKey(current) {
  var idx = INTERACT_KEYS.indexOf(current)
  if (idx < 0 || idx === INTERACT_KEYS.length - 1) return INTERACT_KEYS[0]
  return INTERACT_KEYS[idx + 1]
}

function clampSize(val) {
  var n = Number(val)
  if (isNaN(n)) return 0.13
  return Math.max(SIZE_MIN, Math.min(SIZE_MAX, Math.round(n * 100) / 100))
}

if (typeof module !== "undefined") {
  module.exports = { FADE_OPTIONS, INTERACT_KEYS, SIZE_MIN, SIZE_MAX, togglePinned, nextFade, nextInteractKey, clampSize }
}
