// Nota model logic for io.github.sadsfae.nota.
//
// Plain JS so it is testable under Node. The QML layer owns the layer-shell
// surface, the drag grip, and input focus. The only persisted content is the
// note file and the small config at ~/.config/omarchy/nota.json.

var MAX_BYTES = 256 * 1024;
var DEFAULT_PATH = "/Documents/Notes/Inbox.md";

// Resolve a user path against $HOME. Tilde, $HOME, and relative forms all
// resolve; an absolute path passes through untouched.
function expandPath(home, path) {
  var h = String(home || "").replace(/\/$/, "");
  var p = String(path || "").trim();
  if (!p) return h + DEFAULT_PATH;
  if (p === "~") return h;
  if (p.indexOf("~/") === 0) return h + p.slice(1);
  if (p.indexOf("$HOME/") === 0) return h + p.slice(5);
  if (p.charAt(0) === "/") return p;
  return h + "/" + p;
}

function normalizeAutosaveMs(value) {
  var n = Number(value);
  if (!isFinite(n) || n < 0) return 400;
  return Math.min(Math.max(n, 0), 10000);
}

function normalizeConfig(raw, home) {
  raw = raw || {};
  return {
    defaultPath: expandPath(home, raw.defaultPath),
    autosaveMs: normalizeAutosaveMs(raw.autosaveMs),
    rememberPosition: raw.rememberPosition !== false
  };
}

function utf8Length(str) {
  var bytes = 0;
  for (var i = 0; i < str.length; i++) {
    var c = str.charCodeAt(i);
    if (c < 0x80) bytes += 1;
    else if (c < 0x800) bytes += 2;
    else if (c < 0xD800 || c >= 0xE000) bytes += 3;
    else { bytes += 4; i += 1; }
  }
  return bytes;
}

// Whether the note needs a write: compare the clamped draft against what is
// known to be on disk. Equal text needs no write (and FileView.setText would
// no-op without emitting saved(), so callers must not rely on that signal).
function needsWrite(text, savedText) {
  return clampText(text) !== savedText;
}

// Truncate to the largest prefix within MAX_BYTES of UTF-8, without splitting a
// surrogate pair. MAX_BYTES is a byte cap, so CJK and emoji count more than
// once.
function clampText(text) {
  var s = String(text || "");
  if (utf8Length(s) <= MAX_BYTES) return s;
  var bytes = 0;
  var end = 0;
  var i = 0;
  while (i < s.length) {
    var c = s.charCodeAt(i);
    var n;
    if (c < 0x80) n = 1;
    else if (c < 0x800) n = 2;
    else if (c < 0xD800 || c >= 0xE000) n = 3;
    else n = 4;
    if (bytes + n > MAX_BYTES) break;
    bytes += n;
    if (n === 4) { end = i + 2; i += 2; }
    else { end = i + 1; i += 1; }
  }
  return s.slice(0, end);
}

// Clamp a top-left position so a card of cardW x cardH stays entirely on a
// viewport of viewportW x viewportH, leaving `margin` (default Style.gapsOut)
// on each side.
function clampPosition(x, y, viewportW, viewportH, cardW, cardH, margin) {
  var m = Number(margin);
  if (!isFinite(m) || m < 0) m = 12;
  var vw = Number(viewportW) || 0;
  var vh = Number(viewportH) || 0;
  var cw = Number(cardW) || 0;
  var ch = Number(cardH) || 0;
  var maxX = Math.max(m, vw - cw - m);
  var maxY = Math.max(m, vh - ch - m);
  var cx = Number(x);
  var cy = Number(y);
  if (!isFinite(cx)) cx = m;
  if (!isFinite(cy)) cy = m;
  return { x: Math.min(Math.max(cx, m), maxX), y: Math.min(Math.max(cy, m), maxY) };
}

// Basename for the footer, so the user sees which file they are writing.
function noteName(path) {
  var p = String(path || "").replace(/\/$/, "");
  var slash = p.lastIndexOf("/");
  return slash > 0 ? p.slice(slash + 1) : p;
}

function noteDirectory(path) {
  var p = String(path || "").replace(/\/$/, "");
  var slash = p.lastIndexOf("/");
  return slash > 0 ? p.slice(0, slash) : "";
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_BYTES: MAX_BYTES,
    DEFAULT_PATH: DEFAULT_PATH,
    expandPath: expandPath,
    needsWrite: needsWrite,
    normalizeAutosaveMs: normalizeAutosaveMs,
    normalizeConfig: normalizeConfig,
    clampText: clampText,
    clampPosition: clampPosition,
    noteName: noteName,
    noteDirectory: noteDirectory
  };
}
