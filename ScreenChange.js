// Multi-monitor screen transitions (B19; OverlayController.swift:627-632, 703-720).
// When the pointer moves to a new screen while active:
// - end the current stroke in progress
// - clear all ink across all screens
// - reveal the toolbar on the new screen for 1.5 s

function transition(fromScreen, toScreen, active) {
  if (!active) return { changed: false, clearInk: false, endStroke: false, revealMs: 0 }
  if (!fromScreen || !toScreen || fromScreen === toScreen) {
    return { changed: false, clearInk: false, endStroke: false, revealMs: 0 }
  }
  return {
    changed: true,
    clearInk: true,
    endStroke: true,
    revealMs: 1500
  }
}

if (typeof module !== "undefined") module.exports = { transition }
