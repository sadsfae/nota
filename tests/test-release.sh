#!/usr/bin/env bash
# Nota release checks: logic tests, manifest/JSON/SVG validation, and QML lint.
# Runtime dependencies: node, python3, qmllint (optional), and the omarchy CLI
# (optional). Every optional tool is skipped when it is not on PATH.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== node logic tests =="
node tests/note-store.test.js

echo "== manifest validation (no Omarchy required) =="
python3 tests/validate-manifest.py

echo "== JSON parse checks =="
for f in manifest.json config.example.json; do
  python3 -c "import json,sys; json.load(open(sys.argv[1])); print('ok   ' + sys.argv[1])" "$f"
done

echo "== SVG parse check =="
python3 -c "import xml.etree.ElementTree as ET; ET.parse('assets/nota.svg'); print('ok   assets/nota.svg')"

QML_LINT=$(command -v qmllint || true)
if [ -z "$QML_LINT" ] && [ -x /usr/lib/qt6/bin/qmllint ]; then
  QML_LINT=/usr/lib/qt6/bin/qmllint
fi
if [ -n "$QML_LINT" ] && [ -x "$QML_LINT" ]; then
  echo "== QML syntax check =="
  for f in NoteEditor.qml NoteWidget.qml SaveDialog.qml; do
    # qmllint cannot resolve the omarchy-only qs.* imports (not on PATH in CI),
    # so only hard syntax errors are fatal. Warnings are ignored.
    OUT=$("$QML_LINT" -I /usr/share/omarchy/shell "$f" 2>&1 || true)
    SYNTAX=$(echo "$OUT" | grep -iE "expected token|syntax error|: [0-9]+:[0-9]+: error:" | grep -viE "not found|unqualified|did you mean|import|failed to import|module" || true)
    if [ -n "$SYNTAX" ]; then
      echo "$SYNTAX"
      echo "QML syntax error in $f"
      exit 1
    fi
    echo "ok   $f"
  done
else
  echo "note: qmllint not found, skipping QML syntax check"
fi

if command -v omarchy >/dev/null 2>&1; then
  echo "== omarchy plugin validate =="
  omarchy plugin validate .
else
  echo "note: omarchy CLI not on PATH, skipping plugin validation"
fi

echo "all checks passed"
