const test = require("node:test")
const assert = require("node:assert/strict")
const ScreenChange = require("../ScreenChange.js")

test("no transition when inactive", () => {
  const r = ScreenChange.transition("DP-1", "DP-2", false)
  assert.equal(r.changed, false)
  assert.equal(r.clearInk, false)
})

test("no transition when staying on the same screen", () => {
  const r = ScreenChange.transition("DP-1", "DP-1", true)
  assert.equal(r.changed, false)
  assert.equal(r.clearInk, false)
})

test("no transition on initial screen acquisition (from empty)", () => {
  const r = ScreenChange.transition("", "DP-1", true)
  assert.equal(r.changed, false)
  assert.equal(r.clearInk, false)
})

test("screen transition ends stroke, clears ink, and reveals toolbar for 1.5 s", () => {
  const r = ScreenChange.transition("DP-1", "DP-2", true)
  assert.equal(r.changed, true)
  assert.equal(r.endStroke, true)
  assert.equal(r.clearInk, true)
  assert.equal(r.revealMs, 1500)
})
