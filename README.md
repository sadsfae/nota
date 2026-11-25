# Nota

A simple, Quickshell-based note-taking widget that lives in the Omarchy top bar.
Click its icon or press a hotkey and a small floating note appears. It autosaves
as you type and remembers where you put it.

Nota is an [Omarchy](https://omarchy.org/) shell plugin. It is not a full editor
and it does not manage a collection of notes. It is a scratch note with a
default home, exactly where you left it.

## Features

- In the top bar, shown with a hand-writing-note icon. Left-click toggles the
  note.
- Floating card that can be grabbed by its top grip or Ctrl/Super+dragged
anywhere, the same feel as Omacalc, and resized from any corner. Its position
and size are remembered.
- Pastes and copies like a normal editor: `Ctrl+V` and `Ctrl+Shift+V` paste,
  middle-click pastes the primary selection, and `Ctrl+C` (or selecting with
  the middle button) copies.
- Autosaves while you type (debounced) and again when the card closes.
- Save-as offers a `Browse` button that opens Omarchy's file chooser, so the
  destination follows whatever file manager the desktop registers.
- Writes to one configured default file. A minimal save-as dialog lets you type
  a different path, save there, and optionally make it the new default.
- Follows the active Omarchy theme (colours, corner radius) live.
- Lightweight: one Quickshell plugin, no daemon, no network, no telemetry.
- Settings live at `~/.config/omarchy/nota.json`, outside the plugin, so they
  survive updates and uninstall.

## Requirements

- Omarchy with the Quickshell shell (Omarchy 4 / Quattro or later).
- The `hyprland` and `xdg-desktop-portal` components Omarchy already ships.

## Install

```sh
omarchy plugin add https://github.com/sadsfae/nota.git --enable
```

A plugin cannot ship a Hyprland binding, so add the hotkey yourself. Check for
a free chord first:

```sh
omarchy menu keybindings --print
```

Then add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + N", "Nota", "omarchy-shell -q shell toggle io.github.sadsfae.nota")
```

`SUPER + N` is the default used by several other capture plugins, so confirm it
is free. If it is taken, `hl.unbind(...)` first or pick another chord.

## Usage

- Click the Nota icon in the top bar, or press the hotkey, to open the note.
- Type. The note autosaves shortly after you pause and again when it closes.
- Move the card by dragging the grip at the top, or hold `Ctrl` (or `Super`)
  and drag anywhere on it, like a Hyprland floating window.
- Resize the card by dragging any of its four corners.
- `Ctrl+C` copies a selection, `Ctrl+V` and `Ctrl+Shift+V` paste, and
  middle-click pastes the current selection. Selection is always on.
- Click outside the card or press `Esc` to close it.
- The footer shows the file you are writing, an `Unsaved` marker while changes
  are pending, and a `Save as...` button that opens the save-as dialog.
- In the save-as dialog, type a destination path or press `Browse` to pick one
  with Omarchy's file chooser, tick `Use as default` to make it the file Nota
  always writes to, and press `Save`.

## Configuration

`~/.config/omarchy/nota.json`:

```json
{
  "defaultPath": "~/Documents/Notes/Inbox.md",
  "autosaveMs": 400,
  "rememberPosition": true
}
```

| Key | Default | Meaning |
| --- | --- | --- |
| `defaultPath` | `~/Documents/Notes/Inbox.md` | The file the note autosaves to. `~` and `$HOME` expand; missing parent directories are created on first write. |
| `autosaveMs` | `400` | Delay after the last keystroke before an autosave (clamped to 0-10000). |
| `rememberPosition` | `true` | Restore the card's last position and size. |

Change `defaultPath` to send the note somewhere else. The `Save as...` dialog
updates this key for you when you tick `Use as default`.

## Save behaviour

- The note is stored as plain text (Markdown-aware) in a single file.
- Writes are atomic (write to a temporary file, then rename) and the file is
  size-capped at 256 KiB, so a runaway paste cannot corrupt or balloon a note.
- A `defaultPath` that is a symlink is replaced by a regular file on the first
  write, because writes are atomic (temp file plus rename). Point it at the
  real file if it is linked from a synced folder.
- The card never truncates or reorders existing content. If the destination
  already has text and you ask Nota to write there, the card loads it and your
  edit replaces the whole buffer, as a single-file scratch note should.

## Development

Validate and test locally:

```sh
bash tests/test-release.sh
```

This runs the Node logic tests, JSON and SVG parse checks, and (when the
`omarchy` CLI is on `PATH`) `omarchy plugin validate .`.

The QML logic that does not touch a surface lives in `omarchy/NoteStore.js` and
is covered by `tests/note-store.test.js`, so it runs under Node without a
compositor.

## License

[GPL-3.0-or-later](LICENSE)
