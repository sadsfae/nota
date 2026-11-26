# Changelog

All notable changes to Nota are documented here. Nota follows
[Semantic Versioning](https://semver.org/): tags are `vMAJOR.MINOR.PATCH`,
cut from `main`, and the manifest `version` field matches the current tag.
Commit messages use Conventional Commits (`feat:`, `fix:`, `chore:`, `doc:`).

## [Unreleased]

## [0.4.3] - 2026-11-26

### Fixed
- Undoing edits back to the previous text while an autosave write is in
  flight no longer loses the revert: the completed write updates the on-disk
  baseline unconditionally, so the reverted text is saved on the next pass.

## [0.4.2] - 2026-11-25

### Fixed
- `Browse` works again: `exec()` without arguments cannot resolve Quickshell's
  `Process.exec` overloads, so the button did nothing. The command is now
  passed explicitly.

## [0.4.1] - 2026-11-25

### Fixed
- Cancelling the file chooser opened by `Browse` no longer reopens it in an
  endless loop: the chooser is now started with `exec()` and the button is
  disabled while it runs.
- Save as with `Use as default` no longer races the note file reload: the note
  stays in the editor and the destination keeps the saved content instead of
  the editor being wiped or stale destination content overwriting the note.
- Save as without `Use as default` no longer clears the `Unsaved` marker:
  those edits still autosave to the default file.
- The `Unsaved` marker now clears when the note is reverted to the last saved
  text, and `Save as...` of unchanged text writes the target file.

## [0.4.0] - 2026-11-25

### Added
- The note is now a regular floating window (Omacalc-style), so it can be
  dragged to any monitor or virtual desktop. A Hyprland rule keeps it floating.
- A Close button that hides the note back to the top bar.
- A simple, clearly visible pencil bar icon.
- Save-as with a Browse button that opens the desktop file chooser.
- Autosave, save-as, and text editing (paste and copy) in the note.
- A top-bar toggle and a `SUPER + N` hotkey, both driving the same note.

### Changed
- Polished the note header: the title and status text are white-space
  draggable, and the Save as / Close buttons no longer ride the card's top edge.
- The note opens centred on first run; the compositor remembers its position
  and size afterwards.

### Fixed
- The bar icon now renders (BarWidget root plus a sized Image), where it
  previously never appeared.
- Removed `font` / `flat` overrides that the qs.Ui `Button` and `CheckBox`
  widgets do not accept, which had been preventing the note from loading.
