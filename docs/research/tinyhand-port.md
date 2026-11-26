# TinyHand → Omarchy plugin: port research

Date: 2026-11-17

**Sources**
- TinyHand: `https://github.com/nilbuild/tinyhand` @ `da98f98d529971297487b0ec6ef07dc549555686` (VERSION `1.1.0`, MIT, (c) 2026 Kamran Ahmed). I read every file under `Sources/TinyHand/` (20 files, 5,894 lines), plus `README.md`, `LICENSE`, `Package.swift`, `Package.resolved`, `scripts/lib.sh` and `scripts/build-app.sh`. I also listed every file under `assets/`. Paths below starting `S/` mean `Sources/TinyHand/`.
- Omarchy `4.0.0.alpha` (`/usr/share/omarchy/version`), written `O/` below. Files used:
  - `O/default/agents/skills/omarchy/plugins.md` (the guide, all of it) and `SKILL.md`
  - `O/shell/plugins/README.md`, `O/shell/plugins/bar/README.md`
  - `O/shell/shell.qml`, `O/shell/services/PluginRegistry.qml`, `O/shell/services/PluginShellApi.qml`, `O/shell/Ui/OverlayWindow.qml`
  - `O/shell/plugins/emojis/*`, `O/bin/omarchy-plugin-validate`
  - `O/default/hypr/helpers.lua`, `O/default/hypr/bindings/*.lua`, `O/default/omarchy/shortcuts`
- Quickshell `0.3.2.r7.g2b4501a`, Hyprland `0.56.2` (`pacman -Q`). Qt types come from the local `/usr/lib/qt6/qml/Quickshell/**/*.qmltypes`, written `QS/` below.
- Live checks, read-only: `hyprctl binds -j` and `hyprctl cursorpos`.
- Not installed locally: `O/docs/omarchy-shell.md` and `O/manual/32-shell-plugins.md`. `O/shell/README.md:5-6` links to both, but neither is on disk, so the manifest schema below comes from the validator and the registry source instead.

---

## 1. Behavior inventory

### A. Global entry points and hotkeys
| ID | Behavior | Source |
|---|---|---|
| A1 | Toggle-pointer hotkey. Default **⌃⌥H** (keyCode `kVK_ANSI_H`, `controlKey\|optionKey`). It is global and calls `overlay.toggle()`. | S/Preferences.swift:10; S/AppDelegate.swift:179-183 |
| A2 | Clear-drawing hotkey. Default **⌃⌥X**. It is global and calls `overlay.clearInk()`. | S/Preferences.swift:11; S/AppDelegate.swift:184-186 |
| A3 | Hotkeys are registered with Carbon `RegisterEventHotKey` (signature `0x54484B59`), so the key is consumed system-wide. | S/HotKeyCenter.swift:40-62 |
| A4 | Both hotkeys can be rebound in Settings. The recorder requires at least one of ⌃⌥⌘ (it shows "Add ⌃, ⌥ or ⌘" otherwise). Esc cancels recording, and so does a click outside the field. The hotkeys are unregistered while recording. | S/SettingsWindow.swift:228-293; S/AppDelegate.swift:114-120 |
| A5 | If a new shortcut fails to register, TinyHand reverts to the old one and shows "<key> is already used by another app. Pick a different shortcut." | S/AppDelegate.swift:152-172; S/SettingsView.swift:1531-1534 |
| A6 | **Esc** is a *global* hotkey with no modifiers, registered only while the pointer is on. It calls `exit()`, which clears the ink and turns the pointer off. One press does this; there is no multi-press logic. | S/OverlayController.swift:539-549, 453, 484, 189-192 |
| A7 | Esc is unregistered (passes to apps) while any popup menu is open, while TinyHand's own menu is open, or while click-through is on. | S/OverlayController.swift:515 |
| A8 | The app is an agent: no Dock icon, no app switcher entry. | S/main.swift:102; scripts/lib.sh:70-71 |
| A9 | Debug CLI flags (render, toolbar, settings, welcome snapshots, `--make-hand`, `--e2e-test`, `--click-test`). These are development aids only. | S/main.swift:4-97 |

### B. Modes, states, transitions
| ID | Behavior | Source |
|---|---|---|
| B1 | State `isActive` (off/on). `toggle()` flips it. | S/OverlayController.swift:44, 391-397 |
| B2 | `activate()` fails without Accessibility trust and opens the Welcome window instead. | S/OverlayController.swift:406-410; S/AppDelegate.swift:55-57 |
| B3 | When turned on, TinyHand: hides the system cursor, puts the overlay on top, starts a 120 Hz tick, installs the event tap, loads the interact key, resets click-through, installs the Shift monitors, places the toolbar on the mouse's screen, shows it, and forces it revealed for 3 s. | S/OverlayController.swift:411-436 |
| B4 | First-run hint, shown once (`firstRunHintShown`): "Click to tap · Drag to draw · Hold ⌥ to click for real · Double-tap ⇧ to click through · Esc to exit". Parts are dropped when their feature is off. It stays 10 s and keeps the toolbar revealed for 10 s. | S/OverlayController.swift:399, 437-452 |
| B5 | When turned off, TinyHand: stops the timer and monitors, disables the tap, turns click-through off, clears the ink, hides the overlay and toolbar, shows the cursor and unregisters Esc. | S/OverlayController.swift:458-488 |
| B6 | Opening Settings, Welcome or "Check for Updates" turns the pointer off first. | S/AppDelegate.swift:213-226 |
| B7 | The pointer turns off automatically on: screen lock, screensaver start, display sleep, system sleep, session switch, and any click while `CGSSessionScreenIsLocked`. | S/OverlayController.swift:194-211, 323-329; S/InputTap.swift:189-192, 212-218 |
| B8 | On a Space change, if the overlay is not on the active Space, it is shown again and the toolbar is re-placed. | S/OverlayController.swift:212-231 |
| B9 | **Click-through (latched)** toggles on a double tap of Shift alone. While latched, every click reaches apps and the hand stays visible. The Esc hotkey is released. A hint shows for 1.5 s ("Clicks go through · the hand stays / Double-tap ⇧ to tap again" or "Taps · clicks don't reach apps / Double-tap ⇧ to click through"). The menu bar icon turns orange. Turning it on ends any stroke in progress. | S/OverlayController.swift:304-321, 233-235; S/AppDelegate.swift:253-256; S/InputTap.swift:33-37 |
| B10 | Double-tap detection: Shift is pressed with no other modifier and released within **0.3 s**, with no key or click between press and release (checked with HID event counters). A second such tap starting within **0.35 s** of the first one's release counts as the double tap. The feature is controlled by `doubleShiftClickThrough` (default true); turning it off cancels an active latch. | S/OverlayController.swift:52-53, 261-302, 140-142; S/Preferences.swift:132-135 |
| B11 | **Interact key (hold)**. Options: Option (default), Command, Control, Off. While it is held, mouse down, up and drag reach the app; the modifier flag is stripped from the forwarded event, and the hand still plays its press animation. After release, the hidden cursor is re-asserted for 2 s. | S/Preferences.swift:14-43, 137-140; S/InputTap.swift:150-168; S/OverlayController.swift:95-105 |
| B12 | `interactKeepsHand` (default false). While the interact key is held, or the pointer is over the menu bar or an open menu, the real cursor returns and the hand or laser is hidden. Set to true, the hand stays. | S/OverlayController.swift:509-528; S/ArmView.swift:42-50; S/SettingsView.swift:438-449 |
| B13 | Pass-through zones, where clicks reach the real UI: the menu bar rect (height `max(24, frame.maxY−visibleFrame.maxY)`), every open popup menu (window list at the popUpMenu level, rescanned every 0.05 s when a menu is likely and 0.25 s otherwise), the TinyHand status item, and the toolbar while it is revealed. | S/OverlayController.swift:490-537, 551-570, 36-37; S/AppDelegate.swift:43-48; S/InputTap.swift:170-185 |
| B14 | A press in the menu bar marks "menu opening" for 1 s, which keeps menu-area clicks passing through. | S/OverlayController.swift:106-115, 497-508 |
| B15 | While TinyHand's own status menu is open, input interception is suspended. | S/AppDelegate.swift:136-142; S/OverlayController.swift:178-187 |
| B16 | Over the Dock (read through Accessibility, refreshed every 1 s, padded 8 pt) the overlay window catches the mouse so the Dock doesn't magnify or reveal the cursor. | S/OverlayController.swift:728-732; S/CursorHider.swift:86-139 |
| B17 | If permission is granted while the pointer is on, the tap is installed within 1 s and the toolbar's permission button disappears. | S/OverlayController.swift:577-588 |
| B18 | Tick rate: 120 Hz while busy, 20 Hz after 0.5 s without motion. Global and local monitors wake it on motion, click or modifier change. This is a performance detail, not visible behavior. | S/OverlayController.swift:33-35, 634-701 |
| B19 | **Multi-monitor**: one overlay that follows the screen under the mouse on every tick. On a screen change it ends the current stroke, **clears all ink**, moves the window, re-places the toolbar, and reveals the toolbar for 1.5 s. | S/OverlayController.swift:627-632, 703-720 |

