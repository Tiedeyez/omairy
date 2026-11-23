import QtQuick
import qs.Commons
import "Sprite.js" as Sprite

// The fairy as a 16-bit handheld style sprite: a 28x28 pixel grid painted
// with square pixels that land exactly on screen pixels. Wings flap on three
// frames, and the dithered glow breathes and palette-cycles.
Item {
  id: fairy

  // Size of one sprite pixel in logical units (set by the service so it
  // lands on whole screen pixels).
  property real px: 3
  property color glow: Color.accent
  property bool resting: false
  property bool animate: true

  property int frame: 1
  property int phase: 0
  property int tick: 0

  width: Sprite.GRID * px
  height: Sprite.GRID * px

  function css(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (a === undefined ? 1 : a) + ")"
  }

  // Palette cycling: on phase 2 the glow steps to a lighter tint
  // (glowPeak/glowLightPeak), applied by the cached glow canvas for that phase.
  readonly property var palette: ({
    glow: css(glow),
    glowLight: css(Qt.lighter(glow, 1.5)),
    glowPeak: css(Qt.lighter(glow, 1.25)),
    glowLightPeak: css(Qt.lighter(glow, 1.75)),
    outline: css(Qt.darker(glow, 1.9)),
    shade: css(Qt.darker(glow, 1.25)),
    base: css(glow),
    light: css(Qt.lighter(glow, 1.5)),
    white: "rgba(255,255,255,1)",
    wingLine: css(Qt.lighter(glow, 1.35)),
    wing: css(Qt.tint(Qt.lighter(glow, 1.9), Qt.rgba(1, 1, 1, 0.55)))
  })

  // Flying: up, mid, down, mid at ~14 fps. Resting: wings folded, a lazy
  // flap now and then.
  Timer {
    interval: 70
    repeat: true
    running: fairy.animate
    onTriggered: {
      fairy.tick++
      if (fairy.resting) {
        var t = fairy.tick % 40
        fairy.frame = t < 4 ? [2, 1, 0, 1][t] : 2
      } else {
        fairy.frame = [0, 1, 2, 1][fairy.tick % 4]
      }
      if (fairy.tick % (fairy.resting ? 8 : 4) === 0) fairy.phase = (fairy.phase + 1) % 4
    }
  }

  // Cached layers. Each canvas is painted once and again only when the
  // colours, size or resting dim change; animation just switches which one
  // is visible, so a tick costs no JavaScript painting.
  readonly property real dim: resting ? 0.6 : 1.0

  Repeater {
    model: 4
    Canvas {
      required property int index
      anchors.fill: parent
      visible: fairy.phase === index
      renderStrategy: Canvas.Cooperative
      onPaint: Sprite.paintGlow(getContext("2d"), fairy.px, index, fairy.palette, fairy.dim)
      Connections {
        target: fairy
        function onPaletteChanged() { requestPaint() }
        function onDimChanged() { requestPaint() }
        function onPxChanged() { requestPaint() }
      }
    }
  }

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
