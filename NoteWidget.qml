import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Commons
import qs.Ui

// Nota bar icon. Left-click toggles the floating note overlay. The icon is the
// plugin's own hand-writing-note SVG, tinted to the bar foreground so it
// follows the active theme. The overlay owns the open state, so this icon makes
// no claim about it: it is a toggle, not an open/closed indicator.
Panel {
  id: root
  moduleName: "io.github.sadsfae.nota"

  readonly property string pluginId: "io.github.sadsfae.nota"
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

  function toggle() {
    Quickshell.execDetached([
      root.omarchyPath + "/bin/omarchy-shell",
      "-q", "shell", "toggle", root.pluginId
    ])
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    iconComponent: Component {
      Item {
        Image {
          id: img
          anchors.fill: parent
          source: Qt.resolvedUrl("assets/nota.svg")
          fillMode: Image.PreserveAspectFit
          smooth: true
        }

        ColorOverlay {
          anchors.fill: parent
          source: img
          color: root.bar ? root.bar.foreground : Color.foreground
        }
      }
    }

    onPressed: function(buttonCode) { root.toggle() }
  }
}
