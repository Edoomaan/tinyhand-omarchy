// PROTOTYPE: virtual pointer for the nested test compositor only.
// usage: vclick move X Y W H | down | up | click | drag X1 Y1 X2 Y2 W H
#include <linux/input-event-codes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "vp.h"

static struct zwlr_virtual_pointer_manager_v1 *mgr;

static void global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t v) {
  if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name))
    mgr = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void global_remove(void *d, struct wl_registry *r, uint32_t n) {}
static const struct wl_registry_listener rl = {global, global_remove};

static void move(struct zwlr_virtual_pointer_v1 *p, int x, int y, int w, int h) {
  zwlr_virtual_pointer_v1_motion_absolute(p, 0, x, y, w, h);
  zwlr_virtual_pointer_v1_frame(p);
}
static void button(struct zwlr_virtual_pointer_v1 *p, int pressed) {
  zwlr_virtual_pointer_v1_button(p, 0, BTN_LEFT, pressed);
  zwlr_virtual_pointer_v1_frame(p);
}

int main(int argc, char **argv) {
  struct wl_display *dpy = wl_display_connect(NULL);
  if (!dpy) { fprintf(stderr, "no display\n"); return 1; }
  struct wl_registry *reg = wl_display_get_registry(dpy);
  wl_registry_add_listener(reg, &rl, NULL);
  wl_display_roundtrip(dpy);
  if (!mgr) { fprintf(stderr, "no virtual pointer manager\n"); return 1; }
  struct zwlr_virtual_pointer_v1 *p = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(mgr, NULL);
  const char *c = argc > 1 ? argv[1] : "";
  if (!strcmp(c, "move") && argc == 6) move(p, atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
  else if (!strcmp(c, "down")) button(p, 1);
  else if (!strcmp(c, "up")) button(p, 0);
  else if (!strcmp(c, "click")) { button(p, 1); wl_display_roundtrip(dpy); usleep(50000); button(p, 0); }
  else if (!strcmp(c, "drag") && argc == 8) {
    int x1 = atoi(argv[2]), y1 = atoi(argv[3]), x2 = atoi(argv[4]), y2 = atoi(argv[5]), w = atoi(argv[6]), h = atoi(argv[7]);
    move(p, x1, y1, w, h); wl_display_roundtrip(dpy); usleep(30000);
    button(p, 1); wl_display_roundtrip(dpy);
    for (int i = 1; i <= 20; i++) { move(p, x1 + (x2 - x1) * i / 20, y1 + (y2 - y1) * i / 20, w, h); wl_display_roundtrip(dpy); usleep(15000); }
    button(p, 0);
  } else { fprintf(stderr, "bad args\n"); return 2; }
  wl_display_roundtrip(dpy);
  usleep(30000);
  return 0;
}
