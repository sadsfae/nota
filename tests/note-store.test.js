"use strict";

var assert = require("assert");
var Store = require("../NoteStore.js");

var failures = 0;
function test(name, fn) {
  try {
    fn();
    console.log("ok - " + name);
  } catch (e) {
    failures += 1;
    console.error("FAIL - " + name + ": " + e.message);
  }
}

test("expandPath leaves absolute paths alone", function () {
  assert.strictEqual(Store.expandPath("/home/w", "/tmp/x.md"), "/tmp/x.md");
});
test("expandPath expands ~", function () {
  assert.strictEqual(Store.expandPath("/home/w", "~/x.md"), "/home/w/x.md");
});
test("expandPath expands $HOME", function () {
  assert.strictEqual(Store.expandPath("/home/w", "$HOME/x.md"), "/home/w/x.md");
});
test("expandPath defaults to the inbox note", function () {
  assert.strictEqual(
    Store.expandPath("/home/w", ""),
    "/home/w/Documents/Notes/Inbox.md"
  );
});
test("normalizeAutosaveMs clamps to [0,10000] and defaults to 400", function () {
  assert.strictEqual(Store.normalizeAutosaveMs(-5), 400);
  assert.strictEqual(Store.normalizeAutosaveMs(99999), 10000);
  assert.strictEqual(Store.normalizeAutosaveMs(700), 700);
});
test("normalizeConfig applies defaults", function () {
  var c = Store.normalizeConfig({}, "/home/w");
  assert.strictEqual(c.defaultPath, "/home/w/Documents/Notes/Inbox.md");
  assert.strictEqual(c.autosaveMs, 400);
  assert.strictEqual(c.rememberPosition, true);
});
test("normalizeConfig honours explicit values", function () {
  var c = Store.normalizeConfig(
    { defaultPath: "~/n.md", autosaveMs: 250, rememberPosition: false },
    "/home/w"
  );
  assert.strictEqual(c.defaultPath, "/home/w/n.md");
  assert.strictEqual(c.autosaveMs, 250);
  assert.strictEqual(c.rememberPosition, false);
});
test("clampText caps length at MAX_BYTES", function () {
  var s = "x".repeat(Store.MAX_BYTES + 50);
  assert.strictEqual(Store.clampText(s).length, Store.MAX_BYTES);
});
test("clampText counts UTF-8 bytes for multi-byte text", function () {
  var out = Store.clampText("\u00e9".repeat(300000));
  assert.strictEqual(out.length, Math.floor(Store.MAX_BYTES / 2));
});
test("clampText does not split a surrogate pair", function () {
  var out = Store.clampText("a".repeat(Store.MAX_BYTES - 1) + "\ud83d\ude00");
  assert.strictEqual(out, "a".repeat(Store.MAX_BYTES - 1));
});
test("clampPosition keeps the card on screen", function () {
  var p = Store.clampPosition(-100, 9999, 1920, 1080, 460, 320, 12);
  assert.strictEqual(p.x, 12);
  assert.strictEqual(p.y, 1080 - 320 - 12);
});
test("clampPosition passes through an in-bounds position", function () {
  var p = Store.clampPosition(200, 100, 1920, 1080, 460, 320, 12);
  assert.strictEqual(p.x, 200);
  assert.strictEqual(p.y, 100);
});
test("noteName returns the basename", function () {
  assert.strictEqual(Store.noteName("/a/b/Inbox.md"), "Inbox.md");
});
test("needsWrite is false for equal text and true for a change", function () {
  assert.strictEqual(Store.needsWrite("hello", "hello"), false);
  assert.strictEqual(Store.needsWrite("hello", "hell"), true);
  assert.strictEqual(Store.needsWrite("", ""), false);
  assert.strictEqual(Store.needsWrite("new", ""), true);
});

test("needsWrite clamps the draft before comparing", function () {
  var big = "x".repeat(Store.MAX_BYTES + 10);
  assert.strictEqual(Store.needsWrite(big, Store.clampText(big)), false);
  assert.strictEqual(Store.needsWrite("x".repeat(Store.MAX_BYTES - 1), Store.clampText(big)), true);
});

test("noteDirectory returns the parent directory", function () {
  assert.strictEqual(Store.noteDirectory("/a/b/Inbox.md"), "/a/b");
});

if (failures) {
  console.error("\n" + failures + " test(s) failed");
  process.exit(1);
} else {
  console.log("\nall tests passed");
}
