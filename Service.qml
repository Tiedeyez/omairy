import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "Sprite.js" as Sprite

// OmAiry: a small fairy of light that hangs out on the desktop.
//
// It lives on one full-screen, transparent layer-shell surface on the
// focused monitor. The surface takes no input except a small region around
// the fairy, so it never gets in the way of clicks. Behaviour is a tiny
// state machine run from a timer:
//   wander - drift to a random spot
//   visit  - hover around the window you are working in
//   perch  - sit on top of that window for a while, wings slow
//   dart   - zip away quickly after being clicked
// It sits on the Top layer, so fullscreen windows cover it, and it stops
// animating when the workspace has a fullscreen window or when animations
// are turned off (omarchy toggle animations).
Item {
  id: root

  property bool shown: true
  property string mode: "wander"
  property string bubbleKey: ""

  readonly property bool reducedMotion: Style.duration(1000) === 0
  readonly property var monitor: Hyprland.focusedMonitor
  readonly property bool underFullscreen: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.hasFullscreen : false
  readonly property bool animate: shown && !reducedMotion && !underFullscreen

  readonly property var lines: ["say.hey", "say.over", "say.psst", "say.stretch", "say.water",
                                "say.hi", "say.tickles", "say.busy", "say.look", "say.nap"]

  readonly property var targetScreen: {
    var name = monitor ? String(monitor.name) : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (String(screens[i].name) === name) return screens[i]
    return screens.length > 0 ? screens[0] : null
  }

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function rand(lo, hi) { return lo + Math.random() * (hi - lo) }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

  // Usable area of the surface: the monitor minus the space other panels
  // (the bar, a dock) reserve on each edge, from Hyprland's monitor info.
  function bounds() {
    var ipc = monitor ? monitor.lastIpcObject : null
    var r = ipc && ipc.reserved && ipc.reserved.length === 4 ? ipc.reserved : [0, 0, 0, 0]
    var pad = 4
    return { x0: Number(r[0]) + pad, y0: Number(r[1]) + pad,
             x1: win.width - Number(r[2]) - pad, y1: win.height - Number(r[3]) - pad }
  }

  // Active window rectangle in this monitor's local coordinates, or null.
  function activeWindowRect() {
    var top = Hyprland.activeToplevel
    var ipc = top ? top.lastIpcObject : null
    if (!ipc || !ipc.at || !ipc.size || !monitor) return null
    if (top.monitor && top.monitor !== monitor) return null
    if ((Number(ipc.fullscreen) & 2) !== 0) return null
    return { x: ipc.at[0] - monitor.x, y: ipc.at[1] - monitor.y, w: ipc.size[0], h: ipc.size[1] }
  }

  // Pick what to do next and fly there.
  function decide(forced) {
    if (!win.visible) return
    var W = win.width, H = win.height
    if (W <= 0 || H <= 0) return
    var fw = fairy.width, fh = fairy.height
    var b = bounds()
    var rect = activeWindowRect()

    var next = forced || ""
    if (next === "") {
      var r = Math.random()
      if (rect && r < 0.18) next = "perch"
      else if (rect && r < 0.50) next = "visit"
      else next = "wander"
    }

    var tx, ty, speed = 130, hold = rand(1800, 5000)
    if (next === "perch" && rect) {
      tx = rand(rect.x + 20, rect.x + rect.w - fw - 20)
      ty = rect.y - fh * 0.62
      speed = 110
      hold = rand(8000, 16000)
    } else if (next === "visit" && rect) {
      // Somewhere just around the window's edges.
      var side = Math.floor(Math.random() * 3)
      if (side === 0) { tx = rand(rect.x, rect.x + rect.w - fw); ty = rect.y - fh - rand(4, 60) }
      else if (side === 1) { tx = rect.x - fw - rand(4, 50); ty = rand(rect.y, rect.y + rect.h * 0.6) }
      else { tx = rect.x + rect.w + rand(4, 50); ty = rand(rect.y, rect.y + rect.h * 0.6) }
      hold = rand(2500, 6000)
    } else if (next === "dart") {
      tx = rand(b.x0, b.x1 - fw)
      ty = rand(b.y0, b.y1 - fh)
      speed = 520
      hold = rand(1500, 3000)
    } else {
      next = "wander"
      // Drift a moderate distance rather than across the whole screen every time.
      tx = fairy.x + rand(-420, 420)
      ty = fairy.y + rand(-260, 260)
    }

    tx = clamp(tx, b.x0, b.x1 - fw)
    ty = clamp(ty, b.y0, b.y1 - fh)
    mode = next

    if (!animate) {
      fairy.x = tx
      fairy.y = ty
      return
    }

    var dist = Math.sqrt((tx - fairy.x) * (tx - fairy.x) + (ty - fairy.y) * (ty - fairy.y))
    flyX.to = tx
    flyY.to = ty
    flight.duration = clamp(dist / speed * 1000, 500, 7000)
    flight.restart()
    brain.interval = flight.duration + hold
    brain.restart()
  }

  function poke() {
    if (!shown) return
    bubbleKey = lines[Math.floor(Math.random() * lines.length)]
    bubbleTimer.restart()
    ring.begin()
    flight.stop()
    brain.interval = 1400
    brain.restart()
    mode = "poked"
  }

  function home() {
    // Somewhere sensible before the first flight: lower right, out of the way.
    var b = bounds()
    fairy.x = Math.max(b.x0, b.x1 - fairy.width - 160)
    fairy.y = Math.max(b.y0, b.y1 - fairy.height - 180)
  }

  Timer {
    id: brain
    interval: 2000
    running: root.animate
    repeat: false
    onTriggered: root.decide(root.mode === "poked" ? "dart" : "")
  }

  Timer {
    id: bubbleTimer
    interval: 3400
    onTriggered: root.bubbleKey = ""
  }

  // Curious: sometimes flies over when you focus a different window.
  Connections {
    target: Hyprland
    function onActiveToplevelChanged() {
      if (root.animate && root.mode !== "perch" && Math.random() < 0.4)
        visitDelay.restart()
    }
  }
  Timer { id: visitDelay; interval: 450; onTriggered: root.decide("visit") }

  onAnimateChanged: {
    if (animate) { brain.interval = 800; brain.restart() }
    else { flight.stop(); brain.stop() }
  }
  onTargetScreenChanged: Qt.callLater(home)

  // Pixel units that land on whole screen pixels at any monitor scale.
  readonly property real screenScale: monitor && monitor.scale > 0 ? monitor.scale : 1
  readonly property real px: Math.max(1, Math.round(3 * screenScale)) / screenScale
  readonly property real ui: Math.max(1, Math.round(2 * screenScale)) / screenScale
  function snap(v, unit) { return Math.round(v / unit) * unit }

  property int bobStep: 0
  readonly property var bobPath: [0, -1, -1, 0, 1, 1]
  Timer {
    interval: root.mode === "perch" ? 340 : 170
    repeat: true
    running: root.animate
    onTriggered: root.bobStep = (root.bobStep + 1) % root.bobPath.length
  }

  PanelWindow {
    id: win
    screen: root.targetScreen
    visible: root.shown && root.targetScreen !== null
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tiedeyez-omairy"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the fairy itself takes clicks. The region is given in window
    // coordinates: Region.item reads an item's x/y relative to its parent,
    // which put the click area in the screen corner for the nested hit box.
    mask: Region {
      x: Math.round(sprite.x + hit.x)
      y: Math.round(sprite.y + hit.y)
      width: Math.round(hit.width)
      height: Math.round(hit.height)
    }

    onWidthChanged: if (fairy.x === 0 && fairy.y === 0) root.home()
    onHeightChanged: if (fairy.x === 0 && fairy.y === 0) root.home()

    ParallelAnimation {
      id: flight
      property int duration: 1500
      NumberAnimation { id: flyX; target: fairy; property: "x"; duration: flight.duration; easing.type: Easing.InOutSine }
      NumberAnimation { id: flyY; target: fairy; property: "y"; duration: flight.duration; easing.type: Easing.InOutSine }
    }

    // The fairy's true (smooth) position. Everything drawn snaps to the
    // pixel grid from here, so it moves in whole sprite pixels like a
    // handheld game.
    Item {
      id: fairy
      width: 28 * root.px
      height: 28 * root.px
    }

    // ---- sparkle trail: stepped 4-frame twinkles ---------------------------
    Item {
      id: trail
      anchors.fill: parent
      property int nextSlot: 0
      property int ticks: 0
      property bool live: false // any sparkle still twinkling

      // Runs only while flying or while sparkles are still fading out.
      Timer {
        interval: 100
        repeat: true
        running: root.animate && (flight.running || trail.live)
        onTriggered: {
          var any = false
          for (var i = 0; i < sparkles.count; i++) {
            var s = sparkles.itemAt(i)
            if (s && s.frame < 4) { s.frame++; s.y += root.px; if (s.frame < 4) any = true }
          }
          trail.live = any
          trail.ticks++
          var every = root.mode === "dart" ? 1 : 2
          if (flight.running && trail.ticks % every === 0) {
            var n = sparkles.itemAt(trail.nextSlot)
            trail.nextSlot = (trail.nextSlot + 1) % sparkles.count
            if (n) {
              n.x = root.snap(sprite.x + sprite.width / 2 + root.rand(-4, 4) * root.px, root.px)
              n.y = root.snap(sprite.y + sprite.height / 2 + root.rand(-2, 5) * root.px, root.px)
              n.frame = 0
              trail.live = true
            }
          }
        }
      }

      Repeater {
        id: sparkles
        model: 14
        Item {
          id: sp
          property int frame: 4
          readonly property int arm: [2, 1, 1, 0, -1][frame]
          visible: arm >= 0
          width: 0; height: 0
          Rectangle {
            x: -(sp.arm + 0.5) * root.px; y: -0.5 * root.px
            width: (2 * sp.arm + 1) * root.px; height: root.px
            color: Qt.lighter(Color.accent, 1.6)
          }
          Rectangle {
            x: -0.5 * root.px; y: -(sp.arm + 0.5) * root.px
            width: root.px; height: (2 * sp.arm + 1) * root.px
            color: Qt.lighter(Color.accent, 1.6)
          }
          Rectangle {
            x: -0.5 * root.px; y: -0.5 * root.px
            width: root.px; height: root.px
            color: sp.frame === 2 ? Qt.lighter(Color.accent, 1.6) : "white"
          }
        }
      }
    }

    // ---- the sprite ---------------------------------------------------------
    Item {
      id: sprite
      width: fairy.width
      height: fairy.height
      x: root.snap(fairy.x, root.px)
      y: root.snap(fairy.y, root.px) + root.bobPath[root.bobStep] * root.px

      // Chime: a dotted diamond that steps outwards.
      Canvas {
        id: ringCanvas
        property int step: -1
        readonly property int size: 33
        width: size * root.px; height: size * root.px
        x: (sprite.width - width) / 2
        y: (sprite.height - height) / 2
        renderStrategy: Canvas.Cooperative
        onPaint: {
          var ctx = getContext("2d")
          Sprite.paintRing(ctx, root.px, size, step >= 0 ? [4, 7, 10, 13, 16][step] : 0,
                           fairyArt.css(Qt.lighter(Color.accent, 1.6)))
        }
        onStepChanged: requestPaint()
        Timer {
          id: ring
          interval: 55
          repeat: true
          onTriggered: {
            if (ringCanvas.step >= 4) { ringCanvas.step = -1; stop() }
            else ringCanvas.step++
          }
          function begin() { ringCanvas.step = 0; restart() }
        }
      }

      Fairy {
        id: fairyArt
        anchors.fill: parent
        px: root.px
        glow: Color.accent
        resting: root.mode === "perch"
        animate: root.animate
      }

      Item {
        id: hit
        anchors.centerIn: parent
        width: 14 * root.px; height: 14 * root.px
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.poke()
        }
      }
    }

    // ---- text box: RPG dialog, opens in steps, types itself out -------------
    Item {
      id: box
      readonly property string full: root.bubbleKey !== "" ? strings.t(root.bubbleKey) : ""
      property int openStep: 0
      property int chars: 0
      property bool caret: true
      readonly property bool done: chars >= full.length

      readonly property int padX: 7
      readonly property int padY: 5
      readonly property int wUnits: Math.ceil(metrics.width) + padX * 2 + 4
      readonly property int hUnits: Math.ceil(metrics.height) + padY * 2 + 2

      visible: root.bubbleKey !== "" && openStep > 0
      width: wUnits * root.ui
      height: hUnits * root.ui
      x: root.snap(root.clamp(sprite.x + sprite.width / 2 - width / 2, 4, win.width - width - 4), root.ui)
      y: root.snap(Math.max(4, sprite.y + 5 * root.px - height), root.ui)

      TextMetrics {
        id: metrics
        font: label.font
        text: box.full
      }

      onFullChanged: {
        openStep = 0
        chars = 0
        if (full !== "") {
          if (Style.duration(100) === 0) { openStep = 3; chars = full.length }
          else opener.restart()
        }
      }

      Timer {
        id: opener
        interval: 45
        repeat: true
        onTriggered: {
          if (box.openStep < 3) box.openStep++
          else if (box.chars < box.full.length) box.chars++
          else stop()
        }
      }
      Timer {
        interval: 380
        repeat: true
        running: box.visible && box.done
        onTriggered: box.caret = !box.caret
      }

      // Box art, revealed top-down-from-the-middle in three steps.
      Item {
        anchors.centerIn: parent
        width: parent.width
        height: Math.max(root.ui * 6, root.snap(parent.height * box.openStep / 3, root.ui))
        clip: true
        Canvas {
          id: boxCanvas
          anchors.centerIn: parent
          width: box.width; height: box.height
          renderStrategy: Canvas.Cooperative
          onPaint: Sprite.paintBox(getContext("2d"), root.ui, box.wUnits, box.hUnits, {
            outline: fairyArt.css(Qt.darker(Color.background, 1.6)),
            frame: fairyArt.css(Color.foreground),
            accent: fairyArt.css(Color.accent),
            fill: fairyArt.css(Color.background)
          })
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          Connections {
            target: Color
            function onAccentChanged() { boxCanvas.requestPaint() }
            function onBackgroundChanged() { boxCanvas.requestPaint() }
          }
        }
      }

      // Text drawn at 1 texel per unit and blown up without smoothing, so the
      // glyphs come out chunky like a handheld font.
      Item {
        id: textHost
        visible: box.openStep >= 3
        x: box.padX * root.ui
        y: box.padY * root.ui
        width: Math.ceil(metrics.width)
        height: Math.ceil(metrics.height)
        transformOrigin: Item.TopLeft
        scale: root.ui
        layer.enabled: true
        layer.smooth: false
        layer.textureSize: Qt.size(width, height)

        Text {
          id: label
          textFormat: Text.PlainText
          color: Color.foreground
          font.family: Style.fontFamily
          font.pixelSize: 10
          font.bold: true
          renderType: Text.NativeRendering
          text: box.full.substring(0, box.chars)
        }
      }

      // Blinking "more" arrow.
      Item {
        visible: box.done && box.caret && box.openStep >= 3
        x: box.width - 8 * root.ui
        y: box.height - 6 * root.ui
        Repeater {
          model: [[0, 0, 5], [1, 1, 3], [2, 2, 1]]
          Rectangle {
            required property var modelData
            x: modelData[0] * root.ui; y: modelData[1] * root.ui
            width: modelData[2] * root.ui; height: root.ui
            color: Color.accent
          }
        }
      }
    }
  }

  ShellIpc {
    target: "tiedeyez.omairy"
    function show(): void { root.shown = true }
    function hide(): void { root.shown = false }
    function toggle(): void { root.shown = !root.shown }
    function poke(): void { root.poke() }
    function summon(): void {
      if (!root.shown) root.shown = true
      root.decide("visit")
    }
  }
}
