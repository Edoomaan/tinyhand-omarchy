import QtQuick
import "Ink.js" as Ink

// The drawing on one screen (Ink.swift plus OverlayController.drag).
Item {
  id: ink

  property color color: "#8754F2"
  property real strokeWidth: Ink.width(height)
  property int fadeDelay: 3000
  property bool arrow: false

  property var points: []
  property var current: null
  readonly property bool drawing: current !== null

  function render() {
    if (!current) return
    current.path = Ink.svgPath(points) + (arrow ? " " + Ink.arrowSvg(points, strokeWidth) : "")
  }

  onArrowChanged: render()

  function begin(p) {
    current = strokeComponent.createObject(ink, { strokeColor: ink.color, strokeWidth: ink.strokeWidth, fadeDelay: ink.fadeDelay })
    points = [p]
    render()
  }

  function extend(p) {
    if (!current) return
    var next = Ink.extend(points, p)
    if (next === points) return
    points = next
    render()
  }

  function end() {
    if (!current) return
    current.finish()
    current = null
    points = []
    arrow = false
  }

  function clear() {
    current = null
    points = []
    // Each stroke's layer.effect adds engine-owned items here too; destroying the stroke removes them.
    for (var i = ink.children.length - 1; i >= 0; i--) if (typeof ink.children[i].finish === "function") ink.children[i].destroy()
  }

  Component {
    id: strokeComponent
    InkStroke {}
  }
}
