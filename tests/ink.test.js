const test = require("node:test")
const assert = require("node:assert/strict")
const Ink = require("../Ink.js")

const near = (a, b) => Math.abs(a - b) < 1e-9

test("a stroke starts only once the drag is 4 px from the press", () => {
  assert.equal(Ink.startsStroke({ x: 10, y: 10 }, { x: 13, y: 12 }), false) // 3.6 px
  assert.equal(Ink.startsStroke({ x: 10, y: 10 }, { x: 14, y: 10 }), true)
})

test("points closer than 1.5 px to the last one are dropped", () => {
  let pts = [{ x: 0, y: 0 }]
  pts = Ink.extend(pts, { x: 1, y: 1 })   // 1.41 px
  assert.equal(pts.length, 1)
  pts = Ink.extend(pts, { x: 1.5, y: 0 }) // exactly 1.5 px
  assert.equal(pts.length, 2)
})

test("a single point draws a dot", () => {
  assert.equal(Ink.svgPath([{ x: 5, y: 6 }]), "M 5 6 L 5 6")
})

test("the path curves through midpoints and ends on the last point", () => {
  const d = Ink.svgPath([{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }])
  assert.equal(d, "M 0 0 Q 0 0 5 0 Q 10 0 10 5 L 10 10")
})

test("stroke width is 0.55% of the screen height, at least 3", () => {
  assert.ok(near(Ink.width(1440), 7.92))
  assert.equal(Ink.width(400), 3)
})

test("arrowhead size is max(14, 3.2 x width), capped at 80% of the last stretch", () => {
  // width 5 -> size 16; aimed from the last point >= 19.2 px back.
  const pts = [{ x: 0, y: 0 }, { x: 100, y: 0 }]
  const arms = Ink.arrowHead(pts, 5)
  assert.equal(arms.length, 2)
  for (const arm of arms) {
    assert.deepEqual(arm.from, { x: 100, y: 0 })
    assert.ok(near(Math.hypot(arm.to.x - 100, arm.to.y), 16))
  }
  // Arms sit pi/7 either side of straight back (180 deg).
  const angles = arms.map(a => Math.atan2(a.to.y, a.to.x - 100)).map(Math.abs).sort()
  assert.ok(near(angles[0], Math.PI - Math.PI / 7) && near(angles[1], Math.PI - Math.PI / 7))
  // Short stroke: head is 80% of its length.
  const short = Ink.arrowHead([{ x: 0, y: 0 }, { x: 10, y: 0 }], 5)
  assert.ok(near(Math.hypot(short[0].to.x - 10, short[0].to.y), 8))
})

test("the arrowhead aims along the last stretch, ignoring a wobble at the end", () => {
  // Heading right, then a 2 px hook down at the end: the head still points right.
  const pts = [{ x: 0, y: 0 }, { x: 50, y: 0 }, { x: 100, y: 0 }, { x: 101, y: 2 }]
  const arms = Ink.arrowHead(pts, 5)
  const mid = { x: (arms[0].to.x + arms[1].to.x) / 2, y: (arms[0].to.y + arms[1].to.y) / 2 }
  const dir = Math.atan2(2 - mid.y, 101 - mid.x)
  assert.ok(Math.abs(dir) < 0.05, `direction ${dir}`)
})

test("no arrowhead when the stroke is shorter than 1 px", () => {
  assert.deepEqual(Ink.arrowHead([{ x: 0, y: 0 }, { x: 0.5, y: 0 }], 5), [])
})

test("ink colour: a fixed choice wins, 'match' uses the pointer's own ink", () => {
  assert.equal(Ink.color("orange", "#8754F2"), "#FF8A00")
  assert.equal(Ink.color("match", "#16A87A"), "#16A87A")
  assert.equal(Ink.color("nonsense", "#16A87A"), "#16A87A")
})

test("ink fades after max(0.5, fadeSeconds); 0 keeps it", () => {
  assert.equal(Ink.fadeDelay(3), 3000)
  assert.equal(Ink.fadeDelay(0.2), 500)
  assert.equal(Ink.fadeDelay(0), -1)
})
