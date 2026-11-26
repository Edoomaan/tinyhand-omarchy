// Toolbar auto-reveal (OverlayController.updateZones, OverlayController.swift:490-495),
// in y-down screen coordinates.

function contains(r, p) {
  return p.x >= r.x && p.x <= r.x + r.width && p.y >= r.y && p.y <= r.y + r.height
}

// The bounding box (CGRect.union) of the toolbar widened 80 px each side and the
// toolbar shifted 90 px up, then grown 10 px at top and bottom.
function near(bar, p) {
  return contains({ x: bar.x - 80, y: bar.y - 100, width: bar.width + 160, height: bar.height + 110 }, p)
}

function shown(s) {
  return s.showToolbar && !s.drawing && (s.near || s.now < s.revealUntil)
}

// First-run hint (OverlayController.swift:437-452), as translation keys.
function hintParts(s) {
  var parts = ["hint.click", "hint.drag"]
  if (s.interactKey !== "off") parts.push("hint.hold")
  if (s.doubleShift) parts.push("hint.doubleShift")
  parts.push("hint.esc")
  return parts
}

if (typeof module !== "undefined") module.exports = { near, shown, hintParts }
