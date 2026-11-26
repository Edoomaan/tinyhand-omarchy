# Build plan

Ordered vertical slices. Each ends with something that runs in the nested Hyprland harness (`dev/harness`), and gets a commit.
`IDs` refer to the behavior inventory in `docs/research/tinyhand-port.md`.

1. **Skeleton** — manifest (`overlay` + `bar-widget`), one overlay surface per screen, IPC toggle, clicks swallowed, lavender hand at the cursor, system cursor hidden, Esc exits. (B1, B3, B5, C1, A6, E8)
2. **Arm** — 1:1 hand-on-a-stick geometry: grip easing, fingertip on the cursor, rod, shadow, press squash and decay; all 36 hands + laser; fingertip metrics precomputed per PNG. Pure maths in `Arm.js` with node tests. (E1–E9, C4, C5)
3. **Tap sound** — 15 sounds, pool of 4 players, per-pointer mute. (G1–G4)
4. **Ink** — draw after a ≥4 px drag, smoothing, width, Ctrl arrowhead, fade, clear, ink colours. Pure maths in `Ink.js` with node tests. (D1–D9)
5. **Toolbar** — pinned styles, ink tray, sound, exit; auto-reveal rules; hint pill and first-run hint. Reveal rules in `Reveal.js` with tests. (F1–F8, B4)
6. **Pass-through** — Omarchy bar passes clicks; hold Alt = click for real; double-⇧ click-through latch; Hyprland binds gated on the overlay's layer; cursor from Hyprland's socket. Double-tap timing in `DoubleTap.js` with tests. (B9–B14)
7. **Multi-monitor** — draw on the screen under the pointer, clear ink on a screen change. (B19)
8. **Settings + bar widget** — `settings.json` persistence, bar icon (left toggle, right menu), settings panel. (H1–H4, I2–I4, J)
9. **Lifecycle + automation** — off on sleep/lock; IPC commands on/off/toggle/clear/style/sound. (B7, K1)
10. **Ship** — i18n (en, tr), README (credit, keys, manual tests), LICENSE, `omarchy plugin validate`, install, enable, binds.
