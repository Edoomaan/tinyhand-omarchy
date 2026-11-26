// Ink maths, ported from TinyHand's Ink.swift and OverlayController.drag (OverlayController.swift:364-381).

var PALETTE = {
  red: "#FF291F", orange: "#FF8A00", yellow: "#FFCC00", green: "#30C25A",
  blue: "#0A84FF", purple: "#8754F2", white: "#FFFFFF", black: "#1D1D21",
}
var CHOICES = ["match", "red", "orange", "yellow", "green", "blue", "purple", "white", "black"]

function dist(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y)
}

// A drag becomes a stroke once it is 4 px from where the button went down.
function startsStroke(down, p) {
  return dist(down, p) >= 4
}

// Drop points closer than 1.5 px to the previous one.
function extend(points, p) {
  if (points.length && dist(points[points.length - 1], p) < 1.5) return points
  return points.concat([{ x: p.x, y: p.y }])
}

function width(screenHeight) {
  return Math.max(3, screenHeight * 0.0055)
}

// Quadratic smoothing through midpoints, then a line to the last point (Ink.smoothPath).
function svgPath(points) {
  if (!points.length) return ""
  var f = points[0]
  var d = "M " + f.x + " " + f.y
  if (points.length === 1) return d + " L " + f.x + " " + f.y
  for (var i = 1; i < points.length; i++) {
    var prev = points[i - 1], p = points[i]
    d += " Q " + prev.x + " " + prev.y + " " + (prev.x + p.x) / 2 + " " + (prev.y + p.y) / 2
  }
  var last = points[points.length - 1]
  return d + " L " + last.x + " " + last.y
}

// Two arms from the last point, pi/7 either side of straight back, aimed from the
// last point at least 1.2 x size back so a wobble at the end doesn't twist it (Ink.addHead).
function arrowHead(points, strokeWidth) {
  if (!points.length) return []
  var size = Math.max(14, strokeWidth * 3.2)
  var end = points[points.length - 1]
  var back = points[0]
  for (var i = points.length - 1; i >= 0; i--) {
    if (dist(end, points[i]) >= size * 1.2) { back = points[i]; break }
  }
  var length = dist(end, back)
  if (length <= 1) return []
  var head = Math.min(size, length * 0.8)
  var angle = Math.atan2(end.y - back.y, end.x - back.x)
  var spread = Math.PI / 7
  return [-1, 1].map(function(side) {
    var a = angle + Math.PI + side * spread
    return { from: { x: end.x, y: end.y }, to: { x: end.x + Math.cos(a) * head, y: end.y + Math.sin(a) * head } }
  })
}

function arrowSvg(points, strokeWidth) {
  return arrowHead(points, strokeWidth).map(function(arm) {
    return "M " + arm.from.x + " " + arm.from.y + " L " + arm.to.x + " " + arm.to.y
  }).join(" ")
}

function color(choice, pointerInk) {
  return PALETTE[choice] || pointerInk
}

// Milliseconds to wait before fading a finished stroke; -1 keeps it until cleared.
function fadeDelay(fadeSeconds) {
  return fadeSeconds <= 0 ? -1 : Math.max(0.5, fadeSeconds) * 1000
}

if (typeof module !== "undefined") module.exports = { PALETTE, CHOICES, startsStroke, extend, width, svgPath, arrowHead, arrowSvg, color, fadeDelay }
