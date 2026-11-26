pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "Hands.js" as Hands
import "DoubleTap.js" as DoubleTap

// State shared by the overlay and the bar widget (one instance per shell).
// Settings are TinyHand's UserDefaults keys (Sources/TinyHand/Preferences.swift),
// stored outside the plugin folder: a write inside it would trigger a plugin reload.
Singleton {
  id: state

  property bool active: false
  // Double-tap ⇧ latch: clicks reach apps, the hand stays (OverlayController.swift:304-321).
  property bool clickThrough: false
  // Interact key held: clicks reach apps (InputTap.swift:150-168).
  property bool interacting: false
  readonly property bool passThrough: clickThrough || interacting
  // Name of the screen the pointer is on; only that screen draws the hand and toolbar.
  property string pointerScreen: ""
  // Global pointer position from Hyprland while clicks pass through (the overlay
  // gets no pointer events then).
  property point globalCursor: Qt.point(-1, -1)
  property var doubleTap: DoubleTap.initial()

  // Feed Shift/other input; returns true when a double tap fires.
  function shiftEvent(kind) {
    var r = DoubleTap.next(doubleTap, kind, Date.now())
    doubleTap = r.state
    return r.fired
  }

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/edooman-tinyhand"
  readonly property alias settings: adapter

  readonly property var hands: Hands.hands
  readonly property var sounds: Hands.sounds
  readonly property var defaultPinned: ["lavender", "glove", "coral", "plush", "robot", "laser"]

  function hand(id) {
    for (var i = 0; i < hands.length; i++) if (hands[i].id === id) return hands[i]
    return null
  }

  // The saved style, with TinyHand's legacy ids migrated (PointerStyle.swift:111-125).
  readonly property string style: {
    var raw = adapter.pointerStyle
    if (raw === "dot") return "laser"
    if (raw === "sunny") return "coral"
    return raw === "laser" || hand(raw) ? raw : "lavender"
  }
  readonly property bool isLaser: style === "laser"

  readonly property var pinned: {
    var seen = ({}), out = []
    var list = Array.isArray(adapter.pinnedStyles) && adapter.pinnedStyles.length ? adapter.pinnedStyles : defaultPinned
    for (var i = 0; i < list.length && out.length < 8; i++) {
      var id = String(list[i])
      if (!seen[id] && (id === "laser" || hand(id))) { seen[id] = true; out.push(id) }
    }
    return out.length ? out : defaultPinned
  }

  readonly property bool soundOn: isLaser ? adapter.soundLaser : adapter.soundHands

  // Toolbar reveal window end, in ms since the epoch (OverlayController.revealUntil).
  property real revealUntil: 0
  // Hint pill parts: [{ key, text }]; empty hides it. hintUntil ends it.
  property var hint: []
  property real hintUntil: 0

  function reveal(ms) {
    revealUntil = Math.max(revealUntil, Date.now() + ms)
  }

  function showHint(parts, ms) {
    hint = parts
    hintUntil = Date.now() + ms
  }

  function hideHint() {
    hint = []
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function t(key) {
    return strings.t(key)
  }

  function styleTitle(id) {
    return strings.t("style." + id)
  }

  function setStyle(id) {
    if (id !== "laser" && !hand(id)) return
    adapter.pointerStyle = id
  }

  function toggleSound() {
    if (isLaser) adapter.soundLaser = !adapter.soundLaser
    else adapter.soundHands = !adapter.soundHands
  }

  function setSound(on) {
    if (isLaser) adapter.soundLaser = on
    else adapter.soundHands = on
  }

  // Hyprland's request socket: one request per connection.
  Socket {
    id: hyprSocket
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket.sock"
    onConnectedChanged: if (connected) { write("j/cursorpos"); flush() }
    parser: SplitParser {
      splitMarker: ""
      onRead: function(data) {
        try {
          var p = JSON.parse(data)
          state.globalCursor = Qt.point(p.x, p.y)
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 16
    repeat: true
    running: state.active && state.passThrough
    onTriggered: { hyprSocket.connected = false; hyprSocket.connected = true }
  }

  onPassThroughChanged: {
    if (active && passThrough) {
      hyprSocket.connected = false
      hyprSocket.connected = true
    }
  }

  onActiveChanged: {
    doubleTap = DoubleTap.initial()
  }

  FileView {
    id: file
    path: state.stateDir + "/settings.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound) {
        Quickshell.execDetached(["mkdir", "-p", state.stateDir])
        saveSoon.start()
      }
    }

    JsonAdapter {
      id: adapter
      property real pointerSize: 0.13
      property bool showShadow: true
      property real fadeSeconds: 3
      property bool soundHands: true
      property bool soundLaser: false
      property string tapSound: "thock"
      property string interactKey: "alt"
      property bool interactKeepsHand: false
      property bool doubleShiftClickThrough: true
      property string inkChoice: "match"
      property bool showToolbar: true
      property bool showInkButton: true
      property var pinnedStyles: []
      property string pointerStyle: "lavender"
      property bool firstRunHintShown: false
    }
  }

  // The state directory is created asynchronously on first run.
  Timer {
    id: saveSoon
    interval: 300
    onTriggered: file.writeAdapter()
  }
}
