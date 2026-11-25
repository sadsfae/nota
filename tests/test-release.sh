#!/usr/bin/env bash
# Nota release checks: logic tests, parse checks, and (when present) the
# Omarchy manifest validator. Run from any directory.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== node logic tests =="
node tests/note-store.test.js

echo "== JSON parse checks =="
for f in manifest.json omarchy/config.example.json; do
  python3 -c "import json,sys; json.load(open(sys.argv[1])); print('ok   ' + sys.argv[1])" "$f"
done

echo "== SVG parse check =="
python3 -c "import xml.etree.ElementTree as ET; ET.parse('omarchy/assets/nota.svg'); print('ok   omarchy/assets/nota.svg')"

if command -v omarchy >/dev/null 2>&1; then
  echo "== omarchy plugin validate =="
  omarchy plugin validate .
else
  echo "note: omarchy CLI not on PATH, skipping manifest validation"
fi

echo "all checks passed"
