# Dev tools (not loaded by the shell)

- `dev/nested` — starts a hidden nested Hyprland on `special:tinyhandproto`. Inside it, run `hyprctl output create headless THTEST` (a hidden window gets no frames; the headless output does).
- `dev/harness <sig> <wayland-display>` — copies the plugin plus Omarchy's `Commons`/`Ui` into `$XDG_RUNTIME_DIR/tinyhand-harness` and runs it with `qs`, with its own `XDG_STATE_HOME`.
- `dev/vclick.c` — wlr-virtual-pointer client for that nested compositor (`move X Y W H`, `click`, `down`, `up`, `drag`). Build: generate `vp.h`/`vp.c` from `wlr-virtual-pointer-unstable-v1.xml` with `wayland-scanner`, then `gcc vclick.c vp.c $(pkg-config --cflags --libs wayland-client)`.
- Tests: `node --test tests/`.
