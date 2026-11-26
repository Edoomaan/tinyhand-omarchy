import QtQuick
import QtQuick.Effects

// Laser dot (ArmView.aimLaser, ArmView.swift:199-217): red dot with a red glow
// and a pale core, centred exactly on the cursor, no stick.
Item {
  id: dot
  required property real cursorX
  required property real cursorY
  required property var shape   // Arm.laser(...)

  x: cursorX
  y: cursorY

  Rectangle {
    id: disc
    x: -dot.shape.radius
    y: -dot.shape.radius
    width: dot.shape.radius * 2
    height: width
    radius: width / 2
    color: Qt.rgba(1, 0.16, 0.12, 1)
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(1, 0.16, 0.12, 1)
      shadowOpacity: 1
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      blurMax: 64
      shadowBlur: Math.min(1, dot.shape.glow / 64)
    }
  }

  Rectangle {
    x: -dot.shape.core
    y: -dot.shape.core
    width: dot.shape.core * 2
    height: width
    radius: width / 2
    color: Qt.rgba(1, 0.86, 0.82, 0.95)
  }
}
