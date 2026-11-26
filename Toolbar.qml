import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Ink.js" as Ink

// Toolbar shown while the pointer is on (Toolbar.swift). Pinned styles, a
// divider, ink colour (with its tray), tap sound and exit. Omarchy theme
// colours replace TinyHand's fixed dark glass (docs/decisions.md, Q12).
Item {
  id: toolbar

  property bool revealed: false
  property color currentInk: "#8754F2"
  signal exitRequested()

  // Pinned styles plus the current one if it isn't pinned (Toolbar.rebuildStyles).
  readonly property var styles: TinyState.pinned.indexOf(TinyState.style) >= 0
    ? TinyState.pinned : TinyState.pinned.concat([TinyState.style])
  property bool trayOpen: false

  width: panel.width
  height: panel.height
  opacity: revealed ? 1 : 0
  enabled: revealed   // a hidden toolbar ignores the mouse
  onRevealedChanged: if (!revealed) trayOpen = false
  Behavior on opacity {
    NumberAnimation {
      duration: Style.duration(toolbar.revealed ? 180 : 120)
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    id: panel
    width: row.width + 20
    height: row.height + 16
    radius: Style.cornerRadius
    color: Commons.Color.menu.background
    border.width: 1
    border.color: Commons.Color.menu.border

    // Swallow clicks on the toolbar's own background so they don't tap.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Row {
      id: row
      x: 10
      y: 8
      spacing: 6

      Repeater {
        model: toolbar.styles
        ToolbarButton {
          required property string modelData
          selected: TinyState.style === modelData
          tip: TinyState.styleTitle(modelData)
          onClicked: TinyState.setStyle(modelData)

          Image {
            visible: parent.modelData !== "laser"
            anchors.centerIn: parent
            width: 32
            height: 32
            source: parent.modelData !== "laser" ? Qt.resolvedUrl("assets/thumbs/" + parent.modelData + ".webp") : ""
            smooth: true
            mipmap: true
          }
          Rectangle {
            visible: parent.modelData === "laser"
            anchors.centerIn: parent
            width: 14
            height: 14
            radius: 7
            color: Ink.PALETTE.red
            Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Qt.rgba(1, 0.86, 0.82, 0.95) }
          }
        }
      }

      Rectangle {
        width: 1
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        color: Commons.Color.menu.border
        opacity: 0.6
      }

      ToolbarButton {
        id: inkButton
        visible: TinyState.settings.showInkButton
        tip: TinyState.t("toolbar.ink")
        selected: toolbar.trayOpen
        onClicked: toolbar.trayOpen = !toolbar.trayOpen
        InkSwatch {
          anchors.centerIn: parent
          size: 20
          choice: TinyState.settings.inkChoice
          swatchColor: toolbar.currentInk
        }
      }

      ToolbarButton {
        tip: TinyState.t(TinyState.soundOn ? "toolbar.soundOn" : "toolbar.soundOff")
        onClicked: TinyState.toggleSound()
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: TinyState.soundOn ? "" : ""
          font.family: Style.font.family
          font.pixelSize: 17
          color: Commons.Color.menu.text
          opacity: TinyState.soundOn ? 0.85 : 0.45
        }
      }

      ToolbarButton {
        tip: TinyState.t("toolbar.exit")
        onClicked: toolbar.exitRequested()
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: ""
          font.family: Style.font.family
          font.pixelSize: 16
          color: Commons.Color.menu.text
          opacity: 0.85
        }
      }
    }
  }

  // Ink tray: 9 swatches, 8 px above the ink button (Toolbar.swift:133-200).
  Rectangle {
    id: tray
    visible: opacity > 0
    opacity: toolbar.trayOpen ? 1 : 0
    enabled: toolbar.trayOpen
    x: Math.round(panel.x + row.x + inkButton.x + inkButton.width / 2 - width / 2)
    y: -height - 8
    width: trayRow.width + 16
    height: trayRow.height + 16
    radius: Style.cornerRadius
    color: Commons.Color.menu.background
    border.width: 1
    border.color: Commons.Color.menu.border
    Behavior on opacity {
      NumberAnimation { duration: Style.duration(toolbar.trayOpen ? 120 : 80); easing.type: Easing.OutCubic }
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    Row {
      id: trayRow
      x: 8
      y: 8
      spacing: 4
      Repeater {
        model: Ink.CHOICES
        ToolbarButton {
          required property string modelData
          width: 30
          height: 30
          selected: TinyState.settings.inkChoice === modelData
          tip: TinyState.t("ink." + modelData)
          onClicked: {
            TinyState.settings.inkChoice = modelData
            toolbar.trayOpen = false
          }
          InkSwatch {
            anchors.centerIn: parent
            size: 18
            choice: parent.modelData
            swatchColor: Ink.PALETTE[parent.modelData] || "transparent"
          }
        }
      }
    }
  }
}
