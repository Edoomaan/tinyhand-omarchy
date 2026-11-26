import QtQuick
import Quickshell
import Quickshell.Io
import "Reveal.js" as Reveal
import "ScreenChange.js" as ScreenChange
import "LogindEvent.js" as LogindEvent

// Overlay entry point (manifest "overlay", keepLoaded). The shell calls
// open()/close() for `omarchy-shell shell summon|hide|toggle edooman-tinyhand`.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: (manifest && manifest.id) || "edooman-tinyhand"
  property string lastScreen: ""

  Connections {
    target: TinyState
    function onPointerScreenChanged() {
      var t = ScreenChange.transition(root.lastScreen, TinyState.pointerScreen, TinyState.active)
      root.lastScreen = TinyState.pointerScreen
      if (t.changed) {
        if (t.endStroke) root.clearStrokesInProgress()
        if (t.clearInk) root.clear()
        if (t.revealMs > 0) TinyState.reveal(t.revealMs)
      }
    }
    function onActiveChanged() {
      if (!TinyState.active) root.lastScreen = ""
      else root.lastScreen = TinyState.pointerScreen
    }
  }

  // isPluginOpen() reads this, so toggle() knows which way to go.
  readonly property bool opened: TinyState.active

  function open(payload) {
    if (TinyState.active) return
    TinyState.active = true
    TinyState.reveal(3000)
    if (!TinyState.settings.firstRunHintShown) {
      TinyState.settings.firstRunHintShown = true
      showFirstRunHint()
    }
  }

  // Shown once (OverlayController.swift:437-452); parts drop out when their feature is off.
  function showFirstRunHint() {
    var keyName = { alt: "Alt", ctrl: "Ctrl", super: "Super" }[TinyState.settings.interactKey] || ""
    var parts = Reveal.hintParts({ interactKey: TinyState.settings.interactKey, doubleShift: TinyState.settings.doubleShiftClickThrough })
    TinyState.showHint(parts.map(function(k) {
      var key = TinyState.t(k + ".key")
      return { key: key.indexOf("%1") >= 0 ? key.arg(keyName) : key, text: TinyState.t(k + ".text") }
    }), 10000)
    TinyState.reveal(10000)
  }

  // Clear-drawing hotkey, toolbar and IPC (Ink.clear via OverlayController.clearInk).
  function clear() {
    var all = screens.instances
    for (var i = 0; i < all.length; i++) all[i].clearInk()
  }

  function close() {
    clear()
    TinyState.hideHint()
    TinyState.revealUntil = 0
    TinyState.active = false
    TinyState.clickThrough = false
    TinyState.interacting = false
  }

  // Turning off from inside (Esc, toolbar ✕) goes through the shell so its
  // open/closed bookkeeping stays in step with ours.
  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
    else close()
  }

  // Double-tap ⇧ latch (OverlayController.swift:304-321): clicks reach apps and
  // the hand stays; a hint explains the new mode for 1.5 s.
  function toggleClickThrough() {
    TinyState.clickThrough = !TinyState.clickThrough
    var on = TinyState.clickThrough
    var k = on ? "through.on" : "through.off"
    TinyState.showHint([
      { key: TinyState.t(k + ".key"), text: TinyState.t(k + ".text") },
      { key: TinyState.t(k + ".key2"), text: TinyState.t(k + ".text2") }
    ], 1500)
    TinyState.reveal(1500)
    if (on) clearStrokesInProgress()
  }

  // IPC entry points for gated Hyprland binds while passing through.
  function interactUp() {
    TinyState.interacting = false
  }

  function interactDown() {
    TinyState.interacting = true
  }

  function shiftDown() {
    TinyState.shiftEvent("down")
  }

  function shiftUp() {
    if (TinyState.shiftEvent("up") && TinyState.settings.doubleShiftClickThrough) {
      toggleClickThrough()
    }
  }

  // Turning click-through on ends any stroke in progress.
  function clearStrokesInProgress() {
    var all = screens.instances
    for (var i = 0; i < all.length; i++) all[i].endPress()
  }

  // Diagnostics for the dev harness: `call debug ""`.
  function debug() {
    var all = screens.instances
    return JSON.stringify({
      active: TinyState.active, pointerScreen: TinyState.pointerScreen, style: TinyState.style,
      surfaces: all.map(function(s) { return s.debugState() })
    })
  }

  // TinyHand plays on every mouse-down it swallows (OverlayController.swift:79).
  function tap() {
    if (TinyState.soundOn) sound.play()
  }

  // Automation / IPC commands (B7, K1; docs/decisions.md Q13)
  function on() {
    open()
  }

  function off() {
    dismiss()
  }

  function toggle() {
    if (TinyState.active) dismiss()
    else open()
  }

  function style(id) {
    if (id) TinyState.setStyle(id)
    if (!TinyState.active) open()
  }

  function sound(arg) {
    var a = String(arg || "").trim().toLowerCase()
    if (a === "on" || a === "1" || a === "true") TinyState.setSound(true)
    else if (a === "off" || a === "0" || a === "false") TinyState.setSound(false)
    else TinyState.toggleSound()
  }

  function command(cmd, arg) {
    var parts = String(cmd || "").split("/")
    var action = parts[0]
    var param = parts.length > 1 ? parts.slice(1).join("/") : arg
    if (action === "on") on()
    else if (action === "off") off()
    else if (action === "toggle") toggle()
    else if (action === "clear") clear()
    else if (action === "style") style(param)
    else if (action === "sound") sound(param)
  }

  // Auto-off on sleep/lock via logind (B7, Q14)
  Process {
    id: logindWatcher
    command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
    running: TinyState.active
    stdout: SplitParser {
      onRead: function(line) {
        if (TinyState.active && LogindEvent.shouldDismiss(line)) {
          root.dismiss()
        }
      }
    }
  }

  TapSound {
    id: sound
    sound: TinyState.settings.tapSound
  }

  Variants {
    id: screens
    model: Quickshell.screens
    PointerSurface {
      overlay: root
      bar: root.shell ? root.shell.bar : null
    }
  }
}
