import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "NoteStore.js" as Store

// Nota floating note surface. A layer-shell card that can be dragged anywhere
// on the monitor (grip, or Ctrl/Super+drag), resized from any corner, pastes
// and copies with the usual shortcuts, autosaves to the configured default
// file, and offers a minimal save-as dialog.
//
// The shell drives show/hide through this plugin's own open()/close() and its
// `opened` property: summon() calls open(), hide() calls close(), and
// isPluginOpen() reads `opened`. Do not rely on anything else to show the card.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "io.github.sadsfae.nota"
  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: home + "/.config/omarchy/nota.json"
  readonly property string positionPath: home + "/.local/state/omarchy/nota-position.json"

  readonly property color textColor: Color.popups.text
  readonly property color surfaceColor: Color.popups.background
  readonly property color borderColor: Color.popups.border
  readonly property color accentColor: Color.accent

  readonly property int minCardWidth: 220
  readonly property int minCardHeight: 140

  property bool opened: false
  property bool restoring: false
  property bool saveAsOpen: false
  property bool saveError: false

  property string draft: ""
  property bool ready: false
  property bool dirty: false

  // Revision guards the dirty flag: a completed save only clears edits made
  // before it started, so keystrokes typed while a write is in flight are not
  // silently dropped.
  property int revision: 0
  property int pendingRev: -1

  property string defaultPath: ""
  property int autosaveMs: 400
  property bool rememberPosition: true

  property real cardX: 0
  property real cardY: 0
  property int cardWidth: 480
  property int cardHeight: 340

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

  function dismiss() {
    root.close()
  }

  function parseLoose(raw) {
    try { return JSON.parse(String(raw || "")) || {} } catch (e) { return {} }
  }

  function attach() {
    root.saveError = false
    configFile.reload()
    positionFile.reload()
  }

  function applyConfig(raw) {
    var cfg = Store.normalizeConfig(root.parseLoose(raw), root.home)
    root.defaultPath = cfg.defaultPath
    root.autosaveMs = cfg.autosaveMs
    root.rememberPosition = cfg.rememberPosition
    root.ready = true
    noteFile.reload()
  }

  function saveConfig() {
    configFile.setText(JSON.stringify({
      defaultPath: root.defaultPath,
      autosaveMs: root.autosaveMs,
      rememberPosition: root.rememberPosition
    }, null, 2))
  }

  function applyPosition(raw) {
    var info = root.parseLoose(raw)
    if (info.w) root.cardWidth = Math.max(root.minCardWidth, Number(info.w) || root.cardWidth)
    if (info.h) root.cardHeight = Math.max(root.minCardHeight, Number(info.h) || root.cardHeight)
    var x = Number(info.x)
    var y = Number(info.y)
    if (!isFinite(x)) x = Style.gapsOut
    if (!isFinite(y)) y = Style.gapsOut
    // Clamp only once the layer surface has a size; otherwise trust the saved
    // position so a not-yet-laid-out surface does not reset it to the margin.
    if (panel.width > 0 && panel.height > 0) {
      var point = Store.clampPosition(x, y, panel.width, panel.height, root.cardWidth, root.cardHeight, Style.gapsOut)
      root.cardX = point.x
      root.cardY = point.y
    } else {
      root.cardX = x
      root.cardY = y
    }
  }

  function persistPosition() {
    if (!root.rememberPosition) return
    positionFile.setText(JSON.stringify({
      x: Math.round(root.cardX), y: Math.round(root.cardY),
      w: root.cardWidth, h: root.cardHeight
    }))
  }

  function moveCard(x, y) {
    var point = Store.clampPosition(x, y, panel.width, panel.height, root.cardWidth, root.cardHeight, Style.gapsOut)
    root.cardX = point.x
    root.cardY = point.y
    root.persistPosition()
  }

  function resizeFrom(corner, dx, dy) {
    var nw = root.cardWidth
    var nh = root.cardHeight
    var nx = root.cardX
    var ny = root.cardY
    if (corner === "br") { nw += dx; nh += dy }
    else if (corner === "bl") { nw -= dx; nx += dx; nh += dy }
    else if (corner === "tr") { nw += dx; nh -= dy; ny += dy }
    else if (corner === "tl") { nw -= dx; nx += dx; nh -= dy; ny += dy }
    nw = Math.max(root.minCardWidth, nw)
    nh = Math.max(root.minCardHeight, nh)
    var point = Store.clampPosition(nx, ny, panel.width, panel.height, nw, nh, Style.gapsOut)
    root.cardX = point.x
    root.cardY = point.y
    root.cardWidth = Math.round(nw)
    root.cardHeight = Math.round(nh)
    root.persistPosition()
  }

  function noteEdited() {
    root.revision += 1
    root.dirty = true
    saveTimer.restart()
  }

  function flush() {
    if (!root.ready || !root.dirty) return
    root.pendingRev = root.revision
    noteFile.setText(Store.clampText(root.draft))
  }

  function flushNow() {
    if (!root.ready) return
    root.saveAsOpen = false
    if (root.dirty) {
      root.pendingRev = root.revision
      noteFile.setText(Store.clampText(root.draft))
    }
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
    root.pendingRev = root.revision
    if (target !== root.notePath) {
      exportFile.path = target
      exportFile.setText(Store.clampText(root.draft))
    } else {
      noteFile.setText(Store.clampText(root.draft))
    }
    if (makeDefault && target !== root.defaultPath) {
      root.defaultPath = target
      root.saveConfig()
    }
  }

  FileView {
    id: configFile
    path: root.configPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
  }

  FileView {
    id: positionFile
    path: root.positionPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyPosition(text())
    onLoadFailed: {}
  }

  FileView {
    id: noteFile
    path: root.notePath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.restoring = true
      root.draft = Store.clampText(text())
      editor.text = root.draft
      root.restoring = false
      root.dirty = false
      root.saveError = false
    }
    onLoadFailed: {
      root.restoring = true
      root.draft = ""
      editor.text = ""
      root.restoring = false
      root.dirty = false
    }
    onSaved: if (root.revision === root.pendingRev) root.dirty = false
    onSaveFailed: function(error) { root.saveError = true }
  }

  FileView {
    id: exportFile
    atomicWrites: true
    printErrors: false
    onSaved: if (root.revision === root.pendingRev) root.dirty = false
    onSaveFailed: function(error) { root.saveError = true }
  }

  Timer {
    id: saveTimer
    interval: root.autosaveMs
    onTriggered: root.flush()
  }

  readonly property var activeScreen: {
    var mon = Hyprland.focusedMonitor
    var screens = Quickshell.screens || []
    if (mon) {
      for (var i = 0; i < screens.length; i++) {
        if (String(screens[i].name || "") === String(mon.name || "")) return screens[i]
      }
    }
    return screens.length ? screens[0] : null
  }

  PanelWindow {
    id: panel
    screen: root.activeScreen
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nota"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Click outside the card to dismiss. The card is declared after this, so
    // it sits on top and its clicks do not reach here.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      x: root.cardX
      y: root.cardY
      radius: Math.max(0, Style.cornerRadius)
      color: root.surfaceColor
      borderSpec: Border.flat(root.borderColor, 1)
      padding: Style.space(6)

      // Ctrl/Super + drag moves the whole card, like a Hyprland floating
      // window. Only activates with the modifier, so text editing is untouched.
      DragHandler {
        id: moveDrag
        acceptedModifiers: Qt.ControlModifier | Qt.MetaModifier
        property real startX: 0
        property real startY: 0
        onActiveChanged: if (active) { moveDrag.startX = root.cardX; moveDrag.startY = root.cardY }
        onTranslationChanged: if (active) root.moveCard(moveDrag.startX + translation.x, moveDrag.startY + translation.y)
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        // Drag grip.
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(12)

          MouseArea {
            id: dragHandle
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real pressPointerX: 0
            property real pressPointerY: 0
            property real pressCardX: 0
            property real pressCardY: 0

            onPressed: function(mouse) {
              dragHandle.pressPointerX = mouse.x
              dragHandle.pressPointerY = mouse.y
              dragHandle.pressCardX = root.cardX
              dragHandle.pressCardY = root.cardY
            }
            onPositionChanged: function(mouse) {
              if (dragHandle.pressed) {
                root.moveCard(
                  dragHandle.pressCardX + (mouse.x - dragHandle.pressPointerX),
                  dragHandle.pressCardY + (mouse.y - dragHandle.pressPointerY)
                )
              }
            }
          }

          RowLayout {
            anchors.fill: parent
            spacing: Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: root.noteName
              color: root.textColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideMiddle
              Layout.fillWidth: true
            }

            Text {
              textFormat: Text.PlainText
              visible: root.dirty && !root.saveError
              text: qsTr("Unsaved")
              color: root.accentColor
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              textFormat: Text.PlainText
              visible: root.saveError
              text: qsTr("Save failed")
              color: Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Button {
              text: qsTr("Save as...")
              flat: true
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              onClicked: root.startSaveAs()
            }
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

      // Corner resize handles. Declared after the content so they sit on top.
      // Each drags the matching edge/corner and clamps to the monitor.
      MouseArea {
        anchors { left: parent.left; bottom: parent.bottom }
        width: 18; height: 18
        cursorShape: Qt.SizeBDiagCursor
        property real px: 0; property real py: 0
        onPressed: function(m) { px = m.x; py = m.y }
        onPositionChanged: function(m) { if (pressed) root.resizeFrom("bl", m.x - px, m.y - py) }
      }
      MouseArea {
        anchors { right: parent.right; bottom: parent.bottom }
        width: 18; height: 18
        cursorShape: Qt.SizeFDiagCursor
        property real px: 0; property real py: 0
        onPressed: function(m) { px = m.x; py = m.y }
        onPositionChanged: function(m) { if (pressed) root.resizeFrom("br", m.x - px, m.y - py) }
      }
      MouseArea {
        anchors { left: parent.left; top: parent.top }
        width: 18; height: 18
        cursorShape: Qt.SizeFDiagCursor
        property real px: 0; property real py: 0
        onPressed: function(m) { px = m.x; py = m.y }
        onPositionChanged: function(m) { if (pressed) root.resizeFrom("tl", m.x - px, m.y - py) }
      }
      MouseArea {
        anchors { right: parent.right; top: parent.top }
        width: 18; height: 18
        cursorShape: Qt.SizeBDiagCursor
        property real px: 0; property real py: 0
        onPressed: function(m) { px = m.x; py = m.y }
        onPositionChanged: function(m) { if (pressed) root.resizeFrom("tr", m.x - px, m.y - py) }
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
