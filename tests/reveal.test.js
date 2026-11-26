const test = require("node:test")
const assert = require("node:assert/strict")
const Reveal = require("../Reveal.js")

// Toolbar 400 x 56 at (760, 1000) on a y-down screen.
const bar = { x: 760, y: 1000, width: 400, height: 56 }

test("the pointer is near the toolbar within 80 px to either side", () => {
  assert.equal(Reveal.near(bar, { x: 685, y: 1020 }), true)   // 75 px left
  assert.equal(Reveal.near(bar, { x: 675, y: 1020 }), false)  // 85 px left
  assert.equal(Reveal.near(bar, { x: 1235, y: 1020 }), true)  // 75 px right
})

test("the pointer is near the toolbar up to 90 px above it, plus 10 px slack", () => {
  assert.equal(Reveal.near(bar, { x: 900, y: 905 }), true)    // 95 px above
  assert.equal(Reveal.near(bar, { x: 900, y: 895 }), false)   // 105 px above
  assert.equal(Reveal.near(bar, { x: 900, y: 1064 }), true)   // 8 px below
  // CGRect.union is a bounding box, so the corner 50 px left and 50 px above counts too.
  assert.equal(Reveal.near(bar, { x: 710, y: 950 }), true)
})

test("the toolbar shows when near or while the reveal timer runs, never while drawing", () => {
  const base = { showToolbar: true, drawing: false, near: false, now: 1000, revealUntil: 0 }
  assert.equal(Reveal.shown(base), false)
  assert.equal(Reveal.shown({ ...base, near: true }), true)
  assert.equal(Reveal.shown({ ...base, revealUntil: 1500 }), true)
  assert.equal(Reveal.shown({ ...base, near: true, drawing: true }), false)
  assert.equal(Reveal.shown({ ...base, near: true, showToolbar: false }), false)
})

test("the first-run hint lists only the features that are on", () => {
  assert.deepEqual(Reveal.hintParts({ interactKey: "alt", doubleShift: true }),
    ["hint.click", "hint.drag", "hint.hold", "hint.doubleShift", "hint.esc"])
  assert.deepEqual(Reveal.hintParts({ interactKey: "off", doubleShift: false }),
    ["hint.click", "hint.drag", "hint.esc"])
})
