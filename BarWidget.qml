import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons as Commons
import qs.Commons
import qs.Ui
import "Hands.js" as Hands
import "SettingsLogic.js" as SettingsLogic

// The menu bar icon and popup menu/settings (H1-H4, I2-I4; AppDelegate.swift:76-134):
// - Left click toggles the pointer on/off
// - Right click opens the menu
// - Menu options: Turn On/Off, Clear Drawing, Tap Sound, Settings…
// - Settings view: interact key, click-through, toolbar & pinned styles, size, shadow, fade, tap sound.
BarWidget {
  id: root
  moduleName: "edooman-tinyhand"

  property var shell: null
  property bool popupOpen: false
  property string view: "menu"   // "menu" | "settings"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function togglePointer() {
    if (root.shell && typeof root.shell.toggle === "function") root.shell.toggle("edooman-tinyhand", "")
    else if (root.bar) root.bar.run("omarchy-shell shell toggle edooman-tinyhand")
  }

  function clearDrawing() {
    if (root.shell && typeof root.shell.callIfLoaded === "function") root.shell.callIfLoaded("edooman-tinyhand", "clear", "")
    else if (root.bar) root.bar.run("omarchy-shell shell call edooman-tinyhand clear ''")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Pointing hand icon (\uf0a6)
    text: "\uf0a6"
    dimmed: !TinyState.active
    foreground: TinyState.clickThrough ? Commons.Color.accent : (root.bar ? root.bar.foreground : Commons.Color.foreground)

    // On/off and click-through already show in the icon (dimmed / accent).
    tooltipText: TinyState.t("bar.tooltip")
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) {
        root.togglePointer()
      } else if (mouseButton === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
      }
    }
  }

  TapSound {
    id: previewSound
    sound: TinyState.settings.tapSound
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    triggerMode: "click"
    onOpenChanged: {
      root.popupOpen = open
      if (!open) root.view = "menu"
    }

    contentWidth: popup.fittedContentWidth(root.view === "settings" ? Style.space(380) : Style.space(260))
    contentHeight: popup.fittedContentHeight(root.view === "settings" ? settingsLayout.implicitHeight : menuLayout.implicitHeight, Style.space(520))

    Item {
      anchors.fill: parent

      // ==========================================
      // MENU VIEW (H4)
      // ==========================================
      Column {
        id: menuLayout
        visible: root.view === "menu"
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(4)

        // Header / Brand
        Row {
          spacing: Style.space(8)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.space(4)

          Text {
            textFormat: Text.PlainText
            text: "\uf0a6"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            color: TinyState.active ? (TinyState.clickThrough ? Commons.Color.accent : Commons.Color.foreground) : Commons.Color.muted
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            textFormat: Text.PlainText
            text: "TinyHand"
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            color: Commons.Color.foreground
            anchors.verticalCenter: parent.verticalCenter
          }

          Item { Layout.fillWidth: true; width: 1; height: 1 }

          BorderSurface {
            anchors.verticalCenter: parent.verticalCenter
            radius: Style.cornerRadius
            color: TinyState.active ? (TinyState.clickThrough ? Commons.Color.accent : Commons.Color.popups.border) : "transparent"
            borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
            topPadding: Style.space(2); bottomPadding: Style.space(2)
            leftPadding: Style.space(6); rightPadding: Style.space(6)
            // BorderSurface doesn't size itself from its children.
            implicitWidth: badgeLabel.implicitWidth + leftPadding + rightPadding
            implicitHeight: badgeLabel.implicitHeight + topPadding + bottomPadding
            Text {
              id: badgeLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: TinyState.active ? (TinyState.clickThrough ? "THROUGH" : "ON") : "OFF"
              font.pixelSize: Style.font.caption
              font.bold: true
              color: TinyState.active ? Commons.Color.popups.background : Commons.Color.muted
            }
          }
        }

        // Separator
        Rectangle {
          width: parent.width
          height: 1
          color: Commons.Color.popups.border
          opacity: 0.3
        }

        // Item 1: Turn Pointer On / Off
        BorderSurface {
          width: parent.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: item1Hover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
          leftPadding: Style.space(8); rightPadding: Style.space(8)

          Row {
            anchors.fill: parent
            Text {
              textFormat: Text.PlainText
              text: TinyState.active ? TinyState.t("menu.turnOff") : TinyState.t("menu.turnOn")
              font.pixelSize: Style.font.body
              color: Commons.Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { Layout.fillWidth: true; width: 1; height: 1 }
            Text {
              textFormat: Text.PlainText
              text: "CTRL+ALT+H"
              font.pixelSize: Style.font.caption
              color: Commons.Color.muted
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          HoverHandler { id: item1Hover }
          MouseArea {
            anchors.fill: parent
            onClicked: {
              root.togglePointer()
              popup.open = false
            }
          }
        }

        // Item 2: Clear Drawing
        BorderSurface {
          width: parent.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: item2Hover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
          leftPadding: Style.space(8); rightPadding: Style.space(8)

          Row {
            anchors.fill: parent
            Text {
              textFormat: Text.PlainText
              text: TinyState.t("menu.clear")
              font.pixelSize: Style.font.body
              color: Commons.Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { Layout.fillWidth: true; width: 1; height: 1 }
            Text {
              textFormat: Text.PlainText
              text: "CTRL+ALT+X"
              font.pixelSize: Style.font.caption
              color: Commons.Color.muted
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          HoverHandler { id: item2Hover }
          MouseArea {
            anchors.fill: parent
            onClicked: {
              root.clearDrawing()
              popup.open = false
            }
          }
        }

        // Item 3: Tap Sound
        BorderSurface {
          width: parent.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: item3Hover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
          leftPadding: Style.space(8); rightPadding: Style.space(8)

          Row {
            anchors.fill: parent
            Text {
              textFormat: Text.PlainText
              text: TinyState.t("menu.sound")
              font.pixelSize: Style.font.body
              color: Commons.Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { Layout.fillWidth: true; width: 1; height: 1 }
            Text {
              textFormat: Text.PlainText
              text: TinyState.soundOn ? "\u2713" : ""
              font.pixelSize: Style.font.body
              font.bold: true
              color: Commons.Color.accent
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          HoverHandler { id: item3Hover }
          MouseArea {
            anchors.fill: parent
            onClicked: TinyState.toggleSound()
          }
        }

        // Separator
        Rectangle {
          width: parent.width
          height: 1
          color: Commons.Color.popups.border
          opacity: 0.3
        }

        // Item 4: Settings…
        BorderSurface {
          width: parent.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: item4Hover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
          leftPadding: Style.space(8); rightPadding: Style.space(8)

          Row {
            anchors.fill: parent
            Text {
              textFormat: Text.PlainText
              text: TinyState.t("menu.settings")
              font.pixelSize: Style.font.body
              color: Commons.Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { Layout.fillWidth: true; width: 1; height: 1 }
            Text {
              textFormat: Text.PlainText
              text: "\u2192"
              font.pixelSize: Style.font.body
              color: Commons.Color.muted
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          HoverHandler { id: item4Hover }
          MouseArea {
            anchors.fill: parent
            onClicked: root.view = "settings"
          }
        }
      }

      // ==========================================
      // SETTINGS VIEW (I2-I4)
      // ==========================================
      Flickable {
        id: settingsFlickable
        visible: root.view === "settings"
        anchors.fill: parent
        contentWidth: width
        contentHeight: settingsLayout.implicitHeight
        clip: true

        Column {
          id: settingsLayout
          width: parent.width
          spacing: Style.space(8)

          // Header with Back button
          Row {
            spacing: Style.space(8)
            width: parent.width

            BorderSurface {
              radius: Style.cornerRadius
              color: backHover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
              borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
              topPadding: Style.space(4); bottomPadding: Style.space(4)
              leftPadding: Style.space(8); rightPadding: Style.space(8)
              implicitWidth: backLabel.implicitWidth + leftPadding + rightPadding
              implicitHeight: backLabel.implicitHeight + topPadding + bottomPadding
              Text {
                id: backLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "\u2190 " + TinyState.t("settings.back")
                font.pixelSize: Style.font.body
                color: Commons.Color.foreground
              }
              HoverHandler { id: backHover }
              MouseArea {
                anchors.fill: parent
                onClicked: root.view = "menu"
              }
            }

            Text {
              textFormat: Text.PlainText
              text: TinyState.t("settings.title")
              font.pixelSize: Style.font.subtitle
              font.bold: true
              color: Commons.Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Rectangle { width: parent.width; height: 1; color: Commons.Color.popups.border; opacity: 0.3 }

          // --- General ---
          Text {
            textFormat: Text.PlainText
            text: TinyState.t("settings.general")
            font.pixelSize: Style.font.subtitle
            font.bold: true
            color: Commons.Color.accent
          }

          // Interact key row
          Row {
            width: parent.width
            Text {
              textFormat: Text.PlainText
              text: TinyState.t("settings.interactKey")
              font.pixelSize: Style.font.body
              color: Commons.Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { Layout.fillWidth: true; width: 1; height: 1 }
            BorderSurface {
              radius: Style.cornerRadius
              color: keyHover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
              borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
              topPadding: Style.space(4); bottomPadding: Style.space(4)
              leftPadding: Style.space(10); rightPadding: Style.space(10)
              implicitWidth: keyLabel.implicitWidth + leftPadding + rightPadding
              implicitHeight: keyLabel.implicitHeight + topPadding + bottomPadding
              Text {
                id: keyLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: TinyState.settings.interactKey.toUpperCase()
                font.pixelSize: Style.font.body
                font.bold: true
                color: Commons.Color.foreground
              }
              HoverHandler { id: keyHover }
              MouseArea {
                anchors.fill: parent
                onClicked: {
                  TinyState.settings.interactKey = SettingsLogic.nextInteractKey(TinyState.settings.interactKey)
                }
              }
            }
          }

          // Keep hand visible toggle
          Toggle {
            width: parent.width
            label: TinyState.t("settings.interactKeepsHand")
            checked: TinyState.settings.interactKeepsHand
            onClicked: TinyState.settings.interactKeepsHand = !TinyState.settings.interactKeepsHand
          }

          // Double Shift toggle
          Toggle {
            width: parent.width
            label: TinyState.t("settings.doubleShift")
            checked: TinyState.settings.doubleShiftClickThrough
            onClicked: TinyState.settings.doubleShiftClickThrough = !TinyState.settings.doubleShiftClickThrough
          }

          Rectangle { width: parent.width; height: 1; color: Commons.Color.popups.border; opacity: 0.3 }

          // --- Toolbar & Pointers ---
          Text {
            textFormat: Text.PlainText
            text: TinyState.t("settings.pointers")
            font.pixelSize: Style.font.subtitle
            font.bold: true
            color: Commons.Color.accent
          }

          Toggle {
            width: parent.width
            label: TinyState.t("settings.showToolbar")
            checked: TinyState.settings.showToolbar
            onClicked: TinyState.settings.showToolbar = !TinyState.settings.showToolbar
          }

          Toggle {
            width: parent.width
            label: TinyState.t("settings.showInkButton")
            checked: TinyState.settings.showInkButton
            onClicked: TinyState.settings.showInkButton = !TinyState.settings.showInkButton
          }

          Text {
            textFormat: Text.PlainText
            text: TinyState.t("settings.pinned")
            font.pixelSize: Style.font.body
            color: Commons.Color.foreground
          }

          // Pinned styles flow
          Flow {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: ["laser"].concat(Hands.hands.map(function(h) { return h.id }))
              delegate: BorderSurface {
                required property string modelData
                readonly property bool isPinned: TinyState.pinned.indexOf(modelData) >= 0
                radius: Style.cornerRadius
                color: isPinned ? Commons.Color.accent : (chipHover.hovered ? Commons.Color.menu.selectedBackground : "transparent")
                borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
                topPadding: Style.space(2); bottomPadding: Style.space(2)
                leftPadding: Style.space(6); rightPadding: Style.space(6)
                implicitWidth: chipLabel.implicitWidth + leftPadding + rightPadding
                implicitHeight: chipLabel.implicitHeight + topPadding + bottomPadding

                Text {
                  id: chipLabel
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: (isPinned ? "\u2713 " : "") + TinyState.styleTitle(modelData)
                  font.pixelSize: Style.font.caption
                  color: isPinned ? Commons.Color.popups.background : Commons.Color.foreground
                }

                HoverHandler { id: chipHover }
                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    TinyState.settings.pinnedStyles = SettingsLogic.togglePinned(TinyState.pinned, modelData)
                  }
                }
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: Commons.Color.popups.border; opacity: 0.3 }

          // --- Appearance & Sound ---
          Text {
            textFormat: Text.PlainText
            text: TinyState.t("settings.appearance")
            font.pixelSize: Style.font.subtitle
            font.bold: true
            color: Commons.Color.accent
          }

          // Pointer size row
          Row {
            width: parent.width
            Text {
              textFormat: Text.PlainText
              text: TinyState.t("settings.pointerSize") + " (" + Math.round(TinyState.settings.pointerSize * 100) + "%)"
              font.pixelSize: Style.font.body
              color: Commons.Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { Layout.fillWidth: true; width: 1; height: 1 }

            BorderSurface {
              radius: Style.cornerRadius
              color: sizeDownHover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
              borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
              topPadding: Style.space(2); bottomPadding: Style.space(2)
              leftPadding: Style.space(8); rightPadding: Style.space(8)
              implicitWidth: sizeDownLabel.implicitWidth + leftPadding + rightPadding
              implicitHeight: sizeDownLabel.implicitHeight + topPadding + bottomPadding
              Text { id: sizeDownLabel; anchors.centerIn: parent; textFormat: Text.PlainText; text: "\u2212"; font.bold: true; color: Commons.Color.foreground }
              HoverHandler { id: sizeDownHover }
              MouseArea {
                anchors.fill: parent
                onClicked: TinyState.settings.pointerSize = SettingsLogic.clampSize(TinyState.settings.pointerSize - 0.01)
              }
            }
            BorderSurface {
              radius: Style.cornerRadius
              color: sizeUpHover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
              borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
              topPadding: Style.space(2); bottomPadding: Style.space(2)
              leftPadding: Style.space(8); rightPadding: Style.space(8)
              implicitWidth: sizeUpLabel.implicitWidth + leftPadding + rightPadding
              implicitHeight: sizeUpLabel.implicitHeight + topPadding + bottomPadding
              Text { id: sizeUpLabel; anchors.centerIn: parent; textFormat: Text.PlainText; text: "+"; font.bold: true; color: Commons.Color.foreground }
              HoverHandler { id: sizeUpHover }
              MouseArea {
                anchors.fill: parent
                onClicked: TinyState.settings.pointerSize = SettingsLogic.clampSize(TinyState.settings.pointerSize + 0.01)
              }
            }
          }

          // Shadow toggle
          Toggle {
            width: parent.width
            label: TinyState.t("settings.showShadow")
            checked: TinyState.settings.showShadow
            onClicked: TinyState.settings.showShadow = !TinyState.settings.showShadow
          }

          // Ink fade row
          Row {
            width: parent.width
            Text {
              textFormat: Text.PlainText
              text: TinyState.t("settings.inkFade")
              font.pixelSize: Style.font.body
              color: Commons.Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
            Item { Layout.fillWidth: true; width: 1; height: 1 }
            BorderSurface {
              radius: Style.cornerRadius
              color: fadeHover.hovered ? Commons.Color.menu.selectedBackground : "transparent"
              borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
              topPadding: Style.space(4); bottomPadding: Style.space(4)
              leftPadding: Style.space(10); rightPadding: Style.space(10)
              implicitWidth: fadeLabel.implicitWidth + leftPadding + rightPadding
              implicitHeight: fadeLabel.implicitHeight + topPadding + bottomPadding
              Text {
                id: fadeLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: TinyState.settings.fadeSeconds === 0 ? TinyState.t("settings.fade.keep") : TinyState.settings.fadeSeconds + "s"
                font.pixelSize: Style.font.body
                font.bold: true
                color: Commons.Color.foreground
              }
              HoverHandler { id: fadeHover }
              MouseArea {
                anchors.fill: parent
                onClicked: TinyState.settings.fadeSeconds = SettingsLogic.nextFade(TinyState.settings.fadeSeconds)
              }
            }
          }

          // Tap sound row & grid
          Text {
            textFormat: Text.PlainText
            text: TinyState.t("settings.tapSound")
            font.pixelSize: Style.font.body
            color: Commons.Color.foreground
          }

          Flow {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: Hands.sounds
              delegate: BorderSurface {
                required property string modelData
                readonly property bool isSelected: TinyState.settings.tapSound === modelData
                radius: Style.cornerRadius
                color: isSelected ? Commons.Color.accent : (sndHover.hovered ? Commons.Color.menu.selectedBackground : "transparent")
                borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
                topPadding: Style.space(2); bottomPadding: Style.space(2)
                leftPadding: Style.space(6); rightPadding: Style.space(6)
                implicitWidth: soundLabel.implicitWidth + leftPadding + rightPadding
                implicitHeight: soundLabel.implicitHeight + topPadding + bottomPadding

                Text {
                  id: soundLabel
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: (isSelected ? "\u25B6 " : "") + modelData
                  font.pixelSize: Style.font.caption
                  color: isSelected ? Commons.Color.popups.background : Commons.Color.foreground
                }

                HoverHandler { id: sndHover }
                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    TinyState.settings.tapSound = modelData
                    previewSound.sound = modelData
                    previewSound.play()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
