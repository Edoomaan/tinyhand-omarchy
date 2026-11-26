const test = require("node:test")
const assert = require("node:assert/strict")
const DoubleTap = require("../DoubleTap.js")

// Feed events [kind, ms]; return the times at which a double tap fired.
function run(events) {
  let s = DoubleTap.initial()
  const fired = []
  for (const [kind, t] of events) {
    const r = DoubleTap.next(s, kind, t)
    s = r.state
    if (r.fired) fired.push(t)
  }
  return fired
}

test("two quick Shift taps fire once, on the second release", () => {
  assert.deepEqual(run([["down", 0], ["up", 100], ["down", 300], ["up", 380]]), [380])
})

test("a tap held longer than 0.3 s doesn't count", () => {
  assert.deepEqual(run([["down", 0], ["up", 310], ["down", 400], ["up", 450]]), [])
})

test("the second tap must start within 0.35 s of the first release", () => {
  assert.deepEqual(run([["down", 0], ["up", 100], ["down", 460], ["up", 500]]), [])
  assert.deepEqual(run([["down", 0], ["up", 100], ["down", 450], ["up", 500]]), [500])
})

test("any other key or click between press and release cancels the tap", () => {
  assert.deepEqual(run([["down", 0], ["other", 50], ["up", 100], ["down", 200], ["up", 250]]), [])
  assert.deepEqual(run([["down", 0], ["up", 100], ["down", 200], ["other", 220], ["up", 250]]), [])
})

test("a third tap starts a new pair instead of firing again", () => {
  assert.deepEqual(run([["down", 0], ["up", 50], ["down", 100], ["up", 150], ["down", 200], ["up", 250]]), [150])
})
