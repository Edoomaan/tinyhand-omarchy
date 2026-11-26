// Hand-on-a-stick pose, ported from TinyHand's ArmView.aim (Sources/TinyHand/ArmView.swift:121-217).
// TinyHand works in macOS points with y up; this file takes and returns QML coordinates (y down)
// and does the maths in y-up internally so it stays line-for-line comparable with the original.

var MIN_ROD = 0.05       // rod at least 5% of screen height
var GRIP_LEAN = 0.30     // grip sits 30% of the width right of the cursor
var GRIP_DEPTH = 0.12    // grip sits 12% of the height below the bottom edge
var GRIP_FOLLOW = 0.08   // per-tick easing towards the target
var LIFT = 0.06          // shadow lift at rest
var PRESS_DECAY = 0.18   // per-tick press decay while the button is up

function initial() {
  return { gripX: null, press: 0 }
}

function press(state) {
  return { gripX: state.gripX, press: 1 }
}

// One tick: ease the grip towards its target and decay the press. TinyHand ticks at 120 Hz;
// `input.ticks` (default 1) lets a caller at another frame rate advance by elapsed/(1/120).
function step(state, input) {
  var w = input.width
  var n = input.ticks === undefined ? 1 : input.ticks
  var target = Math.min(Math.max(input.cursor.x + GRIP_LEAN * w, w * 0.15), w * 1.05)
  var follow = 1 - Math.pow(1 - GRIP_FOLLOW, n)
  var gripX = state.gripX === null ? target : state.gripX + (target - state.gripX) * follow
  var p = input.held ? state.press : state.press * Math.pow(1 - PRESS_DECAY, n)
  return { gripX: gripX, press: p }
}

// True while the arm is still moving on its own (grip catching up or press decaying).
function settling(state, input) {
  if (state.press > 0.002) return true
  if (state.gripX === null) return false
  var target = Math.min(Math.max(input.cursor.x + GRIP_LEAN * input.width, input.width * 0.15), input.width * 1.05)
  return Math.abs(target - state.gripX) > 0.5
}

// Geometry for drawing. The arm is an item of size armWidth x (rodLength + handLength) whose
// bottom point at (hand.rodX * armWidth, bottom) sits on (gripX, gripY), rotated `rotation`
// degrees clockwise around that point; the hand is the top handLength of it.
function pose(state, input) {
  var H = input.height
  var hand = input.hand
  var gx = state.gripX === null ? input.cursor.x : state.gripX
  var gripUpY = -GRIP_DEPTH * H
  var cursorUpY = H - input.cursor.y

  var dx = input.cursor.x - gx
  var dy = cursorUpY - gripUpY
  var reach = Math.hypot(dx, dy)
  var aimAngle = Math.atan2(dy, dx)

  var handPts = input.size * H * (1 - 0.06 * state.press)
  var s = handPts / (hand.wrist - hand.handTop)
  var widthPts = s * hand.aspect
  var handTipPts = (hand.wrist - hand.tip) * s
  var tipOffX = (hand.tipX - hand.rodX) * widthPts

  var along = Math.sqrt(Math.max(0, reach * reach - tipOffX * tipOffX))
  var rodLen = Math.max(MIN_ROD * H, along - handTipPts)
  var tipAngle = Math.atan2(rodLen + handTipPts, tipOffX)
  var rotation = aimAngle - tipAngle // radians, counter-clockwise in y-up

  var lift = LIFT * H * (1 - 0.8 * state.press)
  // Screen-space shadow offset (0.6 lift right, lift down) expressed in the rotated arm's frame.
  var qmlRad = -rotation
  var sx = lift * 0.6, sy = lift
  return {
    gripX: gx,
    gripY: H - gripUpY,
    rotation: qmlRad * 180 / Math.PI,
    rodLength: rodLen,
    handLength: handPts,
    armWidth: widthPts,
    lift: lift,
    shadowX: sx * Math.cos(-qmlRad) - sy * Math.sin(-qmlRad),
    shadowY: sx * Math.sin(-qmlRad) + sy * Math.cos(-qmlRad),
    shadowRadius: Math.max(1, lift * 0.35) + 5 * state.press,
    shadowOpacity: 0.26 + 0.02 * state.press,
  }
}

// Laser dot (ArmView.aimLaser, ArmView.swift:199-217).
function laser(state, input) {
  var r = Math.max(4, input.height * 0.0038 * input.size / 0.13) * (1 + 0.2 * state.press)
  return { radius: r, core: r * 0.45, glow: r * (2.2 + 1.0 * state.press) }
}

if (typeof module !== "undefined") module.exports = { initial, press, step, settling, pose, laser }
