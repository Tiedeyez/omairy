# OmAiry

A small fairy of light that hangs out on your Omarchy desktop, drawn as a
16-bit handheld style pixel sprite. It drifts around, leaves a sparkle trail,
visits the window you're working in, and sometimes perches on top of it to
rest. The glow follows your theme's accent colour. Click it and a ring of
light pulses out and it says something in a retro RPG text box.

![OmAiry perched on a window](preview.png)

## Install

    omarchy plugin add https://github.com/Tiedeyez/omairy --enable

It appears straight away on your focused monitor. No other setup.

## Remove

    omarchy plugin remove tiedeyez.omairy

To keep it installed but stop it starting with the shell:

    omarchy plugin disable tiedeyez.omairy

## Commands

    omarchy-shell tiedeyez.omairy toggle   # hide/show (this session)
    omarchy-shell tiedeyez.omairy summon   # fly to the focused window
    omarchy-shell tiedeyez.omairy poke     # say something

## Behaviour

- Lives on the Top layer, so fullscreen windows cover it, and it stops
  animating while the workspace has a fullscreen window.
- Holds still when `omarchy toggle animations` is off.
- Only a small area around the fairy takes clicks; everywhere else, clicks
  pass straight through to your windows.
- Stays out of space the bar or a dock reserves, on any edge.
- Text uses your system font (`omarchy font set`).

## Requirements

Omarchy with the Quattro shell (omarchy-shell). No other dependencies.

## What it does on your machine

See [DISCLOSURE.md](DISCLOSURE.md). Short version: it runs inside the shell,
starts no processes, reads and writes no files, and makes no network requests.

## Licence

MIT. Original artwork, drawn as text grids in `Sprite.js`.
