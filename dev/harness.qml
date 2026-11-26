// Dev harness: loads the plugin the way omarchy-shell does, inside a nested Hyprland.
// Run with dev/harness (never in the user's session).
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
  id: root

  FloatingWindow {
    implicitWidth: 1280; implicitHeight: 800
    color: "steelblue"
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onPressed: m => console.log("PROBE target-pressed", Math.round(m.x), Math.round(m.y), "mods", m.modifiers)
    }
    Text { anchors.centerIn: parent; text: "target window"; color: "white"; font.pixelSize: 40 }
  }

  QtObject {
    id: shellStub
    function hide(id) { if (overlay.item) overlay.item.close(); return true }
    function summon(id, p) { if (overlay.item) overlay.item.open(p); return true }
    function toggle(id, p) { return overlay.item && overlay.item.opened ? hide(id) : summon(id, p) }
    function isPluginOpen(id) { return !!(overlay.item && overlay.item.opened) }
  }

  Loader {
    id: overlay
    source: Qt.resolvedUrl("plugin/HandOverlay.qml")
    onLoaded: { item.shell = shellStub; item.manifest = { id: "edooman-tinyhand" } }
  }

  IpcHandler {
    target: "h"
    function on(): void { shellStub.summon("", "") }
    function off(): void { shellStub.hide("") }
    function call(method: string, arg: string): string {
      var r = overlay.item[method](arg)
      return r === undefined ? "ok" : String(r)
    }
    function js(expr: string): string { return String(eval(expr)) }
  }
}
