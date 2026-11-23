# Disclosure

What OmAiry does on your computer, checked against the source.

## What it is and what runs it

OmAiry is an Omarchy shell plugin: QML and JavaScript loaded by
`omarchy-shell` (Quickshell). Omarchy plugins are **not sandboxed**. They run
inside the shell process with your user account's full access. OmAiry uses
very little of that access, as listed below, but nothing technically stops a
plugin from doing more, so check the claims yourself (last section).

## What it needs

Omarchy with the Quattro shell. No packages, binaries or services.

## What it writes

Nothing. It creates, changes and deletes no files. Installing and enabling it
with `omarchy plugin add` adds an entry to `~/.config/omarchy/shell.json`; the
`omarchy` command does that, not OmAiry.

## What it reads

| Source | What | When |
|---|---|---|
| Hyprland IPC (the shell's existing connection) | focused monitor, its size, scale and reserved edges (bar/dock space); the active window's position and size; whether the workspace is fullscreen | continuously, to decide where to fly |
| The shell's theme (`qs.Commons` Color/Style) | accent, foreground and background colours; system font; whether animations are on | continuously |
| Its own `i18n/en.json` | the ten short lines it says when clicked | at start |

It does not read window titles, window contents, the clipboard, keystrokes or
any file outside its own folder.

## Processes

None. It starts no subprocesses and runs no shell commands.

## Network

None. No listening sockets, no outbound connections, no telemetry, no
analytics, no auto-update.

## Input

It shows one transparent full-screen layer surface on the focused monitor. Its
input region is only the ~40 px square around the fairy; clicks anywhere else
go to the windows underneath. It never takes keyboard focus.

## IPC it exposes

`omarchy-shell tiedeyez.omairy show|hide|toggle|poke|summon`. These only move,
show or hide the fairy.

## What it does not do

No files, no processes, no network, no sound, no reading what is in your
windows, no changes to your Hyprland or shell configuration.

## Maintainer and licence

Tiedeyez, MIT licence. Original design: a generic glowing fairy. Not affiliated
with, and contains no art or text from, any game. Written with Claude Code
(Anthropic).

## Check it yourself

    grep -nE 'Process|Socket|FileView|XMLHttpRequest|Quickshell.execDetached|exec|curl|http' *.qml *.js

should print nothing. Then watch it run:

    omarchy plugin list | grep omairy
