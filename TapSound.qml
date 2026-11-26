import QtQuick
import QtMultimedia

// Tap sound (TapSound.swift): four players used round-robin so rapid taps
// overlap; plays at the system output volume, no volume setting of its own.
Item {
  id: tap

  property string sound: "thock"
  property int next: 0
  readonly property url source: Qt.resolvedUrl("assets/sounds/tap_" + sound + ".wav")
  readonly property var players: [p0, p1, p2, p3]

  function play() {
    var p = players[next]
    next = (next + 1) % players.length
    p.stop()
    p.play()
  }

  SoundEffect { id: p0; source: tap.source }
  SoundEffect { id: p1; source: tap.source }
  SoundEffect { id: p2; source: tap.source }
  SoundEffect { id: p3; source: tap.source }
}
