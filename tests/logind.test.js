const test = require("node:test")
const assert = require("node:assert/strict")
const LogindEvent = require("../LogindEvent.js")

test("ignores irrelevant bus noise", () => {
  assert.equal(LogindEvent.shouldDismiss("Monitoring signals on system bus"), false)
  assert.equal(LogindEvent.shouldDismiss("/org/freedesktop/login1: org.freedesktop.DBus.Properties.PropertiesChanged"), false)
  assert.equal(LogindEvent.shouldDismiss("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)"), false)
})

test("detects PrepareForSleep(true)", () => {
  const line = "/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)"
  assert.equal(LogindEvent.shouldDismiss(line), true)
})

test("detects Session.Lock", () => {
  const line = "/org/freedesktop/login1/session/_31: org.freedesktop.login1.Session.Lock ()"
  assert.equal(LogindEvent.shouldDismiss(line), true)
})