### C. Tap (click)
| ID | Behavior | Source |
|---|---|---|
| C1 | Left, right and other mouse-button down and up events are **swallowed** (the tap returns `nil`). No app receives them. | S/InputTap.swift:187-200, 56-65 |
| C2 | On press: `press()` (pressAmount=1), `held=true`, the tap sound plays, the hint is hidden, and the down point is recorded. | S/OverlayController.swift:73-85 |
| C3 | Release comes from the mouse-up callback, or from polling the HID button state as a backstop. It sets `held=false` and ends the stroke. | S/OverlayController.swift:91-94, 331-340, 746-753 |
| C4 | Press visuals: the hand gets 6 % shorter, the lift drops by 80 %, shadow radius grows by 5·press and shadow opacity by 0.02·press. The laser radius grows ×(1+0.2·press) and its glow radius becomes r·(2.2+1.0·press). | S/ArmView.swift:147, 179-180, 195-197, 201, 215 |
| C5 | Press decay: on every tick while not held, `pressAmount += (0−pressAmount)·0.18` (frame-rate dependent, at 120 Hz). | S/ArmView.swift:129-131 |
| C6 | Scroll-wheel events are **not** intercepted, so scrolling reaches the app under the pointer. The E2E test checks this. | S/InputTap.swift:56-65; S/E2ETest.swift:87-93 |

