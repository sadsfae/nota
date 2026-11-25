# Changelog

All notable changes to Nota are documented here. Nota follows
[Semantic Versioning](https://semver.org/): tags are `vMAJOR.MINOR.PATCH`,
cut from `main`, and the manifest `version` field matches the current tag.
Commit messages use Conventional Commits (`feat:`, `fix:`, `chore:`, `doc:`).

## [Unreleased]

## [0.4.1] - 2026-11-25

### Fixed
- Cancelling the file chooser opened by `Browse` no longer reopens it in an
  endless loop: the chooser is now started with `exec()` and the button is
  disabled while it runs.

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
