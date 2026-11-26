import QtQuick
import QtQuick.Effects

// Draws the hand on its stick for a pose from Arm.js (ArmView.swift:183-197).
// The image holds both hand and rod; each half is cut out with sourceClipRect,
// the way TinyHand uses CALayer.contentsRect, and the rod half is stretched.
Item {
  id: arm

  required property var hand      // metrics from Hands.js
  required property var pose      // Arm.pose(...)
  property bool showShadow: true

  readonly property real imageHeight: 1024
  readonly property real imageWidth: Math.round(hand.aspect * imageHeight)

  x: pose.gripX - hand.rodX * pose.armWidth
  y: pose.gripY - (pose.rodLength + pose.handLength)
  width: pose.armWidth
  height: pose.rodLength + pose.handLength
  transform: Rotation {
    origin.x: arm.hand.rodX * arm.pose.armWidth
    origin.y: arm.height
    angle: arm.pose.rotation
  }

  Image {
    id: handPart
    y: 0
    width: arm.width
    height: arm.pose.handLength
    source: Qt.resolvedUrl("assets/hands/" + arm.hand.id + ".webp")
    sourceClipRect: Qt.rect(0, arm.hand.handTop * arm.imageHeight, arm.imageWidth, (arm.hand.wrist - arm.hand.handTop) * arm.imageHeight)
    smooth: true
    mipmap: true
    asynchronous: false
  }

  Image {
    y: arm.pose.handLength
    width: arm.width
    height: arm.pose.rodLength
    source: handPart.source
    sourceClipRect: Qt.rect(0, arm.hand.wrist * arm.imageHeight, arm.imageWidth, (arm.hand.rodEnd - arm.hand.wrist) * arm.imageHeight)
    smooth: true
    mipmap: true
  }

  // The offset is pre-rotated into the arm's frame by Arm.js, so the shadow
  // falls down-right on screen whatever the arm's angle.
  layer.enabled: showShadow
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: "black"
    shadowOpacity: arm.pose.shadowOpacity
    shadowHorizontalOffset: arm.pose.shadowX
    shadowVerticalOffset: arm.pose.shadowY
    blurMax: 48
    shadowBlur: Math.min(1, arm.pose.shadowRadius * 2 / 48)
  }
}
