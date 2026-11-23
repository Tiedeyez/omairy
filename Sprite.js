.pragma library

// Pixel art for OmAiry.
//
// The sprite is a 37x37 grid. The body is the Omarchy icon mark, a hollow 15x15
// outline in the middle; the wings are stair-stepped blocks made of right angles
// like the mark itself. Wing maps are the LEFT wing (10 columns) and are
// mirrored for the right. Everything is coloured at paint time from the
// theme, so the art carries palette indices, not colours:
//   wings: o outline, w membrane, h highlight
//   body:  # stroke (accent), . channel (empty, see-through)

var GRID = 37
var BODY_X = 11  // top-left of the 15x15 body
var BODY_Y = 11
var BODY_N = 15
var WING_X = 1   // left wing's first column
var C = 18.5     // centre of the grid (pixel-edge coordinates)

// The Omarchy icon mark, sampled from Omarchy's own icon.png (15x15).
var BODY = [
  "###############",
  "#......#......#",
  "#.######...##.#",
  "#.#.........#.#",
  "#.#.........#.#",
  "#.#.........#.#",
  "#.#.........#.#",
  "###.........#.#",
  "#.#.........#.#",
  "#.#.........#.#",
  "#.#.........#.#",
  "#.#.........#.#",
  "#.###########.#",
  "#......#......#",
  "########.######"
]

// Three flap frames: up, mid, down. Each wing is [top row, rows].
var WINGS = [
  { upper: [2, [
      "ooooooo...",
      "ohwwwwo...",
      "owwwwwo...",
      "owwwwwo...",
      "owwwwwo...",
      "owwwwwooo.",
      "owwwwwwwo.",
      "oooowwwwo.",
      "...owwwwoo",
      "...owwwwwo",
      "...owwwwwo",
      "...ooooooo"]],
    lower: [23, [
      "...ooooooo",
      "...owwwwwo",
      "..oowwwooo",
      "..owwwwo..",
      "..oooooo.."]] },
  { upper: [5, [
      "ooooooo...",
      "ohwwwwo...",
      "owwwwwo...",
      "owwwwwooo.",
      "owwwwwwwo.",
      "oooowwwwoo",
      "...owwwwwo",
      "...owwwwwo",
      "...ooooooo"]],
    lower: [23, [
      "...ooooooo",
      "...owwwwwo",
      ".ooowwwwoo",
      ".owwwwwwo.",
      ".owwwwooo.",
      ".oooooo..."]] },
  { upper: [8, [
      "ooooooooo.",
      "ohwwwwwwo.",
      "oooowwwwoo",
      "...owwwwwo",
      "...owwwwwo",
      "...ooooooo"]],
    lower: [23, [
      "...ooooooo",
      "...owwwwwo",
      "...owwwwoo",
      ".ooowwwwo.",
      ".owwwwwwo.",
      ".owwwwooo.",
      ".owwwwo...",
      ".oooooo..."]] }
]

function dotter(ctx, px) {
  return function (i, j, color, alpha) {
    ctx.globalAlpha = alpha
    ctx.fillStyle = color
    ctx.fillRect(i * px, j * px, px, px)
  }
}

// The glow, in the style of Omarchy's block art: the mark echoes outward.
// Square frames, one sprite pixel thick, leave the mark one after another
// and travel to the edge. Each has an opening like the mark's own frames
// (bottom on one, top on the next), and each breaks up through the four
// shade textures of block characters as it goes: solid, dense, checker,
// sparse, gone (like the glyphs for full block, dark, medium, light shade).
//
// It is drawn on a finer grid than the sprite: `sub` cells per sprite pixel,
// one cell per screen pixel (the canvas works in logical units and applies
// the monitor scale itself, so a cell is px / sub units). frame: which step of the outward travel to
// draw. Each step is painted once and cached; playing them in order makes
// the light radiate. pal: { glow, glowLight } as CSS colour strings.
var GLOW_FRAMES = 16
var ECHO_GAP = 4   // sprite pixels between one frame and the next

