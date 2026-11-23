import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "Sprite.js" as Sprite

// OmAiry: a small winged Omarchy mark that lives on the desktop.
//
// It lives on one full-screen, transparent layer-shell surface on the
// focused monitor. The surface takes no input except the square of the
// body, so it never gets in the way of clicks. Behaviour is a tiny state
// machine:
//   wander - drift to a spot nearby
//   visit  - hover around the window you are working in
//   perch  - sit on top of that window for a while, wings folded
//   dart   - zip away after being clicked and sharing a tip
// Flights are flown by a small smooth model (see `flight`), not along fixed
// curves. It sits on the Top layer, so fullscreen windows cover it, and it
// stops animating when the workspace has a fullscreen window or when
// animations are turned off (omarchy toggle animations).
Item {
  id: root

  property bool shown: true
  property string mode: "wander"
  property string bubbleKey: ""

  readonly property bool reducedMotion: Style.duration(1000) === 0
  readonly property var monitor: Hyprland.focusedMonitor
  readonly property bool underFullscreen: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.hasFullscreen : false
  readonly property bool animate: shown && !reducedMotion && !underFullscreen

  // Now and then, for no reason at all, a little mark pops up over its head.
  // Checked once per decision (every few seconds), so about once every
  // three or four minutes on average, at random.
  property string emote: ""
  readonly property var emotes: ["!", "?", "...", "!?", ":)", ":D", ":o", ";)", ":P", ":3", "^_^", "o_o", ">_<", "<3", "zzz"]
  readonly property real emoteChance: 0.03
  function maybeEmote() {
    if (demoStep >= 0 || bubbleKey !== "" || emote !== "" || Math.random() >= emoteChance) return
    showEmote(emotes[Math.floor(Math.random() * emotes.length)])
  }
  function showEmote(text) {
    emote = text
    emoteTimer.restart()
  }
  Timer { id: emoteTimer; interval: 2400; onTriggered: root.emote = "" }

  // ---- demo: everything it can do, once through, in about 40 seconds -----
  // `omarchy-shell tiedeyez.omairy demo`. Each step either flies somewhere
  // (the next step starts a moment after it lands) or waits a fixed time.
  property int demoStep: -1        // -1: not running
  property int demoPause: 600      // ms to wait after the current step's flight lands
  property bool demoLoop: false    // the next flight turns a loop
  property bool demoGlide: false   // the next flight glides early
  function demo() {
    shown = true
    if (!animate) return           // nothing to show under fullscreen or with animations off
    flight.stop(); brain.stop(); visitDelay.stop()
    bubbleKey = ""; emote = ""
    demoStep = 0
    demoRun()
  }
  function demoStop() {
    if (demoStep < 0) return
    demoStep = -1
    demoTimer.stop()
    demoLoop = false; demoGlide = false
    if (animate && !flight.running) { brain.interval = 1200; brain.restart() }
  }
  function demoAfter(ms) { demoTimer.interval = ms; demoTimer.restart() }
  function demoFly(kind, pauseMs) {
    demoPause = pauseMs
    decide(kind)
    if (!flight.running) demoAfter(300) // could not take off; move on
  }
  function demoRun() {
    switch (demoStep) {
    case 0: showEmote("!"); demoAfter(1300); break                 // hello
    case 1: demoLoop = true; demoFly("tour", 600); break           // long flight with a loop
    case 2: showEmote("?"); demoAfter(1500); break
    case 3: demoGlide = true; demoFly("tour", 500); break          // long flight with a glide
    case 4: demoFly("visit", 1200); break                          // hover by the active window
    case 5: demoFly("perch", 700); break                           // land on top of it
    case 6: showEmote("zzz"); demoAfter(4200); break               // rest, wings folded
    case 7: showEmote(":D"); demoAfter(1500); break
    case 8: demoPause = 900; poke(); break                         // a tip, then it darts away
    case 9: showEmote("<3"); demoAfter(2400); break
    default: demoStop()
    }
  }
  Timer { id: demoTimer; onTriggered: { root.demoStep++; root.demoRun() } }

  // What it shows when clicked: a random Omarchy tip (i18n tip.1 .. tip.N).
  readonly property int tipCount: 126
  function pickLine() {
    return "tip." + (1 + Math.floor(Math.random() * tipCount))
  }

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
      ty = rect.y - fh * (Sprite.BODY_Y + Sprite.BODY_N) / Sprite.GRID // the body sits on the edge
      speed = 110
      hold = rand(8000, 16000)
    } else if (next === "visit" && rect) {
      // Somewhere just around the window's edges.
      var side = Math.floor(Math.random() * 3)
      if (side === 0) { tx = rand(rect.x, rect.x + rect.w - fw); ty = rect.y - fh - rand(4, 60) }
      else if (side === 1) { tx = rect.x - fw - rand(4, 50); ty = rand(rect.y, rect.y + rect.h * 0.6) }
      else { tx = rect.x + rect.w + rand(4, 50); ty = rand(rect.y, rect.y + rect.h * 0.6) }
      hold = rand(2500, 6000)
    } else if (next === "tour") {
      // Across to the other side of the screen: room for a loop or a glide.
      tx = fairy.x + fw / 2 < W / 2 ? b.x1 - fw - rand(80, 200) : b.x0 + rand(80, 200)
      ty = rand(b.y0 + (b.y1 - b.y0) * 0.25, b.y0 + (b.y1 - b.y0) * 0.6)
      speed = 170
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
      // Bounce off the edges instead of sliding along them.
      if (tx < b.x0) tx = 2 * b.x0 - tx
      else if (tx > b.x1 - fw) tx = 2 * (b.x1 - fw) - tx
      if (ty < b.y0) ty = 2 * b.y0 - ty
      else if (ty > b.y1 - fh) ty = 2 * (b.y1 - fh) - ty
    }

    tx = clamp(tx, b.x0, b.x1 - fw)
    ty = clamp(ty, b.y0, b.y1 - fh)
    mode = next
    if (!forced) maybeEmote()

    if (!animate) {
      fairy.x = tx
      fairy.y = ty
      return
    }

    // Fly there; the brain wakes again `hold` ms after it arrives.
    flight.begin(tx, ty, speed, hold)
  }

  function poke() {
    if (!shown) return
    emote = ""
    bubbleKey = pickLine()
    // Stay put long enough to be read, then dart off.
    var hold = 2200 + 55 * strings.t(bubbleKey).length
    bubbleTimer.interval = hold
    bubbleTimer.restart()
    ring.begin()
    flight.stop()
    brain.interval = hold + 200
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
    onTriggered: {
      if (root.mode === "poked") root.decide("dart")
      else if (root.demoStep < 0) root.decide("")
    }
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
      if (root.animate && root.demoStep < 0 && root.mode !== "perch" && Math.random() < 0.4)
        visitDelay.restart()
    }
  }
  Timer { id: visitDelay; interval: 450; onTriggered: root.decide("visit") }

  onAnimateChanged: {
    if (animate) { brain.interval = 800; brain.restart() }
    else { demoStop(); flight.stop(); brain.stop() }
  }
  onTargetScreenChanged: Qt.callLater(home)

  // Pixel units that land on whole screen pixels at any monitor scale.
  readonly property real screenScale: monitor && monitor.scale > 0 ? monitor.scale : 1
  readonly property real px: Math.max(1, Math.round(2 * screenScale)) / screenScale
  readonly property real ui: Math.max(1, Math.round(2 * screenScale)) / screenScale
  function snap(v, unit) { return Math.round(v / unit) * unit }

  property int bobStep: 0
  readonly property var bobPath: [0, -1, -1, 0, 1, 1]
  Timer {
    interval: root.mode === "perch" ? 340 : 170
    repeat: true
    running: root.animate && !flight.running
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

    // ---- flight: smooth and floaty ---------------------------------------
    //
    // Nothing follows a fixed curve and nothing changes suddenly. Each frame
    // the fairy eases its velocity toward "forward at cruise speed, plus a
    // slow swing from side to side", so it travels in long lazy arcs. On top
    // of that path it floats gently up and down, and once in a while it
    // turns a little loop in the air for the fun of it. Everything fades out
    // over the last stretch, so it settles onto its target softly.
    QtObject {
      id: flight
      property bool running: false
      property real tx: 0
      property real ty: 0
      property real speed: 130      // cruise speed, px/s
      property real hold: 2000      // ms to stay after arriving
      // Position along the path, before the float and loop are added.
      property real bx: 0
      property real by: 0
      property real vx: 0
      property real vy: 0
      property real t: 0            // seconds since take-off
      // Each flight draws its own swing and float, so no two look alike.
      property real p1: 0           // swing phase
      property real p2: 0           // float phase
      property real f1: 0.35        // swing rate, Hz
      property real a1: 90          // sideways speed of the swing, px/s
      property real f2: 1.0         // float rate, Hz
      property real a2: 5           // float height, px
      // Loop-the-loop: one full turn of radius loopR, eased in and out.
      property real loopAt: -1      // time the next loop starts (-1: none this flight)
      property real loopT: -1       // progress 0..1 while looping, else -1
      property real loopR: 22
      property real loopDir: 1
      property real nextGlide: 0
      property real glideUntil: -1
      readonly property bool gliding: running && t < glideUntil
      readonly property bool hurried: running && speed > 300

      function begin(x, y, cruise, holdMs) {
        tx = x; ty = y; speed = cruise; hold = holdMs
        bx = fairy.x; by = fairy.y; vx = 0; vy = 0
        t = 0
        p1 = root.rand(0, Math.PI * 2); p2 = 0
        f1 = root.rand(0.25, 0.45)
        a1 = root.rand(60, 120) * (Math.random() < 0.5 ? -1 : 1)
        f2 = root.rand(0.8, 1.2); a2 = root.rand(3, 6)
        loopAt = root.demoLoop ? 0.8 : Math.random() < 0.22 ? root.rand(0.7, 1.6) : -1
        loopT = -1
        loopR = root.rand(16, 28); loopDir = Math.random() < 0.5 ? -1 : 1
        nextGlide = root.demoGlide ? 0.9 : root.rand(1.2, 2.6)
        root.demoLoop = false; root.demoGlide = false
        glideUntil = -1
        brain.stop()
        running = true
      }

      function stop() { running = false; vx = 0; vy = 0 }

      function arrive() {
        fairy.x = tx; fairy.y = ty
        stop()
        if (root.demoStep >= 0) { root.demoAfter(root.demoPause); return }
        brain.interval = hold
        brain.restart()
      }

      function smooth(u) { return u * u * (3 - 2 * u) }

      function step(dt) {
        t += dt
        var dx = tx - bx, dy = ty - by
        var dist = Math.sqrt(dx * dx + dy * dy)
        if ((dist < 1.5 && loopT < 0) || t > 20) { arrive(); return }
        var ux = dist > 0.01 ? dx / dist : 0, uy = dist > 0.01 ? dy / dist : 0
        var fast = hurried
        var tau = Math.PI * 2
        // 1 far from the target, easing to 0 on the final approach.
        var fade = smooth(Math.min(1, dist / 160))

        // Long lazy swing across the path.
        p1 += dt * tau * f1
        var side = a1 * Math.sin(p1) * fade * (fast ? 0.4 : 1)
        // Ease off toward the target, never quite stopping short of it.
        var want = speed * Math.min(1, dist / 150) + 12
        // Slow right down while turning a loop, so it comes out round.
        if (loopT >= 0) want *= 0.25 + 0.75 * Math.abs(Math.cos(smooth(loopT) * Math.PI))
        // A soft push away from the screen edges, so it curves back instead
        // of pressing flat against them. Off near the target, which may be
        // at an edge itself.
        var b = root.bounds(), m = 70
        var maxX = b.x1 - fairy.width, maxY = b.y1 - fairy.height
        var ex = (Math.max(0, b.x0 + m - bx) - Math.max(0, bx - (maxX - m))) * 2.5 * fade
        var ey = (Math.max(0, b.y0 + m - by) - Math.max(0, by - (maxY - m))) * 2.5 * fade
        // Gliding: wings held up, drifting down a touch.
        var sink = gliding ? 35 : 0

        // Ease the velocity toward that; firmer near the target so it settles.
        var k = (fast ? 4 : 1.9) + 4 * (1 - fade)
        vx += (ux * want - uy * side + ex - vx) * k * dt
        vy += (uy * want + ux * side + sink + ey - vy) * k * dt
        bx += vx * dt; by += vy * dt

        // Glide now and then on longer flights.
        if (t >= nextGlide && dist > 160 && !fast) {
          glideUntil = t + root.rand(0.35, 0.6)
          nextGlide = t + root.rand(1.8, 3.6)
        }

        // Float: a soft rise and fall on top of the path.
        p2 += dt * tau * f2
        var ox = 0, oy = a2 * Math.sin(p2) * fade

        // Loop: one eased turn around a small circle.
        if (loopT < 0 && loopAt >= 0 && t >= loopAt && dist > 200 && !fast) { loopT = 0; loopAt = -1 }
        if (loopT >= 0) {
          loopT += dt / 1.3
          if (loopT >= 1) loopT = -1
          else {
            var th = smooth(loopT) * tau
            // Circle starting and ending at the path, turning to one side.
            ox += loopR * (-uy * loopDir * (1 - Math.cos(th)) + ux * Math.sin(th))
            oy += loopR * (ux * loopDir * (1 - Math.cos(th)) + uy * Math.sin(th))
          }
        }

        fairy.x = root.clamp(bx + ox, b.x0, maxX)
        fairy.y = root.clamp(by + oy, b.y0, maxY)
      }
    }

    // Stepped once per display frame, only while in the air.
    FrameAnimation {
      running: flight.running && root.animate
      onTriggered: flight.step(Math.min(0.05, frameTime))
    }

    // The fairy's true (smooth) position. Everything drawn snaps to the
    // pixel grid from here, so it moves in whole sprite pixels like a
    // handheld game.
    Item {
      id: fairy
      width: Sprite.GRID * root.px
      height: Sprite.GRID * root.px
    }

    // ---- sparkle trail: square blocks, 4 steps ---------------------------
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
              // Shed from just under the body, never inside the hollow mark.
              n.x = root.snap(sprite.x + sprite.width / 2 + root.rand(-7, 7) * root.px, root.px)
              n.y = root.snap(sprite.y + (Sprite.BODY_Y + Sprite.BODY_N + root.rand(1.5, 5)) * root.px, root.px)
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
          // Square blocks that shrink as they fade: 3, 2, 2, 1 pixels.
          readonly property int side: [3, 2, 2, 1, 0][frame]
          visible: side > 0
          width: 0; height: 0
          Rectangle {
            x: -sp.side * root.px / 2; y: x
            width: sp.side * root.px; height: width
            color: sp.frame === 0 ? "white" : Qt.lighter(Color.accent, 1.6)
          }
        }
      }
    }

    // ---- the sprite ---------------------------------------------------------
    Item {
      id: sprite
      width: fairy.width
      height: fairy.height
      // Whole sprite pixels at rest; whole screen pixels in the air, so the
      // flight is smooth and the art stays crisp.
      readonly property real grid: flight.running ? 1 / root.screenScale : root.px
      x: root.snap(fairy.x, grid)
      // In the air the wingbeats do the bobbing; the gentle bob is for hovering.
      y: root.snap(fairy.y, grid) + (flight.running ? 0 : root.bobPath[root.bobStep] * root.px)

      // Click pulse: a dotted square that steps outwards.
      Canvas {
        id: ringCanvas
        property int step: -1
        readonly property int size: 45
        width: size * root.px; height: size * root.px
        x: (sprite.width - width) / 2
        y: (sprite.height - height) / 2
        renderStrategy: Canvas.Cooperative
        onPaint: {
          var ctx = getContext("2d")
          Sprite.paintRing(ctx, root.px, size, step >= 0 ? [9, 12, 15, 18, 21][step] : 0,
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
        hair: 1 / root.screenScale
        glow: Color.accent
        resting: root.mode === "perch"
        animate: root.animate
        gliding: flight.gliding
        hurried: flight.hurried
      }

      Item {
        id: hit
        anchors.centerIn: parent
        width: Sprite.BODY_N * root.px; height: Sprite.BODY_N * root.px
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.poke()
        }
      }
    }

    // ---- emote: a mark over its head, rarely ---------------------------------
    Text {
      id: emoteLabel
      visible: root.emote !== ""
      text: root.emote
      textFormat: Text.PlainText
      font.family: Style.fontFamily
      font.pixelSize: Style.font.body + 2
      font.bold: true
      color: Qt.lighter(Color.accent, 1.3)
      style: Text.Outline
      styleColor: Color.background
      x: Math.round(sprite.x + sprite.width / 2 - width / 2)
      y: Math.round(sprite.y + 7 * root.px - height)
    }

    // ---- speech: a card in the style of Omarchy's own popups, typed out ---
    Rectangle {
      id: box
      readonly property string full: root.bubbleKey !== "" ? strings.t(root.bubbleKey) : ""
      property int chars: 0
      readonly property int pad: 10
      readonly property int maxText: 280
      readonly property real gap: 3 * root.px
      readonly property real bodyTop: sprite.y + Sprite.BODY_Y * root.px
      readonly property real bodyBottom: sprite.y + (Sprite.BODY_Y + Sprite.BODY_N) * root.px
      readonly property var area: root.bounds()

      visible: full !== ""
      color: Color.popups.background
      border.color: Color.popups.border
      border.width: Math.max(1, Style.space(2))
      radius: Style.cornerRadius
      width: sizer.width + pad * 2
      height: sizer.height + pad * 2
      x: Math.round(root.clamp(sprite.x + sprite.width / 2 - width / 2, area.x0, Math.max(area.x0, area.x1 - width)))
      // Above the body; below it when there is no room above.
      y: Math.round(bodyTop - gap - height >= area.y0 ? bodyTop - gap - height : bodyBottom + gap)

      TextMetrics {
        id: metrics
        font: label.font
        text: box.full
      }

      // Lays out the whole line so the card has its final size from the
      // first character and does not grow while typing.
      Text {
        id: sizer
        visible: false
        textFormat: Text.PlainText
        font: label.font
        wrapMode: Text.WordWrap
        width: Math.ceil(Math.min(box.maxText, metrics.width + 1))
        text: box.full
      }

      Text {
        id: label
        x: box.pad
        y: box.pad
        width: sizer.width
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Color.popups.text
        font.family: Style.fontFamily
        font.pixelSize: Style.font.body
        text: box.full.substring(0, box.chars)
      }

      onFullChanged: {
        typer.stop()
        chars = 0
        if (full === "") return
        if (root.reducedMotion) chars = full.length
        else typer.restart()
      }

      Timer {
        id: typer
        interval: 28
        repeat: true
        onTriggered: {
          if (box.chars < box.full.length) box.chars++
          else stop()
        }
      }
    }
  }

  ShellIpc {
    target: "tiedeyez.omairy"
    function show(): void { root.shown = true }
    function hide(): void { root.shown = false }
    function demo(): void { root.demo() }
    function toggle(): void { root.shown = !root.shown }
    function poke(): void { root.poke() }
    function summon(): void {
      if (!root.shown) root.shown = true
      root.decide("visit")
    }
  }
}
