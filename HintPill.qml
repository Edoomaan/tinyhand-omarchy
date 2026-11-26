import QtQuick
import qs.Commons
import qs.Commons as Commons

// Hint pill 12 px above the toolbar, ignoring the mouse (Toolbar.showHint,
// Toolbar.swift:280-351): each part is a bold key and dimmer text.
Rectangle {
  id: pill

  property var parts: []
  readonly property bool shown: parts.length > 0

  width: row.width + 32
  height: row.height + 18
  radius: Math.min(12, Style.cornerRadius)
  color: Commons.Color.menu.background
  border.width: 1
  border.color: Commons.Color.menu.border
  opacity: shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity {
    NumberAnimation { duration: Style.duration(pill.shown ? 180 : 120); easing.type: Easing.OutCubic }
  }

  Row {
    id: row
    x: 16
    y: 9
    spacing: 14
    Repeater {
      model: pill.parts
      Row {
        required property var modelData
        spacing: 4
        Text {
          textFormat: Text.PlainText
          text: modelData.key
          color: Commons.Color.menu.text
          font.family: Style.font.family
          font.pixelSize: 13
          font.weight: Font.DemiBold
        }
        Text {
          textFormat: Text.PlainText
          text: modelData.text
          color: Commons.Color.menu.text
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: 13
        }
      }
    }
  }
}
