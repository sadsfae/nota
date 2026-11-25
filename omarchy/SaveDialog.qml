import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Minimal save-as surface. A single path field (prefilled with the current
// note file) plus a "use as default" toggle. No full file manager: the user
// types or pastes a destination. Emits `commit(path, makeDefault)`.
Item {
  id: dialog

  property string path: ""

  // Reset the field to the current note path each time the dialog opens, so a
  // previous save-as target never leaks into the next one.
  onVisibleChanged: if (visible) pathField.text = dialog.path
  property bool makeDefault: true

  signal commit(path: string, makeDefault: bool)
  signal cancel()

  Rectangle {
    anchors.fill: parent
    color: Color.menu.background
    radius: Math.max(0, Style.cornerRadius)
    border.color: Color.menu.border
    border.width: 1
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(12)
    spacing: Style.space(10)

    Text {
      textFormat: Text.PlainText
      text: qsTr("Save this note to:")
      color: Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    TextField {
      id: pathField
      Layout.fillWidth: true
      text: dialog.path
      focus: true
      color: Color.menu.text
      selectionColor: Color.accent
      placeholderText: "~/Documents/Notes/Inbox.md"
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      onAccepted: dialog.commit(pathField.text, defaultCheck.checked)
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(10)

      CheckBox {
        id: defaultCheck
        text: qsTr("Use as default")
        checked: dialog.makeDefault
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Item { Layout.fillWidth: true }

      Button {
        text: qsTr("Save")
        flat: true
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        onClicked: dialog.commit(pathField.text, defaultCheck.checked)
      }

      Button {
        text: qsTr("Cancel")
        flat: true
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        onClicked: dialog.cancel()
      }
    }
  }
}
