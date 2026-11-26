// Double-tap ⇧ detection (OverlayController.swift:261-302). A tap is Shift pressed
// alone and released within 0.3 s with no other key or click in between; a second
// tap starting within 0.35 s of the first one's release is the double tap.

var TAP_MAX = 300
var GAP_MAX = 350

function initial() {
  return { downAt: -1, clean: false, lastTapUp: -1 }
}

// kind: "down" | "up" (Shift alone) | "other" (any other key or click). t in ms.
function next(s, kind, t) {
  if (kind === "down") {
    return { state: { downAt: t, clean: true, lastTapUp: s.lastTapUp }, fired: false }
  }
  if (kind === "other") {
    return { state: { downAt: s.downAt, clean: false, lastTapUp: -1 }, fired: false }
  }
  // "up"
  var isTap = s.clean && s.downAt >= 0 && t - s.downAt <= TAP_MAX
  if (!isTap) return { state: initial(), fired: false }
  var second = s.lastTapUp >= 0 && s.downAt - s.lastTapUp <= GAP_MAX
  if (second) return { state: initial(), fired: true }
  return { state: { downAt: -1, clean: false, lastTapUp: t }, fired: false }
}

if (typeof module !== "undefined") module.exports = { initial, next }
