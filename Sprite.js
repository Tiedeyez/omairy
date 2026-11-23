.pragma library

// Pixel art for the fairy, 16-bit handheld style.
//
// The sprite is a 28x28 grid. Wing maps are the LEFT half (12 columns) and are
// mirrored for the right; the body is drawn whole. Everything is coloured at
// paint time from the theme accent, so the art carries palette indices, not
// colours:
//   wings: o outline, w membrane, h highlight
//   body:  o outline, d shade, a base, L light, W white core

var GRID = 28
var OX = 2   // offset of the 24x24 art inside the 28 grid
var OY = 1
var CX = 14  // glow centre (pixel-edge coordinates)
var CY = 14

// Three flap frames: up, mid, down.
var WINGS = [
  { upper: [1, [
      "..oo........",
      ".ohho.......",
      ".ohwwo......",
      "..owwwo.....",
      "..owhwwo....",
      "...owhwwo...",
      "...owwhwo...",
      "....owwwwo..",
      ".....owwwo..",
      "......owo..."]],
    lower: [13, [
      "....ooo.....",
      "...owwwo....",
      "...owwo.....",
      "....oo......"]] },
  { upper: [4, [
      "oooo........",
      "ohhwoo......",
      "owwhwwoo....",
      ".owwwhwwoo..",
      "..oowwwwwo..",
      "....ooowwo..",
      ".......oo..."]],
    lower: [12, [
      "..ooo.......",
      ".owwwoo.....",
      "..owwwwo....",
      "...oooo....."]] },
  { upper: [7, [
      "......oooo..",
      "....oowwwo..",
      "..oowhwwo...",
      ".owhwwwo....",
      ".owwwoo.....",
      "..ooo......."]],
    lower: [13, [
      "...oo.......",
      "..owwo......",
      "..owwwo.....",
      "...oooo....."]] }
]

var BODY = [9, 8, [
  "..oooo..",
  ".oLLLao.",
  "oLWWLaao",
  "oLWWLaao",
  "oLLLaado",
  "oaaaaddo",
  ".oaaddo.",
  "..oooo.."]]

// Glow breathing: how far the rings reach on each step of the cycle.
var PULSE = [0, 0.5, 1.0, 0.5]

function hash(i, j, s) {
  var h = (i * 374761393 + j * 668265263 + s * 2147483647) | 0
  h = (h ^ (h >>> 13)) * 1274126177 | 0
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295
}

// pal: { glow, glowLight, outline, shade, base, light, white, wingLine }
// as CSS colour strings. dim: 0..1 multiplier for the glow when resting.
function dotter(ctx, px) {
  return function (i, j, color, alpha) {
    ctx.globalAlpha = alpha
    ctx.fillStyle = color
    ctx.fillRect(i * px, j * px, px, px)
  }
}

// The glow for one step of the breathing cycle. Painted once per phase and
// cached; it only changes with the theme colour or when resting.
function paintGlow(ctx, px, phase, pal, dim) {
  ctx.clearRect(0, 0, GRID * px, GRID * px)
  var p = PULSE[phase % PULSE.length]
  var dot = dotter(ctx, px)
  if (phase === 2) pal = { glow: pal.glowPeak, glowLight: pal.glowLightPeak }

  // Glow: solid core rings, then a checkerboard dither, then sparse dust,
  // the way handheld sprites faked transparency.
  for (var j = 0; j < GRID; j++) {
    for (var i = 0; i < GRID; i++) {
      var dx = i + 0.5 - CX, dy = j + 0.5 - CY
      var d = Math.sqrt(dx * dx + dy * dy)
      if (d < 5.5) dot(i, j, pal.glowLight, 0.75 * dim)
      else if (d < 7.0 + p) dot(i, j, pal.glowLight, 0.45 * dim)
      else if (d < 9.0 + p) dot(i, j, pal.glow, 0.36 * dim)
      else if (d < 11.0 + p) { if ((i + j) % 2 === 0) dot(i, j, pal.glow, 0.36 * dim) }
      else if (d < 12.8 + p) { if (i % 2 === 0 && j % 2 === 0) dot(i, j, pal.glowLight, 0.32 * dim) }
      else if (d < 13.9 && hash(i, j, phase) > 0.93) dot(i, j, pal.glowLight, 0.6 * dim)
    }
  }

  ctx.globalAlpha = 1.0
}

// Wings (one flap frame) and body. Painted once per frame and cached.
function paintBody(ctx, px, frame, pal) {
  ctx.clearRect(0, 0, GRID * px, GRID * px)
  var dot = dotter(ctx, px)

  // Wings, mirrored.
  var f = WINGS[frame % WINGS.length]
  var parts = [f.upper, f.lower]
  for (var k = 0; k < parts.length; k++) {
    var top = parts[k][0], rows = parts[k][1]
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < 12; c++) {
        var ch = rows[r].charAt(c)
        if (ch === ".") continue
        var color = ch === "o" ? pal.wingLine : ch === "h" ? pal.white : pal.wing
        var alpha = ch === "o" ? 1.0 : ch === "h" ? 0.95 : 0.72
        dot(OX + c, OY + top + r, color, alpha)
        dot(OX + 23 - c, OY + top + r, color, alpha)
      }
    }
  }

  // Body.
  var btop = BODY[0], bcol = BODY[1], brows = BODY[2]
  var map = { o: pal.outline, d: pal.shade, a: pal.base, L: pal.light, W: pal.white }
  for (var br = 0; br < brows.length; br++) {
    for (var bc = 0; bc < brows[br].length; bc++) {
      var bch = brows[br].charAt(bc)
      if (bch === ".") continue
      dot(OX + bcol + bc, OY + btop + br, map[bch], 1.0)
    }
  }
  ctx.globalAlpha = 1.0
}

// Grid cell of orbiting mote m (0 or 1) at orbit step t (0..15).
function mote(t, m) {
  var ang = (t / 16 + m / 2) * Math.PI * 2
  return [Math.floor(CX + Math.cos(ang) * 11.5), Math.floor(CY + Math.sin(ang) * 6.5)]
}

// A diamond ring of radius r (grid units) for the click chime.
function paintRing(ctx, px, size, r, color) {
  ctx.clearRect(0, 0, size * px, size * px)
  if (r <= 0) return
  var c = Math.floor(size / 2)
  ctx.fillStyle = color
  for (var t = 0; t <= r; t++) {
    var u = r - t
    var pts = [[c + t, c + u], [c - t, c + u], [c + t, c - u], [c - t, c - u]]
    for (var q = 0; q < 4; q++) {
      ctx.fillRect(pts[q][0] * px, pts[q][1] * px, px, px)
    }
  }
}

// Classic RPG text box: dark outline, light frame, accent inner line,
// notched corners. w/h in grid units.
function paintBox(ctx, u, w, h, pal) {
  ctx.clearRect(0, 0, w * u, h * u)
  function rect(x, y, rw, rh, color, alpha) {
    ctx.globalAlpha = alpha
    ctx.fillStyle = color
    ctx.fillRect(x * u, y * u, rw * u, rh * u)
  }
  // outline (notched corners)
  rect(1, 0, w - 2, h, pal.outline, 1)
  rect(0, 1, w, h - 2, pal.outline, 1)
  // frame
  rect(2, 1, w - 4, h - 2, pal.frame, 1)
  rect(1, 2, w - 2, h - 4, pal.frame, 1)
  // accent line
  rect(2, 2, w - 4, h - 4, pal.accent, 1)
  // fill
  rect(3, 3, w - 6, h - 6, pal.fill, 0.96)
  ctx.globalAlpha = 1
}
