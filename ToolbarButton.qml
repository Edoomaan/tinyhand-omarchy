import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A 40 x 40 toolbar button; the selected one gets the theme's selected background
// (TinyHand: white 0.18, Toolbar.swift:360-364).
Rectangle {
  id: button

  property bool selected: false
  property string tip: ""
  signal clicked()

  width: 40
  height: 40
  radius: Math.min(10, Style.cornerRadius)
  color: selected ? Commons.Color.menu.selectedBackground : (mouse.containsMouse ? Qt.rgba(Commons.Color.menu.text.r, Commons.Color.menu.text.g, Commons.Color.menu.text.b, 0.06) : "transparent")
  border.width: selected ? 1 : 0
  border.color: Commons.Color.menu.selectedBorder

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onClicked: button.clicked()
  }

  PanelToolTip {
    visible: mouse.containsMouse && button.tip !== ""
    text: button.tip
  }
}