function paintGlow(ctx, sub, px, frame, pal) {
  var n = GRID * sub
  var cell = px / sub   // one screen pixel, in the canvas's own units
  ctx.clearRect(0, 0, GRID * px, GRID * px)
  var inner = BODY_N / 2
  var reach = GRID / 2 - inner
  // Over one loop every frame moves out by two gaps, so the bottom-opening
  // and top-opening frames land back on each other.
  var shift = frame / GLOW_FRAMES * 2 * ECHO_GAP
  for (var j = 0; j < n; j++) {
    for (var i = 0; i < n; i++) {
      var x = (i + 0.5) / sub - C, y = (j + 0.5) / sub - C
      var d = Math.max(Math.abs(x), Math.abs(y))
      var e = d - inner                    // distance out from the mark
      if (e < 1) continue
      var out = e / reach
      // Which frame is this cell on, if any?
      var k = Math.round((e - shift) / ECHO_GAP)
      var thick = Math.max(1 / sub, 1 - 0.7 * out)   // thins as it travels
      if (Math.abs(e - (k * ECHO_GAP + shift)) >= thick / 2) continue
      // The opening: along the bottom side on even frames, the top on odd.
      var along = (x + d) / (2 * d)        // 0..1 across a horizontal side
      var horizontal = Math.abs(y) >= Math.abs(x)
      var even = ((k % 2) + 2) % 2 === 0
      if (horizontal && even && y > 0 && along > 0.53 && along < 0.62) continue
      if (horizontal && !even && y < 0 && along > 0.53 && along < 0.74) continue
      var on, color, alpha
      if (out < 0.3) { on = true; color = pal.glowLight; alpha = 0.95 }
      else if (out < 0.52) { on = !(i % 2 === 1 && j % 2 === 1); color = pal.glowLight; alpha = 0.85 }
      else if (out < 0.76) { on = (i + j) % 2 === 0; color = pal.glow; alpha = 0.8 }
      else { on = i % 2 === 0 && j % 2 === 0; color = pal.glow; alpha = 0.7 }
      if (!on) continue
      ctx.globalAlpha = alpha
      ctx.fillStyle = color
      ctx.fillRect(i * cell, j * cell, cell, cell)
    }
  }
  ctx.globalAlpha = 1.0
}

// Wings (one flap frame) and the body. Painted once per frame and cached.
// pal: { wingLine, wing, white, base }.
function paintBody(ctx, px, frame, pal) {
  ctx.clearRect(0, 0, GRID * px, GRID * px)
  var dot = dotter(ctx, px)

  // Wings, mirrored.
  var f = WINGS[frame % WINGS.length]
  var parts = [f.upper, f.lower]
  for (var k = 0; k < parts.length; k++) {
    var top = parts[k][0], rows = parts[k][1]
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        var ch = rows[r].charAt(c)
        if (ch === ".") continue
        var color = ch === "o" ? pal.wingLine : ch === "h" ? pal.white : pal.wing
        var alpha = ch === "o" ? 1.0 : ch === "h" ? 0.95 : 0.85
        dot(WING_X + c, top + r, color, alpha)
        dot(GRID - 1 - WING_X - c, top + r, color, alpha)
      }
    }
  }

  // Body: only the strokes of the icon mark. The channels between them are
  // left empty, so the desktop shows through.
  for (var br = 0; br < BODY_N; br++) {
    for (var bc = 0; bc < BODY_N; bc++) {
      if (BODY[br].charAt(bc) === "#") dot(BODY_X + bc, BODY_Y + br, pal.base, 1.0)
    }
  }
  ctx.globalAlpha = 1.0
}

// Grid cell of orbiting mote m (0 or 1) at orbit step t (0..15). The motes
// run around a rectangle, not an ellipse.
function mote(t, m) {
  var ang = (t / 16 + m / 2) * Math.PI * 2
  var cx = Math.cos(ang), cy = Math.sin(ang)
  var k = 1 / Math.max(Math.abs(cx), Math.abs(cy))
  return [Math.floor(C + cx * k * 17), Math.floor(C + cy * k * 10)]
}

// A dotted square ring of half-width r (grid units) for the click pulse.
function paintRing(ctx, px, size, r, color) {
  ctx.clearRect(0, 0, size * px, size * px)
  if (r <= 0) return
  var c = Math.floor(size / 2)
  ctx.fillStyle = color
  for (var t = -r; t <= r; t += 2) {
    var pts = [[c + t, c - r], [c + t, c + r], [c - r, c + t], [c + r, c + t]]
    for (var q = 0; q < 4; q++) {
      ctx.fillRect(pts[q][0] * px, pts[q][1] * px, px, px)
    }
  }
}
