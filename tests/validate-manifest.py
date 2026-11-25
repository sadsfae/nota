#!/usr/bin/env python3
"""Validate the Nota manifest and its entry points, without Omarchy.

Runs in CI where the omarchy CLI is not installed. Checks required fields,
known kinds, and that every entry point file exists.
"""
import json
import os
import sys

REQUIRED = ["schemaVersion", "id", "name", "version", "kinds", "entryPoints"]
KNOWN_KINDS = {"bar-widget", "panel", "overlay", "menu", "bar", "service"}


def fail(msg):
    print("manifest error: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    manifest = json.load(open("manifest.json"))
    for key in REQUIRED:
        if key not in manifest:
            fail("missing required field: " + key)

    if not isinstance(manifest["kinds"], list) or not manifest["kinds"]:
        fail("kinds must be a non-empty list")
    for kind in manifest["kinds"]:
        if kind not in KNOWN_KINDS:
            fail("unknown kind: " + str(kind))

    entry_points = manifest["entryPoints"]
    if not isinstance(entry_points, dict) or not entry_points:
        fail("entryPoints must be a non-empty object")
    for kind, path in entry_points.items():
        if not os.path.isfile(path):
            fail("entry point file missing: " + str(path))

    print("manifest OK")


if __name__ == "__main__":
    main()
