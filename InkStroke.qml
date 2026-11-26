import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.Commons

// One stroke (Ink.begin, Ink.swift:36-50): round caps and joins, no fill, and a
// soft black shadow. Once finished it waits, fades and removes itself.
Shape {
  id: stroke

  property string path: ""
  property color strokeColor: "#8754F2"
  property real strokeWidth: 6
  property int fadeDelay: 3000   // ms; -1 keeps it until cleared

  anchors.fill: parent
  preferredRendererType: Shape.CurveRenderer

  function finish() {
    if (fadeDelay >= 0) fade.start()
  }

  ShapePath {
    strokeColor: stroke.strokeColor
    strokeWidth: stroke.strokeWidth
    fillColor: "transparent"
    capStyle: ShapePath.RoundCap
    joinStyle: ShapePath.RoundJoin
    PathSvg { path: stroke.path }
  }

  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: "black"
    shadowOpacity: 0.18
    shadowHorizontalOffset: 1
    shadowVerticalOffset: 1.5
    blurMax: 8
    shadowBlur: 0.4
  }

  // TinyHand fades over 0.6 s ease-in; the Omarchy guide caps motion at 300 ms
  // with no ease-in, and the guide wins (docs/decisions.md, Q11).
  SequentialAnimation {
    id: fade
    PauseAnimation { duration: stroke.fadeDelay }
    NumberAnimation { target: stroke; property: "opacity"; to: 0; duration: Style.duration(200); easing.type: Easing.OutCubic }
    ScriptAction { script: stroke.destroy() }
  }
}
