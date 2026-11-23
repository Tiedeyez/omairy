import QtQuick
import qs.Commons
import "Sprite.js" as Sprite

// The fairy: the Omarchy icon mark with block wings, as a pixel sprite on a
// 37x37 grid whose pixels land exactly on screen pixels. Wings flap on three
// frames. The glow is block art too, on a finer grid of single screen pixels:
// the mark's own frames echoing outward and dissolving into shade textures.
Item {
  id: fairy

  // Size of one sprite pixel in logical units (set by the service so it
  // lands on whole screen pixels).
  property real px: 3
  // One screen pixel in logical units: the size of one glow cell.
  property real hair: 1
  property color glow: Color.accent
  property bool resting: false
  property bool animate: true
  // Wings held up and still for a moment, the way a butterfly glides
  // between bursts of flapping.
  property bool gliding: false
  // Faster wingbeats when it is in a hurry.
  property bool hurried: false

  property int frame: 1
  property int tick: 0

  width: Sprite.GRID * px
  height: Sprite.GRID * px

  function css(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (a === undefined ? 1 : a) + ")"
  }

  readonly property var palette: ({
    glow: css(glow),
    glowLight: css(Qt.lighter(glow, 1.5)),
    base: css(glow),
    white: "rgba(255,255,255,1)",
    wingLine: css(glow),
    wing: css(Qt.tint(Qt.lighter(glow, 1.9), Qt.rgba(1, 1, 1, 0.55)))
  })

  // Dimmer and slower while resting.
  readonly property real dim: resting ? 0.55 : 1.0

  // Flying: up, mid, down, mid at ~14 fps. Resting: wings folded, a lazy
  // flap now and then.
  Timer {
    interval: fairy.hurried ? 45 : 70
    repeat: true
    running: fairy.animate
    onTriggered: {
      fairy.tick++
      if (fairy.resting) {
        var t = fairy.tick % 40
        fairy.frame = t < 4 ? [2, 1, 0, 1][t] : 2
      } else if (fairy.gliding) {
        fairy.frame = 0
      } else {
        fairy.frame = [0, 1, 2, 1][fairy.tick % 4]
      }
    }
  }

  // ---- glow -----------------------------------------------------------------
  // Glow cells per sprite pixel (each cell is one screen pixel).
  readonly property int sub: Math.max(1, Math.round(px / hair))
  // Which step of the outward echo is showing.
  property int wave: 0
  Timer {
    interval: fairy.resting ? 190 : 95
    repeat: true
    running: fairy.animate
    onTriggered: fairy.wave = (fairy.wave + 1) % Sprite.GLOW_FRAMES
  }

  // One cached canvas per wave step, painted once (and again only when the
  // colours or size change). Radiating is just showing them in turn.
  Item {
    anchors.fill: parent
    opacity: fairy.dim
    Repeater {
      model: Sprite.GLOW_FRAMES
      Canvas {
        required property int index
        anchors.fill: parent
        visible: fairy.wave === index
        smooth: false
        renderStrategy: Canvas.Cooperative
        onPaint: Sprite.paintGlow(getContext("2d"), fairy.sub, fairy.px, index, fairy.palette)
        Connections {
          target: fairy
          function onPaletteChanged() { requestPaint() }
          function onSubChanged() { requestPaint() }
        }
      }
    }
  }

  // ---- sprite ---------------------------------------------------------------
  // Cached layers: each canvas is painted once and again only when the
  // colours or size change; flapping just switches which one is visible, so
  // a wingbeat costs no JavaScript painting.
  Repeater {
    model: 3
    Canvas {
      required property int index
      anchors.fill: parent
      visible: fairy.frame === index
      renderStrategy: Canvas.Cooperative
      onPaint: Sprite.paintBody(getContext("2d"), fairy.px, index, fairy.palette)
      Connections {
        target: fairy
        function onPaletteChanged() { requestPaint() }
        function onPxChanged() { requestPaint() }
      }
    }
  }

  // Two motes orbiting the fairy.
  Repeater {
    model: 2
    Rectangle {
      required property int index
      readonly property var cell: Sprite.mote(fairy.tick % 16, index)
      x: cell[0] * fairy.px
      y: cell[1] * fairy.px
      width: fairy.px
      height: fairy.px
      color: "white"
      opacity: 0.95 * fairy.dim
    }
  }
}
