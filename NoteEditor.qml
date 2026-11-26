import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "NoteStore.js" as Store

// Nota floating note window. A regular toplevel window (like Omacalc), so it can
// be dragged to another monitor or workspace; Hyprland floats it via a window
// rule. The shell drives show/hide through this plugin's own open()/close() and
// its `opened` property: summon() calls open(), hide() calls close(), and
// isPluginOpen() reads `opened`.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "io.github.sadsfae.nota"
  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: home + "/.config/omarchy/nota.json"

  readonly property color textColor: Color.popups.text
  readonly property color surfaceColor: Color.popups.background
  readonly property color borderColor: Color.popups.border
  readonly property color accentColor: Color.accent

  property bool opened: false
  property bool restoring: false
  property bool saveAsOpen: false
  property bool saveError: false

  property string draft: ""
  property bool ready: false

  // dirty is computed from what is known to be on disk, so it also clears
  // when the user reverts to the last saved text without another write
  // (FileView.setText no-ops on equal content and never emits saved()).
  readonly property bool dirty: root.ready && Store.needsWrite(root.draft, root.lastSavedText)

  // Content known to be on disk for the current note path.
  property string lastSavedText: ""
  // Text handed to the in-flight noteFile / exportFile write.
  property string pendingText: ""
  property string pendingExportText: ""
  // One-shot: skip the noteFile load that races the save-as write after the
  // default path switches (setPath starts an async read of the new path).
  property bool skipNextLoad: false

  property string defaultPath: ""
  property int autosaveMs: 400
  property bool rememberPosition: true
  property int cardWidth: 680
  property int cardHeight: 440

  property string saveAsPath: ""
  property bool saveAsMakeDefault: true

  readonly property string notePath: Store.expandPath(root.home, root.defaultPath)
  readonly property string noteName: Store.noteName(root.notePath)

  // --- Shell plugin contract ----------------------------------------------
  // summon() -> open(), hide() -> close(), isPluginOpen() reads `opened`.
  function open(payloadJson) {
    root.opened = true
    root.attach()
    Qt.callLater(function() {
      if (root.opened) { editor.forceActiveFocus(); editor.cursorPosition = editor.length }
    })
  }

  function close() {
    root.flushNow()
    root.opened = false
    root.saveAsOpen = false
  }

  function dismiss() { root.close() }

  function parseLoose(raw) {
    try { return JSON.parse(String(raw || "")) || {} } catch (e) { return {} }
  }

  function attach() {
    root.saveError = false
    configFile.reload()
  }

  function applyConfig(raw) {
    var cfg = Store.normalizeConfig(root.parseLoose(raw), root.home)
    // A dirty draft means the last write failed; keep the edits. Arming
    // skipNextLoad also covers a changed defaultPath, whose repath starts a
    // load of the new path that would otherwise clobber the draft.
    if (root.dirty && cfg.defaultPath !== root.defaultPath) root.skipNextLoad = true
    root.defaultPath = cfg.defaultPath
    root.autosaveMs = cfg.autosaveMs
    root.rememberPosition = cfg.rememberPosition
    root.ready = true
    // A dirty draft means the last write failed; keep the edits instead of
    // reloading the file and losing them.
    if (!root.dirty) noteFile.reload()
  }

  function saveConfig() {
    configFile.setText(JSON.stringify({
      defaultPath: root.defaultPath,
      autosaveMs: root.autosaveMs,
      rememberPosition: root.rememberPosition
    }, null, 2))
  }

  function noteEdited() {
    saveTimer.restart()
  }

  function flush() {
    if (!root.dirty) return
    root.pendingText = Store.clampText(root.draft)
    noteFile.setText(root.pendingText)
  }

  function flushNow() {
    root.saveAsOpen = false
    root.flush()
  }

  function startSaveAs() {
    root.saveAsPath = root.notePath
    root.saveAsMakeDefault = true
    root.saveAsOpen = true
  }

  // Route the write to the typed target whether or not it becomes the default.
  function commitSaveAs(path, makeDefault) {
    var raw = String(path || "").trim()
    if (!raw) { root.saveAsOpen = false; return }
    var target = Store.expandPath(root.home, raw)
    root.saveAsOpen = false
    root.pendingExportText = Store.clampText(root.draft)
    if (target !== root.notePath) {
      // Repath first: the view's equal-content check would otherwise no-op a
      // write of unchanged text to the new path. preload: false keeps the
      // repath from starting a read that the write immediately cancels.
      exportFile.path = ""
      exportFile.path = target
      exportFile.setText(root.pendingExportText)
    } else {
      root.pendingText = root.pendingExportText
      noteFile.setText(root.pendingText)
    }
    if (makeDefault && target !== root.defaultPath) {
      // The repath starts an async read of the destination that can beat the
      // write above; skip that load so it cannot clobber the editor with the
      // destination's old (or missing) content.
      root.skipNextLoad = true
      root.defaultPath = target
      root.saveConfig()
    }
  }

  FileView {
    id: configFile
    path: root.configPath
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
  }

  FileView {
    id: noteFile
    path: root.notePath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (root.skipNextLoad) { root.skipNextLoad = false; return }
      root.restoring = true
      root.draft = Store.clampText(text())
      root.lastSavedText = root.draft
      editor.text = root.draft
      root.restoring = false
      root.saveError = false
    }
    onLoadFailed: {
      if (root.skipNextLoad) { root.skipNextLoad = false; return }
      root.restoring = true
      root.draft = ""
      root.lastSavedText = ""
      editor.text = ""
      root.restoring = false
      root.saveError = false
    }
    onSaved: {
      // The completed write is by definition pendingText; dirty recompares
      // the live draft, so a revert during the write stays dirty and resaves.
      root.lastSavedText = root.pendingText
      root.saveError = false
    }
    onSaveFailed: function(error) { root.saveError = true }
  }

  FileView {
    id: exportFile
    atomicWrites: true
    preload: false
    printErrors: false
    onSaved: {
      // A copy-only save leaves dirty alone: the default file has not
      // received these edits. Only the make-default flow, where the export
      // target has become the note path, updates the on-disk baseline.
      if (exportFile.path === root.notePath) {
        root.lastSavedText = root.pendingExportText
        root.saveError = false
      }
    }
    onSaveFailed: function(error) { root.saveError = true }
  }

  Timer {
    id: saveTimer
    interval: root.autosaveMs
    onTriggered: root.flush()
  }

  // A regular, floating window. Size is a hint; Hyprland floats it and the user
  // can drag it to any monitor or workspace. Position is remembered by the WM.
  FloatingWindow {
    id: window
    title: "Nota"
    visible: root.opened
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight
    minimumSize: Qt.size(240, 160)
    color: "transparent"

    BorderSurface {
      anchors.fill: parent
      radius: Math.max(0, Style.cornerRadius)
      color: root.surfaceColor
      borderSpec: Border.flat(root.borderColor, 1)

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.md

          Text {
            textFormat: Text.PlainText
            text: root.noteName
            color: root.textColor
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideMiddle
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            textFormat: Text.PlainText
            visible: root.dirty && !root.saveError
            text: qsTr("Unsaved")
            color: root.accentColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            textFormat: Text.PlainText
            visible: root.saveError
            text: qsTr("Save failed")
            color: Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            Layout.alignment: Qt.AlignVCenter
          }

          Button {
            text: qsTr("Save as...")
            onClicked: root.startSaveAs()
            Layout.alignment: Qt.AlignVCenter
          }

          Button {
            text: qsTr("Close")
            onClicked: root.dismiss()
            Layout.alignment: Qt.AlignVCenter
          }
        }

        TextArea {
          id: editor
          Layout.fillWidth: true
          Layout.fillHeight: true
          wrapMode: TextEdit.Wrap
          selectByMouse: true
          color: root.textColor
          selectionColor: root.accentColor
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          placeholderText: qsTr("Note")
          placeholderTextColor: Qt.alpha(root.textColor, 0.5)
          onTextChanged: {
            if (root.restoring) return
            root.draft = editor.text
            root.noteEdited()
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.dismiss()
              event.accepted = true
            } else if (event.key === Qt.Key_V
                       && (event.modifiers & Qt.ControlModifier)
                       && (event.modifiers & Qt.ShiftModifier)) {
              // Paste as plain text. The TextArea is plain, so this mirrors
              // Ctrl+V; kept explicit because Qt does not bind Ctrl+Shift+V.
              editor.paste()
              event.accepted = true
            }
          }
        }
      }

      SaveDialog {
        id: saveAs
        anchors.fill: parent
        visible: root.saveAsOpen
        path: root.saveAsPath
        makeDefault: root.saveAsMakeDefault
        onCommit: function(path, makeDefault) { root.commitSaveAs(path, makeDefault) }
        onCancel: root.saveAsOpen = false
      }
    }
  }
}
