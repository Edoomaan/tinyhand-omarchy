const test = require("node:test")
const assert = require("node:assert/strict")
const Arm = require("../Arm.js")
const { hands } = require("../Hands.js")

const lavender = hands.find(h => h.id === "lavender")
const screen = { width: 1728, height: 1152 }

// Where the fingertip ends up on screen for a pose, worked out from the
// arm's own frame: origin at the grip, rotated clockwise (y points down).
function fingertip(pose, hand) {
  const localX = (hand.tipX - hand.rodX) * pose.armWidth
  const localY = (hand.tip - hand.handTop) / (hand.wrist - hand.handTop) * pose.handLength - (pose.rodLength + pose.handLength)
  const a = pose.rotation * Math.PI / 180
  return {
    x: pose.gripX + localX * Math.cos(a) - localY * Math.sin(a),
    y: pose.gripY + localX * Math.sin(a) + localY * Math.cos(a),
  }
}

function settle(cursor, hand = lavender, extra = {}) {
  let state = Arm.initial()
  for (let i = 0; i < 400; i++) state = Arm.step(state, { cursor, ...screen, held: false })
  return Arm.pose(state, { cursor, ...screen, hand, size: 0.13, ...extra })
}

test("the fingertip lands on the cursor", () => {
  for (const cursor of [{ x: 864, y: 576 }, { x: 100, y: 80 }, { x: 1700, y: 1100 }, { x: 10, y: 1140 }]) {
    const tip = fingertip(settle(cursor), lavender)
    assert.ok(Math.abs(tip.x - cursor.x) < 0.01 && Math.abs(tip.y - cursor.y) < 0.01,
      `tip ${tip.x},${tip.y} vs cursor ${cursor.x},${cursor.y}`)
  }
})

test("the fingertip lands on the cursor for every hand", () => {
  for (const hand of hands) {
    const tip = fingertip(settle({ x: 600, y: 400 }, hand), hand)
    assert.ok(Math.abs(tip.x - 600) < 0.01 && Math.abs(tip.y - 400) < 0.01, hand.id)
  }
})

test("the grip sits 12% of the screen height below the bottom edge", () => {
  assert.equal(settle({ x: 864, y: 576 }).gripY, 1152 + 0.12 * 1152)
})

test("the grip leans 30% of the width right of the cursor, clamped to 15%..105%", () => {
  assert.ok(Math.abs(settle({ x: 864, y: 576 }).gripX - (864 + 0.30 * 1728)) < 0.01)
  assert.ok(Math.abs(settle({ x: 0, y: 576 }).gripX - 0.30 * 1728) < 0.01)
  assert.ok(Math.abs(settle({ x: 1700, y: 576 }).gripX - 1.05 * 1728) < 0.01)
  assert.ok(Math.abs(settle({ x: -300, y: 576 }).gripX - 0.15 * 1728) < 0.01)
})

test("the grip follows 8% of the remaining distance per tick", () => {
  let state = Arm.step(Arm.initial(), { cursor: { x: 0, y: 500 }, ...screen, held: false })
  assert.ok(Math.abs(state.gripX - 518.4) < 1e-9) // first tick snaps to the target
  state = Arm.step(state, { cursor: { x: 1000, y: 500 }, ...screen, held: false })
  // target 1000 + 518.4 = 1518.4; 518.4 + 0.08 * 1000 = 598.4
  assert.ok(Math.abs(state.gripX - 598.4) < 1e-9)
})

test("a press decays by 18% per tick only while the button is up", () => {
  let state = Arm.press(Arm.initial())
  state = Arm.step(state, { cursor: { x: 1, y: 1 }, ...screen, held: true })
  assert.equal(state.press, 1)
  state = Arm.step(state, { cursor: { x: 1, y: 1 }, ...screen, held: false })
  assert.ok(Math.abs(state.press - 0.82) < 1e-9)
})

test("a full press makes the hand 6% shorter and lowers the lift by 80%", () => {
  const cursor = { x: 864, y: 576 }
  const rest = settle(cursor)
  const pressed = Arm.pose({ ...Arm.press(Arm.initial()), gripX: rest.gripX }, { cursor, ...screen, hand: lavender, size: 0.13 })
  assert.ok(Math.abs(rest.handLength - 0.13 * 1152) < 1e-9)
  assert.ok(Math.abs(pressed.handLength - 0.13 * 1152 * 0.94) < 1e-9)
  assert.ok(Math.abs(rest.lift - 0.06 * 1152) < 1e-9)
  assert.ok(Math.abs(pressed.lift - 0.06 * 1152 * 0.2) < 1e-9)
})

test("the rod never gets shorter than 5% of the screen height", () => {
  assert.ok(settle({ x: 1400, y: 1150 }).rodLength >= 0.05 * 1152 - 1e-9)
})

test("the laser dot is max(4, 0.38% of height scaled by size) and grows 20% on press", () => {
  const rest = Arm.laser({ press: 0 }, { height: 1152, size: 0.13 })
  assert.ok(Math.abs(rest.radius - 1152 * 0.0038) < 1e-9)
  assert.ok(Math.abs(rest.glow - rest.radius * 2.2) < 1e-9)
  const pressed = Arm.laser({ press: 1 }, { height: 1152, size: 0.13 })
  assert.ok(Math.abs(pressed.radius - 1152 * 0.0038 * 1.2) < 1e-9)
  assert.equal(Arm.laser({ press: 0 }, { height: 600, size: 0.08 }).radius, 4)
})

test("two half ticks move the grip as far as one full tick", () => {
  const base = Arm.step(Arm.initial(), { cursor: { x: 0, y: 500 }, ...screen, held: false })
  const one = Arm.step(base, { cursor: { x: 1000, y: 500 }, ...screen, held: false, ticks: 1 })
  const half = Arm.step(base, { cursor: { x: 1000, y: 500 }, ...screen, held: false, ticks: 0.5 })
  const two = Arm.step(half, { cursor: { x: 1000, y: 500 }, ...screen, held: false, ticks: 0.5 })
  assert.ok(Math.abs(two.gripX - one.gripX) < 1e-9)
})
