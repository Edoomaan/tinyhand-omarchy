const test = require("node:test")
const assert = require("node:assert/strict")
const SettingsLogic = require("../SettingsLogic.js")

test("togglePinned adds an unpinned style up to 8", () => {
  let list = ["lavender", "glove"]
  list = SettingsLogic.togglePinned(list, "coral")
  assert.deepEqual(list, ["lavender", "glove", "coral"])
})

test("togglePinned removes a pinned style as long as at least 1 remains", () => {
  let list = ["lavender", "glove"]
  list = SettingsLogic.togglePinned(list, "glove")
  assert.deepEqual(list, ["lavender"])
  // Trying to remove the last one does nothing
  list = SettingsLogic.togglePinned(list, "lavender")
  assert.deepEqual(list, ["lavender"])
})

test("togglePinned does not exceed 8 pinned styles", () => {
  let list = ["1", "2", "3", "4", "5", "6", "7", "8"]
  list = SettingsLogic.togglePinned(list, "9")
  assert.equal(list.length, 8)
  assert.ok(!list.includes("9"))
})

test("nextFade cycles through fade options", () => {
  assert.equal(SettingsLogic.nextFade(3), 6)
  assert.equal(SettingsLogic.nextFade(6), 10)
  assert.equal(SettingsLogic.nextFade(10), 0)
  assert.equal(SettingsLogic.nextFade(0), 3)
})

test("nextInteractKey cycles through interact keys", () => {
  assert.equal(SettingsLogic.nextInteractKey("alt"), "ctrl")
  assert.equal(SettingsLogic.nextInteractKey("ctrl"), "super")
  assert.equal(SettingsLogic.nextInteractKey("super"), "off")
  assert.equal(SettingsLogic.nextInteractKey("off"), "alt")
})

test("clampSize bounds pointerSize within 0.08..0.20", () => {
  assert.equal(SettingsLogic.clampSize(0.05), 0.08)
  assert.equal(SettingsLogic.clampSize(0.25), 0.20)
  assert.equal(SettingsLogic.clampSize(0.13), 0.13)
})