### D. Drawing
| ID | Behavior | Source |
|---|---|---|
| D1 | A stroke starts only after a left-button drag of **≥4 pt** from the press point. Right and other drags never draw. | S/OverlayController.swift:364-377; S/InputTap.swift:202-204 |
| D2 | During a drag, apps receive the event rewritten as `mouseMoved` (hover continues underneath). | S/InputTap.swift:201-206 |
| D3 | Stroke width is `max(3, screenHeight × 0.0055)` pt. | S/ArmView.swift:23 |
| D4 | Stroke look: round cap and join, no fill, shadow black at 0.18 opacity, radius 1.5, offset (1, −1.5). | S/Ink.swift:36-48 |
| D5 | Points closer than 1.5 pt are dropped. The path is a quadratic smoothing through midpoints and ends with a line to the last point. | S/Ink.swift:53-62, 128-144 |
| D6 | **Arrowhead** while ⌘ is held. It is checked live on every drag event and modifier change, so it can toggle mid-stroke. Head length is `min(max(14, width×3.2), 0.8×segment)`, aimed from the last point at least 1.2×size back, with arms ±π/7. | S/OverlayController.swift:268-271, 375, 379-381; S/Ink.swift:19-25, 120, 146-165 |
| D7 | **Fade**: after the stroke ends, wait `max(0.5, fadeSeconds)`, then fade opacity 1→0 over **0.6 s ease-in**, then remove. `fadeSeconds` defaults to **3**; the choices are 3, 6, 10 s or 0 = "Keep until cleared". | S/Ink.swift:5, 16-17, 64-76, 99-113; S/Preferences.swift:107-110; S/SettingsView.swift:975-980 |
| D8 | Clear removes every stroke at once. Triggers: hotkey, menu, URL, Esc, toolbar ×, deactivate, screen change. | S/Ink.swift:78-82; S/OverlayController.swift:360-362, 477, 716 |
| D9 | Ink colour is `inkChoice` (default `match` = the pointer's own ink). Palette: red `(1,0.16,0.12)`, orange `#FF8A00`, yellow `#FFCC00`, green `#30C25A`, blue `#0A84FF`, purple `#8754F2`, white `#FFFFFF`, black `#1D1D21`. | S/Preferences.swift:45-79; S/Ink.swift:7-8 |
| D10 | Strokes are rasterised when they end (implementation detail only). | S/Ink.swift:84-97 |

### E. Pointer rendering ("hand on a stick")
| ID | Behavior | Source |
|---|---|---|
| E1 | The grip sits below the screen at `y=−0.12·H`. Its x target is `clamp(cursor.x+0.30·W, 0.15·W, 1.05·W)`, eased by a factor of **0.08** per tick, so the stick lags and swings. | S/ArmView.swift:15-19, 121-127 |
| E2 | Hand length = `pointerSize·H`, default **0.13**, range **0.08–0.20** (Settings slider). | S/Preferences.swift:95-100; S/ArmView.swift:147; S/SettingsView.swift:955-964 |
| E3 | Rotation is computed so the fingertip lands exactly on the cursor. The rod is at least 0.05·H; the rod and hand are cut from one PNG using `contentsRect`. | S/ArmView.swift:101-107, 142-157, 183-190 |
| E4 | Shadow: lift `0.06·H·(1−0.8·press)`, offset `(0.6·lift, −lift)` rotated with the arm, opacity `0.26+0.02·press`, radius `max(1, 0.35·lift)+5·press`. `showShadow` defaults to true. | S/ArmView.swift:159-181, 195-197; S/Preferences.swift:102-105 |
| E5 | Fingertip, wrist, rod end and rod x are measured automatically from each PNG's alpha rows (alpha>128; wrist <0.35×max width; handle >1.8×rod width). | S/PointerStyle.swift:252-323 |
| E6 | **Laser dot**: radius `max(4, H·0.0038·size/0.13)`. Fill and glow are red `(1,0.16,0.12)`, shadow opacity 1; core radius 0.45r in `(1,0.86,0.82,0.95)`. It sits exactly on the cursor, with no stick. | S/ArmView.swift:74-79, 199-217 |
| E7 | An unknown or missing hand asset falls back to the laser. | S/ArmView.swift:92-98 |
| E8 | The system cursor is hidden while the pointer is on. Hiding is re-asserted when the cursor seed changes, every 0.05 s for the first 1 s, every 0.03 s over the Dock, and immediately when urgent; otherwise every 1 s. It uses the private CGS "SetsCursorInBackground". | S/CursorHider.swift:6-83; S/OverlayController.swift:733-736 |
| E9 | There are 36 built-in hands (id, title, ink), plus custom hands, plus `laser`. The default style is `lavender`. Legacy ids are migrated: `dot`→laser, `sunny`→coral. | S/PointerStyle.swift:17-75, 111-125 |

### F. Toolbar (shown while the pointer is on)
| ID | Behavior | Source |
|---|---|---|
| F1 | Placement: horizontally centred on the mouse's screen, 14 pt above the bottom of `visibleFrame`. | S/Toolbar.swift:376-380 |
| F2 | Contents, in order: the pinned style buttons (default `lavender, glove, coral, plush, robot, laser`, max **8**, plus the current style if it isn't pinned), a divider, the ink button, the sound button, ✕ "Exit (Esc)", and the orange "Allow clicks & drawing" button only while permission is missing. | S/Toolbar.swift:89-123, 208-233; S/PointerStyle.swift:75; S/Preferences.swift:157-169 |
| F3 | Metrics: buttons 40×40, radius 10, the selected one with a white 0.18 background. Stack spacing 6, insets 8/10. Dark glass background at radius 16, with a `white 0.07 @0.62` tint and a `white @0.12` 1 px border. | S/Toolbar.swift:52-54, 360-364, 419-443; S/AppKitHelpers.swift:11-33 |
| F4 | Auto-reveal: shown if permission is missing, or if `showToolbar` (default true) **and** not drawing **and** (the mouse is in the toolbar frame grown ±80 px in x, +90 px up and 10 px at top and bottom, **or** the reveal timer is running: 3 s on activation, 10 s on the first-run hint, 1.5 s on a screen change). Fade **in 0.15 s, out 0.35 s**. A hidden toolbar ignores the mouse. | S/OverlayController.swift:490-495; S/Toolbar.swift:395-408 |
| F5 | Ink tray: 9 swatches (`match` drawn as a 6-colour rainbow), each 30×30. The tray appears 8 pt above the ink button and fades over **0.12 s**. Picking a swatch sets `inkChoice` and closes the tray. The tray also closes when the toolbar hides. The ink button shows the current colour; it can be hidden (`showInkButton`, default true). | S/Toolbar.swift:133-200, 453-484; S/Preferences.swift:152-155 |
| F6 | Sound button: `speaker.wave.2.fill` / `speaker.slash.fill`, tint white 0.85 / 0.45. Tooltip: "Tap sound on — click to mute" or "Tap sound off — click to unmute". | S/Toolbar.swift:235-242 |
| F7 | Hint pill: 12 pt above the toolbar, fades in over 0.2 s and out over 0.3 s, ignores the mouse. Keys are 12.5 pt semibold white; the text is white at 0.7. | S/Toolbar.swift:280-351 |
| F8 | Picking a style calls `setStyle`, persists it (`pointerStyle`), updates the highlight, refreshes the ink colour and syncs the sound state, which depends on hand or laser. | S/OverlayController.swift:163-174 |

### G. Sound
| ID | Behavior | Source |
|---|---|---|
| G1 | 15 sounds: thock (default), click, tock, clack, typewriter, snap, wood, pop, boop, blip, coin, pew, squeak, quack, chirp. Each is `tap_<id>.wav`. | S/TapSound.swift:4-26, 186-205; S/Preferences.swift:117-120 |
| G2 | A sound plays on **every mouse-down** that is intercepted. Interact-key and pass-through clicks are silent. | S/OverlayController.swift:79; S/InputTap.swift:161-200 |
| G3 | The mute state is separate for hands (`sound.hands`, default **on**) and the laser (`sound.laser`, default **off**). The toolbar, menu and URL toggle the current pointer's setting. | S/Preferences.swift:112-125; S/OverlayController.swift:151-160 |
| G4 | No volume setting: it plays at system output volume. 4 player nodes are used round-robin, so rapid taps overlap. | S/TapSound.swift:33, 85-99, 122-129 |
| G5 | The audio engine is warmed on activation, stops after 30 s idle, and is rebuilt if a buffer isn't rendered within duration+1 s. | S/OverlayController.swift:413; S/TapSound.swift:100-110, 177-184 |
| G6 | Settings › Sound shows an "Off" tile plus one tile per sound; clicking a tile selects and previews it. "Laser dot taps too" is disabled when sound is off. | S/SettingsView.swift:1009-1051 |

### H. Menu bar icon
| ID | Behavior | Source |
|---|---|---|
| H1 | Icon `menubar_on` / `menubar_off` at 18×18, template image. If missing, falls back to the SF symbol `hand.point.up.left(.fill)`. | S/AppDelegate.swift:245-252 |
| H2 | **Left click toggles the pointer.** Right click or ⌃-click opens the menu. | S/AppDelegate.swift:76-81, 123-134 |
| H3 | Tooltips: "TinyHand is on — click to turn off, right-click for the menu" / "TinyHand — click to turn on, …". In click-through, the icon is tinted `systemOrange` with the tooltip "TinyHand clicks go through — double-tap ⇧ to tap again, click to turn off". | S/AppDelegate.swift:253-260 |
| H4 | Menu items: "Allow Accessibility…" (hidden when trusted) · "Turn Pointer On/Off ⌃⌥H" · "Clear Drawing ⌃⌥X" · "Tap Sound" (with checkmark) · — · "Settings…" ⌘, · "Check for Updates…" (only with Sparkle) · — · "Quit TinyHand" ⌘Q. The labels show the current shortcut. | S/AppDelegate.swift:83-104, 144-150 |
| H5 | The status item's frame is a pass-through zone, so it stays clickable while the pointer is on. | S/AppDelegate.swift:43-48 |

### I. Settings window (SwiftUI, 780×560, min 760×540)
| ID | Behavior | Source |
|---|---|---|
| I1 | Sections: General, Pointers, Appearance, Drawing, Sound, About. | S/SettingsView.swift:5-42; S/SettingsWindow.swift:67-80 |
| I2 | General: the 2 shortcuts, interact-key picker, "While holding" picker (show cursor / keep hand), double-⇧ toggle, open at login, auto-check updates. | S/SettingsView.swift:399-471 |
| I3 | Pointers: an editor for the pinned toolbar (drag to reorder, drag out to remove, + picker grid, at least 1 and at most 8, Reset) and toggles for "Show the toolbar" and "Ink button". | S/SettingsView.swift:473-630, 213-309 |
| I4 | Appearance: size slider (0.08–0.20) and shadow toggle. Drawing: ink swatches and fade picker. About: version, links, and "Reset all settings…" behind a confirm alert. | S/SettingsView.swift:950-1007, 1119-1151, 241-256; S/Preferences.swift:187-194 |
| I5 | **Custom hands**: describe the hand, open ChatGPT with a prompt or copy the prompt, then drop or choose a PNG. The PNG is validated: transparent edges ≤2 %, a single blob ≥97 %, aspect 1.05–2.8, ≥50 % of the height, a single fingertip ≤40 %, a wrist ≥20 %, soft-alpha ≤8 %. It is composed onto a 1024×1536 canvas with a gradient rod, and an ink colour is derived from it. Saved to `~/Library/Application Support/TinyHand/Hands/<custom-xxxxxxxx>.png` and `hands.json`. The name is limited to 16 chars; it can be deleted, and it is auto-pinned if there is room. | S/HandMaker.swift:1-394; S/SettingsView.swift:83-174, 1327-1433 |

### J. Persistence (UserDefaults)
| Key | Default | Source |
|---|---|---|
| `shortcut.toggle` / `shortcut.clear` | ⌃⌥H / ⌃⌥X, stored as `{keyCode, modifiers, display}` | S/Preferences.swift:85-93, 201-211 |
| `pointerSize` | 0.13 | :97-100 |
| `showShadow` | true | :102-105 |
| `fadeSeconds` | 3 | :107-110 |
| `sound.hands` / `sound.laser` | true / false | :112-125 |
| `tapSound` | thock | :117-120 |
| `interactKey` / `interactKeepsHand` | option / false | :127-140 |
| `doubleShiftClickThrough` | true | :132-135 |
| `inkChoice` | match | :142-145 |
| `showToolbar` / `showInkButton` | true / true | :147-155 |
| `pinnedStyles` | lavender, glove, coral, plush, robot, laser (deduped; empty means the default) | :159-169 |
| `pointerStyle` | lavender | S/PointerStyle.swift:111-125 |
| `welcomeShown`, `firstRunHintShown`, `loginItemSetUp` | one-shot flags | S/WelcomeWindow.swift:23; S/OverlayController.swift:399; S/AppDelegate.swift:234 |

Every change posts `Preferences.changed`, and the overlay, toolbar and settings re-read it live (S/Preferences.swift:196-199; S/OverlayController.swift:137-148; S/Toolbar.swift:127-130; S/ArmView.swift:82-85). "Reset all" clears every key except login and accessibility (S/Preferences.swift:187-194).

### K. Automation, lifecycle, update
| ID | Behavior | Source |
|---|---|---|
| K1 | URL scheme `tinyhand://`. Commands: `on`, `off`, `toggle`, `clear`, `style/<id>` (picks the style **and turns the pointer on**), and `sound/on\|off\|toggle` (no argument means toggle). Unknown commands are logged. | S/Automation.swift:18-63; scripts/lib.sh:72-82 |
| K2 | URLs that arrive before launch finishes are queued, then run in order. | S/AppDelegate.swift:22-28, 65-68 |
| K3 | `~/Library/Application Support/TinyHand/state.json` holds `{pid, active, style, soundOn, styles[{id,name,type: hand\|custom\|laser}]}` (pretty, sorted keys, atomic write). It is rewritten on launch, on activation and sound changes, and on custom-hand changes, and deleted on quit. | S/Automation.swift:6-7, 65-83; S/AppDelegate.swift:35-42, 65, 71-74 |
| K4 | Launch at login (`SMAppService.mainApp`) is enabled automatically on first run, but only when running from `/Applications` or `~/Applications`. It can be toggled in Settings. | S/AppDelegate.swift:233-243; S/Preferences.swift:171-185 |
| K5 | Self-update: Sparkle 2.10.0. The feed is `github.com/nilbuild/tinyhand/releases/latest/download/appcast.xml`, signed with an EdDSA key, with `SUEnableAutomaticChecks=true`. There is a gentle reminders delegate, a menu item and a settings toggle. | Package.swift; S/Updater.swift:1-33; scripts/lib.sh:6-8, 24-31 |
| K6 | Welcome card (340×300, borderless, normal level). Shown on first launch or while untrusted. When untrusted it reads "Allow Accessibility" / "Open Settings", which prompts and opens the Privacy pane, and shows a "remove and re-add" tip after 10 s. When trusted it reads "You're all set" / "Press ⌃⌥H any time" / "Start", which activates the pointer. It refreshes every 0.5 s and Esc closes it. | S/WelcomeWindow.swift:1-140; S/AppDelegate.swift:58-63 |
| K7 | Quit turns the pointer off and deletes `state.json`. A log is kept at `~/Library/Logs/TinyHand.log`. | S/AppDelegate.swift:71-74, 228-231; S/Log.swift:1-25 |

### L. Animation and timing constants (summary)
- Tick rate: 120 Hz busy, 20 Hz idle, idle after 0.5 s (S/OverlayController.swift:33-35).
- Grip follow 0.08 per tick; press decay 0.18 per tick (S/ArmView.swift:18, 130).
- Ink fade: delay ≥0.5 s (default 3), 0.6 s ease-in (S/Ink.swift:16-17, 105).
- Toolbar fades in over 0.15 s and out over 0.35 s; tray over 0.12 s; hint fades in over 0.2 s and out over 0.3 s (S/Toolbar.swift:164-170, 321, 346, 405).
- Toolbar reveal windows: 3 s, 10 s, 1.5 s. The click-through hint shows for 1.5 s. Double-⇧ windows: 0.3 s and 0.35 s. Cursor guard: 2 s (S/OverlayController.swift:52-53, 102, 316, 436, 448, 714).

---

## 2. Assets

| Path | Count | Format | Use |
|---|---|---|---|
| `assets/hand_<id>.png` (astro, black, blue, cactus, choco, chrome, cloud, cookie, coral, fuzzy, glass, glove, grass, holo, jelly, knit, lava, lavender, leaf, lemon, lowpoly, marble, mech, mint, monster, neon, pastel, pink, pixel, plush, robot, skeleton, space, terrazzo, water, wood) | 36 | PNG 1024×1536 RGBA. Each image contains both the hand and its rod. | Pointer images and toolbar thumbnails (128 px crop) (S/PointerStyle.swift:213-236, 325-342) |
| `assets/sounds/tap_<id>.wav` | 15 | 44.1 kHz mono 16-bit, 50–180 ms (blip 70, boop 140, chirp 90, clack 80, click 50, coin 180, pew 120, pop 90, quack 140, snap 60, squeak 130, thock 110, tock 90, typewriter 100, wood 120) | Tap sound. Synthesised by `scripts/make-sounds.py` (numpy). |
| `assets/menubar_{on,off}{,@2x,@3x}.png` | 6 | 18 / 36 / 54 px RGBA | Status icon |
| `assets/icon/{hand-cursor,menubar-on,menubar-off}.svg` | 3 | SVG | Sources for the icons (`scripts/make-icons.py`) |
| `assets/AppIcon.icns`, `assets/Assets.car`, `assets/AppIcon.icon/{icon.json,Assets/back.svg,Assets/front.svg}` | 5 | macOS icon formats | App icon |
| `assets/youtube/thumb.{html,jpg,png}`, `docs/**` (website: 36 `hands/*.png` thumbnails, `tap.wav`, art, favicon, `pointer.js`), `.github/{banner.jpg,logo.png}` | – | – | Not runtime |

The bundle copies `hand_*.png`, `tap_*.wav`, `AppIcon.icns`, `Assets.car` and `menubar_*.png` (scripts/lib.sh:36-38). Everything is MIT-licensed (LICENSE), so the assets can be reused if the copyright notice is kept.

---

## 3. macOS → Omarchy / Hyprland / Wayland mapping

| # | macOS mechanism (Swift source) | Omarchy / Quickshell equivalent (source) | Label | Reason |
|---|---|---|---|---|
| 1 | Borderless clear `NSWindow`, level `screenSaver+2`, `canJoinAllSpaces/stationary/fullScreenAuxiliary` (S/OverlayController.swift:61-68) | `OverlayWindow` = `PanelWindow` on `WlrLayer.Overlay`, all 4 anchors, `ExclusionMode.Ignore` (O/shell/Ui/OverlayWindow.qml:10-81) | 1:1 | An Overlay-layer surface sits above fullscreen windows and stays on its output across workspace switches. |
| 2 | Toolbar, ink tray and hint as `NSPanel`s at `screenSaver+1` (S/Toolbar.swift:37-47, 64-74, 282-290) | Items inside the same overlay surface (or a second `PanelWindow`) (QS/_Window/quickshell-window.qmltypes:138) | 1:1 | Same stacking and positioning. |
| 3 | Global click swallowing with a `CGEventTap` that returns `nil` (S/InputTap.swift:51-102, 187-200) | Full-screen input region plus `MouseArea` (O/shell/plugins/emojis/Emojis.qml:171-174) | approximate | Clicks are swallowed 1:1, but **drags are no longer forwarded as hover** (D2) and **scroll no longer reaches apps** (C6), because Wayland sends all pointer input to the surface under the pointer. |
| 4 | Pass-through rects for the menu bar, status item and toolbar (S/OverlayController.swift:530-536) | `PanelWindow.mask: Region` with a subtracted rect for the Omarchy bar (QS/_Window/quickshell-window.qmltypes:367; QS/quickshell-core.qmltypes:646) | approximate | The bar rect can be masked out. Bar position and size come from shell.json (`bar.position`, O/shell/plugins/bar/README.md:27, 176). |
| 5 | Open-menu detection with `CGWindowListCopyWindowInfo` at popUpMenu level (S/OverlayController.swift:556-570) | none | not possible | Wayland has no global list of other clients' popups; `hyprctl layers` shows only layer surfaces. |
| 6 | Hold-modifier "click for real": modifier read from HID state, event passed with the flag stripped (S/InputTap.swift:150-168) | Empty `mask` while the key is held. The key comes from a Hyprland bind on the modifier with a release bind, or from keyboard focus (O/default/hypr/helpers.lua:138-152, 222) | approximate | A surface can't forward one click it already received. Without keyboard focus a layer surface doesn't get modifier state. The modifier flag can't be stripped. |
| 7 | Double-tap ⇧ latch using HID input counters (S/OverlayController.swift:261-302) | Hyprland press and release binds on Shift → IPC; timing done in QML | approximate | The 0.3 s / 0.35 s timing can be reproduced. The "no other key between" check (`CGEventSource.counterForEventType`) has no Wayland equivalent. |
| 8 | ⌘ while dragging adds an arrowhead (S/OverlayController.swift:379-381) | Read the modifier from `MouseEvent.modifiers` (needs keyboard focus) | approximate | ⌘ maps to SUPER, but `SUPER + mouse:272` is Hyprland's "Move window" (O/default/hypr/bindings/tiling.lua:83; live `hyprctl binds`), which takes over the drag. A different modifier is needed. |
| 9 | Carbon `RegisterEventHotKey` for ⌃⌥H / ⌃⌥X (S/HotKeyCenter.swift:40-62) | `o.bind(keys, desc, { panel = "<id>" })` in `~/.config/hypr/bindings.lua`, which runs `omarchy-shell shell toggle <id>` (O/default/hypr/helpers.lua:99-100, 138-152). Clear: `omarchy-shell shell call <id> clear ""` (O/shell/shell.qml:1933-1935) | approximate | The behavior is the same, but the user must add the binds; a plugin can't register them itself. `CTRL+ALT+H` and `CTRL+ALT+X` are currently free (`hyprctl binds -j`). |
| 10 | In-app shortcut recorder and conflict detection (S/SettingsWindow.swift:87-327; S/AppDelegate.swift:152-172) | none | not possible | Keys live in the user's Hyprland config, which the plugin must not edit (O/default/agents/skills/omarchy/SKILL.md:256-263). |
| 11 | Esc as a global hotkey only while on (S/OverlayController.swift:539-549) | `Keys.onPressed` on a focused item, with `WlrKeyboardFocus.Exclusive` (O/shell/Ui/OverlayWindow.qml:16, 81; O/shell/plugins/emojis/Emojis.qml:190-198) | approximate | Exclusive focus takes **all** typing away from apps while the pointer is on; TinyHand only takes Esc. The alternative is a temporary Hyprland Escape bind (`hyprctl eval`, as in O/shell/services/BackgroundIntro.qml:34). |
| 12 | `NSStatusItem`: left click toggles, right click opens the menu (S/AppDelegate.swift:76-134) | `bar-widget` kind with `BarIconButton` (O/shell/plugins/bar/README.md:85, 189); the menu becomes a `PopupCard` or `KeyboardPanel` (O/default/agents/skills/omarchy/plugins.md:41) | approximate | There is no native menu. The click semantics can match: left = toggle, right = popup. |
| 13 | Status icon tint and tooltip (S/AppDelegate.swift:253-260) | Theme colours plus `bar.showTooltip` (O/shell/plugins/bar/README.md:172-178) | 1:1 | Both have tooltip and colour APIs. |
| 14 | Cursor hide with `CGDisplayHideCursor` plus private CGS calls and re-assert (S/CursorHider.swift:6-83) | `cursorShape: Qt.BlankCursor` on the overlay's `MouseArea`. The Wayland client sets a null cursor while it has pointer focus (https://doc.qt.io/qt-6/qml-qtquick-mousearea.html#cursorShape-prop) | 1:1 | The overlay covers the screen, so the cursor stays hidden without the macOS workarounds. |
| 15 | Mouse position from polling `NSEvent.mouseLocation` (S/OverlayController.swift:703-740) | `MouseArea { hoverEnabled: true }` position events. While the mask is empty (rows 6 and 7), `hyprctl cursorpos` instead (tested: returns `x, y`) | 1:1 | Event-driven inside the overlay. While masked, polling a subprocess adds latency. |
| 16 | Multi-monitor: one window follows the mouse's screen (S/OverlayController.swift:627-632, 703-720) | `OverlayWindow` locks to the focused screen when opened (O/shell/Ui/OverlayWindow.qml:44-58). Options: `Variants` over `Quickshell.screens` (QS/quickshell-core.qmltypes:943, 1686) or retarget on `Hyprland.focusedMonitor` (QS/Hyprland/_Ipc/quickshell-hyprland-ipc.qmltypes:84) | approximate | Following the pointer across outputs needs either a surface per screen or a retarget. The stock OverlayWindow does neither. |
| 17 | Space-change re-show (S/OverlayController.swift:212-231) | Layer surfaces are per output, not per workspace | 1:1 | Nothing to do. |
| 18 | Dock handling: AX query plus capturing the mouse over the Dock (S/CursorHider.swift:86-139; S/OverlayController.swift:728-732) | The Overlay layer is above the Omarchy dock layer surface (O/shell/plugins/dock/Dock.qml) | 1:1 | The dock can't react under the overlay; no workaround needed. |
| 19 | `AVAudioEngine` with 4 round-robin players (S/TapSound.swift:32-184) | `QtMultimedia` `SoundEffect` × 4 (/usr/lib/qt6/qml/QtMultimedia/plugins.qmltypes:530-533) | 1:1 | Low-latency WAV playback with overlap. Omarchy ships no sound helper of its own. |
| 20 | `UserDefaults` plus `Preferences.changed` notifications (S/Preferences.swift:81-212) | Plugin settings stored inline in `shell.json` through `shell.updateEntryInline(id, settings)` (O/shell/services/PluginShellApi.qml:62; O/shell/shell.qml:1102-1144), or a plugin-owned JSON file via `FileView`; QML bindings for live updates | 1:1 | Both give key-value persistence with live reload. |
| 21 | `tinyhand://` URL scheme (S/Automation.swift:18-63; scripts/lib.sh:72-82) | `omarchy-shell shell summon/hide/toggle <id>` and `omarchy-shell shell call <id> <method> <arg>` → the plugin's `open()`, `close()` or a named method (O/shell/shell.qml:1910-1935, 1181-1251, 1291-1303) | approximate | The same command set over IPC. Browser and launcher `open tinyhand://` links would need an `x-scheme-handler` `.desktop` file outside the plugin. |
| 22 | `state.json` in Application Support, deleted on quit (S/Automation.swift:65-83; S/AppDelegate.swift:71-74) | `FileView` write to e.g. `$XDG_STATE_HOME/tinyhand/state.json`; delete in `Component.onDestruction` | approximate | The shell rarely quits, so "deleted on quit" rarely happens. `pid` would be the shell's pid. |
| 23 | Launch at login via `SMAppService` (S/Preferences.swift:171-185; S/AppDelegate.swift:233-243) | An enabled plugin loads with `omarchy-shell` at login; on/off = `omarchy plugin enable/disable` (O/shell/services/PluginRegistry.qml:148-164, 497-) | approximate | The plugin always "launches" while enabled; there is no separate toggle inside it. |
| 24 | Sparkle self-update (S/Updater.swift; Package.swift) | `omarchy plugin update <id>` (git) (`omarchy plugin --help`) | approximate | Updates are manual or user-triggered; there is no in-app check or auto-check toggle. |
| 25 | Accessibility permission, Welcome card and permission button (S/WelcomeWindow.swift; S/Toolbar.swift:104-121; S/OverlayController.swift:406-410) | none | not possible | Layer-shell input needs no permission, so there is nothing to port. The "You're all set / Start" state could become a first-run hint. |
| 26 | Turn off on lock, sleep or screensaver (S/OverlayController.swift:194-211) | The session lock surface already covers overlays. Sleep could come from `Process` on `gdbus monitor` for logind `PrepareForSleep`. First-party services are hidden from third-party plugins (O/shell/services/PluginRegistry.qml:104-116) | approximate | Detection needs a custom watcher; the lock covers the overlay visually. |
| 27 | `ProcessInfo.beginActivity(.latencyCritical)` (S/OverlayController.swift:422-423) | none | not possible | No equivalent, and none needed. |
| 28 | `CALayer` arm rendering (rotation, `contentsRect`, shadows) (S/ArmView.swift) | QML `Image` with `sourceClipRect` and `Rotation`, plus `MultiEffect` shadows (/usr/lib/qt6/qml/QtQuick/Effects) | 1:1 | Same maths, different scene graph. |
| 29 | `CAShapeLayer` ink with a quadratic path and a fade `CABasicAnimation` (S/Ink.swift) | `QtQuick.Shapes` `ShapePath` / `PathQuad` or `Canvas`, with `NumberAnimation` on opacity (/usr/lib/qt6/qml/QtQuick/Shapes) | 1:1 | The path maths ports directly. |
| 30 | `NSVisualEffectView` dark glass (S/AppKitHelpers.swift:11-33) | Theme tokens (`Commons.Color.menu.*`, O/shell/Commons/Color.qml:100-107) plus `BorderSurface`; blur only by namespace layer rule (O/default/hypr/toggles/window-glassy.lua:11) | approximate | A plugin namespace isn't in the blur rule list, and the guide expects theme colours (§4). |
| 31 | SwiftUI Settings window (S/SettingsView.swift, S/SettingsWindow.swift) | A plugin panel (`KeyboardPanel` / `PopupCard`, from the `qs.Ui` qmldir), or `shell.json` keys only | approximate | The UI must be rebuilt with Omarchy controls. There are no Apple popovers or alerts. |
| 32 | `NSOpenPanel`, PNG drag-drop and ChatGPT URL for custom hands (S/SettingsView.swift:103-135, 1389-1400) | There is no file dialog in Quickshell. Options: a path field, the `omarchy.image-picker` summon (O/shell/plugins/README.md:61-71), or `Qt.openUrlExternally` | approximate | The flow can be reproduced with a different picker. |
| 33 | Log file `~/Library/Logs/TinyHand.log` (S/Log.swift) | `console.log` (shell journal) | 1:1 | Diagnostics only. |

**Label counts: 1:1 = 12, approximate = 17, not possible = 4** (33 rows).

---

## 4. Plugin guide constraints and conflicts with a naive port

1. **Motion rules vs TinyHand timings** (O/default/agents/skills/omarchy/plugins.md:43-50). Every duration must go through `Style.duration(ms)`, which returns 0 when animations are off. Ease-in is not allowed, transitions must stay under 300 ms, and exits must be shorter than entrances. Things a single keystroke toggles many times a day should not animate at all. These TinyHand values conflict:
   - Ink fade: 0.6 s, ease-in (S/Ink.swift:17, 105).
   - Toolbar: in 0.15 s, out 0.35 s, so the exit is longer than the entrance (S/Toolbar.swift:405).
   - Hint: in 0.2 s, out 0.3 s (S/Toolbar.swift:321, 346).
   - Overlay on/off is a hotkey toggle, so under the guide it should not animate.
   - Open: the ink fade arguably counts as "constant motion" and not a UI transition, so the user should decide.
2. **Translations** (plugins.md:67-96). All plugin strings (toolbar tooltips, hints, menu labels) must live in `i18n/*.json` and be read with `Commons.Translations`. Hint text like "Click · to tap" must be whole strings with `%1` placeholders. Positions set by explicit `x` must follow `LayoutMirroring` (RTL). The toolbar order is a design choice.
3. **Plain text** (plugins.md:20-37). `textFormat: Text.PlainText` is required on every `Text`. Custom hand names (I5) are user-supplied, so they count as untrusted input.
4. **Theming**. Use `qs.Ui` components and `Commons.Color` tokens (Emojis.qml:27-33). TinyHand's fixed dark glass (S/AppKitHelpers.swift:20-23) and its orange accents would not follow the Omarchy theme. The pointer images and ink colours are content, not chrome, so they can stay as they are.
5. **Bar icon** (O/shell/plugins/bar/README.md:85, 93). The bar icon must be a `BarIconButton` or `WidgetButton`, using the shared icon size of 12 px on a 16 px canvas. This replaces the 18×18 `menubar_*.png` template images.
6. **Manifest** (O/bin/omarchy-plugin-validate:41-116; O/shell/services/PluginRegistry.qml:43-90):
   - `schemaVersion` must be the number 1. Required fields: `id`, `name`, `version`, `kinds`, `entryPoints`.
   - The id may not use the `omarchy.*` namespace.
   - `overlay` needs `entryPoints.overlay` and `bar-widget` needs `entryPoints.barWidget`.
   - No symlinks are allowed.
   - `barWidget.defaultSection` must be one of left, centerBegin, center, centerEnd, tray or right.
7. **Enabling**. A third-party overlay is enabled only if its id appears in `shell.json` (in `plugins[]` or the bar layout). Otherwise `summon` refuses with "plugin not enabled" (O/shell/services/PluginRegistry.qml:143-164; O/shell/shell.qml:1189-1194).
8. **`keepLoaded` and reload**. With `keepLoaded: true` the overlay Loader stays active between summons (O/shell/shell.qml:1402). On a file change, `reloadPlugins()` runs `unloadPanels()`, which clears `panelEntryModel` (destroying keepLoaded loaders too), then `Qt.clearComponentCache()` and a rescan (O/shell/shell.qml:1291-1297, 1517-1535). The earlier attempt saw stale QML until `omarchy restart shell`. The source suggests the cache clear may run before the destroyed instances are released, but this is **unverified**. The dev loop should assume a restart may be needed. Also, the watcher does not follow symlinks (docs/decisions.md; O/shell/services/PluginRegistry.qml:726-745).
9. **Overlay keyboard default**. `OverlayWindow` defaults to `WlrKeyboardFocus.Exclusive` (O/shell/Ui/OverlayWindow.qml:16). Kept as is, apps can't be typed into while the pointer is on, which differs from TinyHand (§3 row 11).
10. **Keybinding convention** (O/default/agents/skills/omarchy/SKILL.md:170-178, 263). Binds belong in the user's `~/.config/hypr/bindings.lua` via `o.bind`. The plugin must not write them, so the README must tell the user to add them. `{ panel = id }` falls back to `omarchy-shell shell toggle` because the id isn't in `O/default/omarchy/shortcuts` (O/default/hypr/helpers.lua:99-100). That costs one process per keypress, compared with first-party plugins' direct `GlobalShortcut` (O/shell/shell.qml:1642-1653).
11. **Layer rules**. Omarchy turns off compositor animation and adds blur only for its own namespaces (O/default/hypr/apps/omarchy-shell.lua:12; O/default/hypr/toggles/window-glassy.lua:11). A plugin namespace such as `tinyhand` gets Hyprland's default layer animation unless the user adds a rule.
12. **Never edit `$OMARCHY_PATH`** (plugins.md:116-131; SKILL.md:256). The port must not add its id to `O/default/omarchy/shortcuts` or to `O/default/hypr/apps/omarchy-shell.lua`.

---

## 5. Open questions for the user

| # | Question | Context |
|---|---|---|
| Q1 | When the pointer is on, should apps still get scroll and hover underneath, as on macOS? On Wayland that means a per-gesture input mask, which can't be decided before the gesture starts. Or is it acceptable that the overlay takes all pointer input? | §3 row 3; C6, D2 |
| Q2 | Keyboard while on: Exclusive focus (Esc and modifiers work, but apps can't be typed into), or no focus plus a temporary Hyprland Esc bind (typing works, but no modifier state)? | §3 rows 6, 8, 11 |
| Q3 | Which modifier draws arrows, since SUPER+drag is Hyprland's window move: Shift, Ctrl, or Alt? | §3 row 8; D6 |
| Q4 | Keep "hold to click for real" (default ⌥ = Alt) and the double-tap ⇧ click-through? Both need Hyprland modifier binds that you add, and the double-tap can't check for "no other key between". | B9-B11; §3 rows 6, 7 |
| Q5 | Multi-monitor: one surface per screen (`Variants`), or one surface that moves to the focused monitor? Should ink still clear on a screen change (B19)? | §3 row 16 |
| Q6 | Hotkeys: keep the decided `CTRL+ALT+H`, and add `CTRL+ALT+X` for clear (both free in `hyprctl binds -j`)? | A1, A2; docs/decisions.md |
| Q7 | Where should settings live: inline in `shell.json` (visible and hand-editable) or a plugin-owned JSON file? And how much of the Settings window should be built: none, or a bar-widget popup with the toolbar, ink, fade, sound, size and shadow settings? | §3 rows 20, 31; I1-I5 |
| Q8 | Port all 36 hands, 15 sounds and the laser (about 9 MB of PNGs), or a subset? | §2 |
| Q9 | Custom-hand maker (validation plus composition, I5): port it, defer it, or drop it? | §3 row 32 |
| Q10 | Bar-widget right click: a popup menu with the H4 items, or no menu? "Quit" and "Check for Updates" have no meaning in a plugin. | H2, H4; §3 rows 12, 24 |
| Q11 | Animations: follow the guide (≤300 ms, no ease-in, `Style.duration`) or match TinyHand exactly (0.6 s ease-in ink fade, 0.35 s toolbar exit)? | §4.1; L |
| Q12 | Theme the toolbar with Omarchy colours, or keep TinyHand's fixed dark glass? | §4.4; F3 |
| Q13 | `tinyhand://` compatibility: ship an `x-scheme-handler/tinyhand` `.desktop` file that maps to `omarchy-shell` IPC, which lives outside the plugin folder? Or IPC only? Write `state.json` at all? | §3 rows 21, 22; K1-K3 |
| Q14 | Auto-off on sleep and screensaver: worth a logind watcher, or rely on the lock covering the overlay? | B7; §3 row 26 |
| Q15 | Should clicks on the Omarchy bar pass through while the pointer is on, like the macOS menu bar (B13)? | §3 row 4 |
| Q16 | Translations: English only at first (allowed, plugins.md:88), or ship `tr.json` too? | §4.2 |

---

## 6. Follow-up questions (added after the user's Stage 1 approval)

### 6.1 Hotkey: is `CTRL+ALT+H` free?
Yes. `hyprctl binds -j` (live, 2026-11-17) lists exactly one bind on key `H`: modmask 68 (`SUPER+CTRL`) → "Hardware menu". `CTRL+ALT` is modmask 12; nothing is bound there for `H`, and `CTRL+ALT+X` is also free. Decision: **`CTRL+ALT+H` is the default** (1:1 with ⌃⌥H, S/Preferences.swift:10); `SUPER+ALT+H` is only a fallback if a conflict appears later.

### 6.2 Click blocking: intended behavior vs bug
- **Intended (1:1):** while the pointer is **on**, every mouse button press and release is consumed and no app receives it (C1, S/InputTap.swift:187-200). Exceptions in the original: pass-through zones (B13) and the interact key (B11).
- **Bug:** **any** click consumed while the pointer is **off**. The overlay must have no input region at all when off.
- How the port guarantees it: `OverlayWindow` sets `visible: shown && !!targetScreen && !!targetMonitor` (O/shell/Ui/OverlayWindow.qml:62), so when `shown` is false the layer surface is unmapped and has no input region. The risk is any *other* always-mapped `PanelWindow` (for example one kept alive by `keepLoaded: true`) or a `visible: true` override. Regression check: after turning off, `hyprctl layers -j` must not list the plugin's namespace.

### 6.3 Hot reload: which kinds reload on save?
Source path: `inotifywait -m -r` on `~/.config/omarchy/plugins` (O/shell/services/PluginRegistry.qml:726-745) → `localPluginChanged(id)` → 150 ms timer (O/shell/shell.qml:69-73, 1539-1543) → `reloadPlugins()` (O/shell/shell.qml:1517-1527), which runs:
| Kind | What reload does | Reloads on save? |
|---|---|---|
| `overlay`, `panel`, `menu` (incl. `keepLoaded: true`) | `unloadPanels()` clears `panelEntryModel` entirely (shell.qml:1291-1297), then `Qt.clearComponentCache()` + rescan recreate them (shell.qml:1529-1535, 1340-1360) | **Yes, per source** |
| `bar-widget` | `unloadPluginWidgets()` then re-created by `syncPluginWidgets()` | **Yes** |
| `service` without `keepLoaded` | `unloadPluginServices()` destroys it | **Yes** |
| `service` with `keepLoaded: true` | deliberately kept alive "must survive plugin hot-reload" (shell.qml:1059-1062) | **No → `omarchy restart shell`** |
The guide agrees: "Saving a file anywhere under `~/.config/omarchy/plugins/` reloads plugin code automatically. If a change somehow fails to apply, force a reload with `omarchy-shell shell rescanPlugins`" (plugins.md:129-131). The earlier attempt's observation (a keepLoaded overlay stayed stale until `omarchy restart shell`) contradicts the source reading; Stage 3 tests it directly.

### 6.4 Developing from `~/Work/edooman.tinyhand`
`plugins.md` has no workflow for an out-of-tree source: it assumes edits happen in `~/.config/omarchy/plugins/<id>/` (plugins.md:119-131). Options checked against the scripts:
- **Symlink** `~/.config/omarchy/plugins/edooman.tinyhand → ~/Work/...`: the scan follows it (`for sub in "$dir"/*/`, PluginRegistry.qml), but `inotifywait -r` doesn't descend into symlinked dirs, so no auto-reload; and `omarchy plugin validate` rejects symlinks (§4.6).
- **`omarchy plugin add ~/Work/edooman.tinyhand`** (a bare path passes `omarchy-git-url-check`, it only refuses `::` helpers and unknown `scheme://`), then per change: `git commit` + `omarchy plugin update edooman.tinyhand` (`git fetch origin HEAD` + reset, O/bin/omarchy-plugin-update:43-73). The update writes into the watched dir, so the shell auto-reloads. **Chosen**: it is the same path real users install through.
