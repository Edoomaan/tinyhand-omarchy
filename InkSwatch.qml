import QtQuick
import qs.Commons
import qs.Commons as Commons

// A round ink swatch; "match" is drawn as a six-colour rainbow (Toolbar.swift:453-484).
Item {
  id: swatch

  property real size: 20
  property string choice: "match"
  property color swatchColor: "transparent"
  readonly property var rainbow: ["#FF291F", "#FF8A00", "#FFCC00", "#30C25A", "#0A84FF", "#8754F2"]

  width: size
  height: size

  Rectangle {
    visible: swatch.choice !== "match"
    anchors.fill: parent
    radius: width / 2
    color: swatch.swatchColor
    border.width: 1
    border.color: Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.25)
  }

  Canvas {
    visible: swatch.choice === "match"
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      var r = width / 2
      ctx.reset()
      for (var i = 0; i < 6; i++) {
        ctx.beginPath()
        ctx.moveTo(r, r)
        ctx.arc(r, r, r, (-90 + i * 60) * Math.PI / 180, (-30 + i * 60) * Math.PI / 180)
        ctx.closePath()
        ctx.fillStyle = swatch.rainbow[i]
        ctx.fill()
      }
    }
  }
}
