import QtQuick
import Quickshell
import Quickshell.Wayland
import "Arm.js" as Arm
import "Ink.js" as Ink
import "Reveal.js" as Reveal

// One fullscreen layer-shell surface per screen while the pointer is on.
// It takes every click (InputTap.swift:187-200 swallows them on macOS) and
// hides the system cursor. Only the surface under the pointer draws the hand.
PanelWindow {
  id: surface

  required property var modelData
  property var overlay: null    // HandOverlay root, for dismiss()
  property var bar: null        // Omarchy's bar (shell.bar), for its pass-through strip

  // OnDemand, not Exclusive: with Exclusive focus Hyprland ignores the input
  // mask, which click-through needs (prototype/VERDICT.md on prototype/overlay).
  property int keyboardMode: WlrKeyboardFocus.OnDemand

  readonly property bool current: TinyState.pointerScreen === modelData.name
  property point cursor: Qt.point(width / 2, height / 2)
  property bool held: false
  property var armState: Arm.initial()
  property var downPoint: null   // left-button press point, for the 4 px draw threshold
  property real now: Date.now()
  // The Omarchy bar strip on this screen. Its clicks pass through and the real
  // cursor shows there, like the macOS menu bar (B12, B13).
  readonly property var barRect: {
    if (!bar || typeof bar.barSizeFor !== "function") return null
    var t = bar.barSizeFor(modelData.name)
    if (!(t > 0)) return null
    switch (bar.position) {
    case "bottom": return Qt.rect(0, height - t, width, t)
    case "left": return Qt.rect(0, 0, t, height)
    case "right": return Qt.rect(width - t, 0, t, height)
    default: return Qt.rect(0, 0, width, t)
    }
  }
  // Bottom of the usable area (TinyHand: visibleFrame.minY).
  readonly property real bottomInset: barRect && bar.position === "bottom" ? barRect.height : 0
  readonly property bool pointerInBar: barRect !== null
    && drawCursor.x >= barRect.x && drawCursor.x < barRect.x + barRect.width
    && drawCursor.y >= barRect.y && drawCursor.y < barRect.y + barRect.height

  // While passing clicks through, the hand follows Hyprland's cursor position.
  readonly property point drawCursor: TinyState.passThrough
    ? Qt.point(TinyState.globalCursor.x - modelData.x, TinyState.globalCursor.y - modelData.y)
    : cursor
  readonly property bool pointerHere: TinyState.passThrough
    ? drawCursor.x >= 0 && drawCursor.y >= 0 && drawCursor.x < width && drawCursor.y < height
    : hover.hovered

  function endPress() {
    held = false
    downPoint = null
    ink.end()
  }

  function isInteractKey(key) {
    switch (TinyState.settings.interactKey) {
    case "alt": return key === Qt.Key_Alt
    case "ctrl": return key === Qt.Key_Control
    case "super": return key === Qt.Key_Super_L || key === Qt.Key_Super_R || key === Qt.Key_Meta
    default: return false
    }
  }

  function debugState() {
    return { screen: modelData.name, visible: visible, current: current, hovered: hover.hovered, kbActive: keys.Window.active, kbMode: keyboardMode,
             cursor: [cursor.x, cursor.y], size: [width, height], pose: pose !== null, toolbar: toolbar.revealed }
  }

  function clearInk() {
    ink.clear()
  }

  screen: modelData
  visible: TinyState.active
  anchors { top: true; left: true; right: true; bottom: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "edooman-tinyhand-pointer"
  WlrLayershell.keyboardFocus: keyboardMode

  mask: TinyState.passThrough ? noInput : (barRect ? allButBar : null)
  Region { id: noInput }
  Region {
    id: allButBar
    width: surface.width
    height: surface.height
    Region {
      intersection: Intersection.Subtract
      x: surface.barRect ? surface.barRect.x : 0
      y: surface.barRect ? surface.barRect.y : 0
      width: surface.barRect ? surface.barRect.width : 0
      height: surface.barRect ? surface.barRect.height : 0
    }
  }

  // After a click went through to an app, that app holds the keyboard. Taking it
  // back (Exclusive, then OnDemand) keeps Esc, the interact key and ⇧ working.
  function reclaimKeyboard() {
    keyboardMode = WlrKeyboardFocus.Exclusive
    Qt.callLater(function() { surface.keyboardMode = WlrKeyboardFocus.OnDemand; keys.forceActiveFocus() })
  }
  Timer {
    interval: 200
    repeat: true
    running: surface.visible && surface.current && TinyState.passThrough
    onTriggered: if (!keys.Window.active) surface.reclaimKeyboard()
  }
  Connections {
    target: TinyState
    function onPassThroughChanged() {
      if (!TinyState.passThrough && surface.current) surface.reclaimKeyboard()
    }
  }

  readonly property var hand: TinyState.hand(TinyState.style)
  readonly property var pose: hand ? Arm.pose(armState, {
    cursor: { x: drawCursor.x, y: drawCursor.y }, width: width, height: height,
    hand: hand, size: TinyState.settings.pointerSize
  }) : null

  onVisibleChanged: {
    held = false
    downPoint = null
    armState = Arm.initial()
    ink.clear()
  }

  function tick(seconds) {
    now = Date.now()
    if (TinyState.passThrough && pointerHere && !current) TinyState.pointerScreen = modelData.name
    if (TinyState.hint.length && now >= TinyState.hintUntil) TinyState.hideHint()
    armState = Arm.step(armState, {
      cursor: { x: drawCursor.x, y: drawCursor.y }, width: width, height: height,
      held: held, ticks: seconds * 120
    })
  }

  // 120 Hz in TinyHand; here one step per rendered frame, scaled by elapsed time.
  FrameAnimation {
    running: surface.visible && (surface.current || TinyState.passThrough)
    onTriggered: surface.tick(Math.min(frameTime, 0.1))
  }

  // Tracks the pointer everywhere on the surface, toolbar included (hover is
  // delivered to every item under the pointer). Handlers need an Item parent.
  Item {
    anchors.fill: parent
    HoverHandler {
      id: hover
      cursorShape: Qt.BlankCursor
      onPointChanged: {
        surface.cursor = point.position
        TinyState.pointerScreen = surface.modelData.name
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    cursorShape: Qt.BlankCursor

    onPositionChanged: function(mouse) {
      surface.cursor = Qt.point(mouse.x, mouse.y)
      // Only a left-button drag draws (OverlayController.swift:364-377; InputTap.swift:202-204).
      if (!surface.downPoint || !(mouse.buttons & Qt.LeftButton)) return
      var p = { x: mouse.x, y: mouse.y }
      if (!ink.drawing) {
        if (!Ink.startsStroke(surface.downPoint, p)) return
        ink.begin(surface.downPoint)
      }
      ink.arrow = (mouse.modifiers & Qt.ControlModifier) !== 0
      ink.extend(p)
    }
    onPressed: function(mouse) {
      surface.cursor = Qt.point(mouse.x, mouse.y)
      TinyState.pointerScreen = surface.modelData.name
      surface.held = true
      TinyState.hideHint()
      TinyState.shiftEvent("other")
      surface.downPoint = mouse.button === Qt.LeftButton ? { x: mouse.x, y: mouse.y } : null
      surface.armState = Arm.press(surface.armState)
      if (surface.overlay) surface.overlay.tap()
      keys.forceActiveFocus()
    }
    onReleased: surface.endPress()
    onCanceled: surface.endPress()
  }

  InkLayer {
    id: ink
    anchors.fill: parent
    color: Ink.color(TinyState.settings.inkChoice, TinyState.isLaser ? Ink.PALETTE.red : (surface.hand ? surface.hand.ink : Ink.PALETTE.purple))
    fadeDelay: Ink.fadeDelay(TinyState.settings.fadeSeconds)
  }

  Toolbar {
    id: toolbar
    z: 1   // the ink tray sits above the hint pill
    visible: surface.current
    x: Math.round((surface.width - width) / 2)
    y: Math.round(surface.height - surface.bottomInset - 14 - height)
    currentInk: ink.color
    revealed: surface.current && Reveal.shown({
      showToolbar: TinyState.settings.showToolbar,
      drawing: ink.drawing,
      near: Reveal.near({ x: toolbar.x, y: toolbar.y, width: toolbar.width, height: toolbar.height }, { x: surface.cursor.x, y: surface.cursor.y }),
      now: surface.now,
      revealUntil: TinyState.revealUntil
    })
    onExitRequested: if (surface.overlay) surface.overlay.dismiss()
  }

  HintPill {
    visible: surface.current && opacity > 0
    parts: TinyState.hint
    x: Math.round((surface.width - width) / 2)
    y: toolbar.y - 12 - height
  }

  // The hand hides while the interact key is held or when over the Omarchy bar,
  // unless "keep the hand" is on (OverlayController.swift:509-528; B12, B13).
  Item {
    anchors.fill: parent
    visible: surface.current && surface.pointerHere
      && !(TinyState.interacting && !TinyState.settings.interactKeepsHand)
      && !(surface.pointerInBar && !TinyState.settings.interactKeepsHand)

    HandArm {
      visible: !TinyState.isLaser && surface.pose !== null
      hand: surface.hand || TinyState.hands[0]
      pose: surface.pose || Arm.pose(Arm.initial(), { cursor: { x: 0, y: 0 }, width: 1, height: 1, hand: TinyState.hands[0], size: 0.13 })
      showShadow: TinyState.settings.showShadow
    }

    LaserDot {
      visible: TinyState.isLaser
      cursorX: surface.drawCursor.x
      cursorY: surface.drawCursor.y
      shape: Arm.laser(surface.armState, { height: surface.height, size: TinyState.settings.pointerSize })
    }
  }

  Item {
    id: keys
    focus: true
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        event.accepted = true
        if (surface.overlay) surface.overlay.dismiss()
        return
      }
      // ⌘ while drawing adds an arrowhead, live mid-stroke (OverlayController.swift:268-271).
      // Ctrl here: SUPER+drag is Hyprland's window move (docs/decisions.md, Q3).
      if (event.key === Qt.Key_Control) ink.arrow = ink.drawing
      if (event.isAutoRepeat) return
      if (surface.isInteractKey(event.key)) TinyState.interacting = true
      // Shift alone starts a tap; anything else breaks one.
      if (event.key === Qt.Key_Shift && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) TinyState.shiftEvent("down")
      else TinyState.shiftEvent("other")
    }
    Keys.onReleased: function(event) {
      if (event.key === Qt.Key_Control) ink.arrow = false
      if (event.isAutoRepeat) return
      if (surface.isInteractKey(event.key)) TinyState.interacting = false
      if (event.key === Qt.Key_Shift && TinyState.shiftEvent("up")
          && TinyState.settings.doubleShiftClickThrough && surface.overlay)
        surface.overlay.toggleClickThrough()
    }
  }
}
