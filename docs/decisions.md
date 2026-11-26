# Decisions

One line each: decision — rationale. Dated 2026-11-17 unless noted.

## Process
- Development repo is `~/Work/edooman.tinyhand` — user's request; it becomes the plugin's git source.
- Issue tracker: local markdown under `.scratch/` — user's choice, no GitHub.
- Agent config file: `CLAUDE.md` (not `AGENTS.md`) — neither existed; the user works in Claude Code.
- Triage labels: defaults — no existing tracker vocabulary to match.
- Plugin guide = Omarchy's `plugins.md`, not the `omarchy-app` skill — that skill covers standalone C++ apps and has no plugin guide.
- Dev loop: `omarchy plugin add ~/Work/edooman.tinyhand` once, then commit + `omarchy plugin update edooman.tinyhand` — the plugin watcher (`inotifywait -r`, PluginRegistry.qml:726) does not follow symlinks, and add/update is the real user install path.
- Grilling stage replaced by self-review of open questions — user's request (busy).

## Hotkey
- `CTRL+ALT+H` (original Ctrl+Option+H) — free: the only live H bind is `SUPER+CTRL+H` (Hardware menu) per `hyprctl binds -j`.
- Fallback `SUPER+ALT+H` not used — `CTRL+ALT+H` is free. Clear drawing: `CTRL+ALT+X` (original ⌃⌥X), also free.
- Binds are written to `~/.config/hypr/bindings.lua` (this plugin's binds only) — a plugin can't register them itself (research §3 row 9).

## Stage 2 — self-review of open questions (research §5)
Rule: where the original is clear, take the most 1:1 option; where the Omarchy guide conflicts, the guide wins (user's instruction).
- Q1 Scroll/hover while on: the overlay takes **all** pointer input, scroll included — Wayland routes pointer input to the topmost surface with an input region; a client can't forward events it received.
- Q2 Keyboard while on: ~~Exclusive~~ → `WlrKeyboardFocus.OnDemand` (changed in Stage 3) — the overlay still gets the keyboard on open (native Esc, Ctrl for arrows, Alt/Shift presses), but with `Exclusive` Hyprland ignores the input mask, which would make click-for-real and click-through impossible. Apps can't be typed into while the hand is on.
- Q3 Arrow modifier: **Ctrl** — ⌘ maps to Ctrl by Linux convention, and `SUPER+drag` is Hyprland's window move.
- Q4 Keep hold-Alt "click for real" and double-⇧ click-through — both are clear original behavior; done by emptying the overlay's input mask so the compositor routes the pointer to the app. With keyboard focus kept on the overlay, the app receives the click without Alt, which matches "modifier stripped".
- Q4a While the click-through latch is on, Esc still exits (original passes Esc to apps) — keyboard focus must stay on the overlay to see the second double-⇧.
- Q4b Hand position while the mask is empty comes from Hyprland's request socket (`j/cursorpos`) — the overlay gets no pointer events then.
- Q5 Multi-monitor: one surface per screen (`Variants`), hand/toolbar drawn only on the screen under the pointer, ink cleared on a screen change — closest to "one overlay that follows the mouse" (B19); a single layer surface can't span outputs.
- Q6 `CTRL+ALT+H` toggle, `CTRL+ALT+X` clear — 1:1.
- Q7 Settings: plugin-owned `settings.json` inside the plugin folder (gitignored, survives `omarchy plugin update`'s fast-forward) — keeps writes inside the plugin's own folder instead of `shell.json`. Settings UI: a bar-widget panel with the I2–I4 options; the pinned-styles editor becomes a checkbox grid (max 8) instead of drag-to-reorder.
- Q8 Port all 36 hands, 15 sounds and the laser — MIT, and they are the product.
- Q9 Custom-hand maker: **not ported** — it is a separate image-processing tool with a file picker and an external ChatGPT flow, not pointer behavior.
- Q10 Bar widget: left click toggles; right click opens a menu with Turn Pointer On/Off, Clear Drawing, Tap Sound, Settings — Allow Accessibility, Check for Updates and Quit have no meaning for a plugin.
- Q11 Animations follow the guide (`Style.duration`, ≤300 ms, no ease-in, exits shorter: toolbar/hint 180 ms in / 120 ms out, ink fade 200 ms OutCubic after the same 3 s default wait) — guide wins over the plan. The hand's swing/lag and press decay stay 1:1 (they are physics, not UI transitions).
- Q12 Toolbar uses Omarchy theme tokens, not fixed dark glass — guide (theming).
- Q13 No `tinyhand://` handler and no `state.json` — the scheme needs a `.desktop` file outside the plugin; the same commands are exposed as `omarchy-shell shell call edooman.tinyhand <on|off|toggle|clear|style|sound>`.
- Q14 Turn off on sleep/lock via a logind D-Bus watcher (`PrepareForSleep`, session `Lock`) while on — otherwise clicks stay swallowed after unlock.
- Q15 The Omarchy bar passes clicks through and shows the real cursor (B12/B13) — bar geometry read from `hyprctl layers -j` (`omarchy-bar`) on activation.
- Q16 Ship `en.json` and `tr.json`.
- Not possible, dropped: open-menu detection (row 5), in-app shortcut recorder (row 10; README tells how to rebind), Accessibility/Welcome flow (row 25; the first-run hint stays), energy hint (row 27). Launch at login = plugin enabled (row 23); self-update = `omarchy plugin update` (row 24).

## Stage 3 — prototype (branch `prototype/overlay`, see `prototype/VERDICT.md` there)
- Fullscreen layer-shell overlay with a `MouseArea` swallows clicks on Hyprland; while off the surface is unmapped and swallows nothing — verified with a virtual pointer in a nested Hyprland.
- Own `PanelWindow` per screen instead of Omarchy's `OverlayWindow` — `OverlayWindow` hard-codes one screen and `Exclusive` focus by default; it exposes `shownKeyboardFocus`, but multi-monitor (Q5) needs one surface per screen anyway.
- Click-for-real and click-through use an empty `mask: Region {}`; after such a click the app owns the keyboard, so Alt release and Shift taps are caught by Hyprland binds that are enabled only while the overlay's layer is open (Omarchy's own pattern in `default/hypr/bindings/utilities.lua:45-90`), calling `omarchy-shell shell call edooman.tinyhand ...` (~20 ms). After a pass-through ends, flip `keyboardFocus` Exclusive→OnDemand to take the keyboard back.
- Hand position while masked: Hyprland request socket `j/cursorpos` through Quickshell `Socket`.
- Dev loop: `omarchy plugin update` + **`omarchy restart shell`** — the running shell keeps compiled QML per file URL, so hot reload serves stale code (also the cause of the earlier attempt's observation). QML is developed and tested in the nested Hyprland harness first, so the real shell is restarted rarely.

## Stage 4 — plan
- `/to-spec`, `/to-tickets` and `/implement` are user-invoke-only (`disable-model-invocation`), so they could not be run autonomously; the plan is a plain ordered slice list in `docs/plan.md` instead, and `.scratch/` stays unused. The user can run those skills later.

## Stage 5 — implementation notes (2026-11-18)
- Slices 6–10 completed autonomously.
- Pass-through: Gated layer binds in `dev/nested-hyprland.lua` and `~/.config/hypr/bindings.lua` catch Alt release and Shift taps while apps hold keyboard focus. `DoubleTap.js` handles timing and state.
- Multi-monitor: Screen transitions trigger stroke termination, clear ink across surfaces, and reveal the toolbar for 1.5 s on the active screen (`ScreenChange.js`).
- Settings & Bar: `BarWidget.qml` handles left-click toggle, right-click menu, and settings view inside `PopupCard`. Pure logic in `SettingsLogic.js`.
- Lifecycle & IPC: Logind D-Bus events (`PrepareForSleep`, `Session.Lock`) automatically dismiss the overlay (`LogindEvent.js`). `on`, `off`, `toggle`, `clear`, `style`, `sound` IPC commands exposed.
- Ship: Manifest validated with `omarchy-plugin-validate`, documentation and license added, installed copy updated.
