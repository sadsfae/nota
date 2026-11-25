import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Nota bar icon. Left-click toggles the floating note overlay. The icon is the
// plugin's own hand-writing-note SVG. The overlay owns the open state, so this
// icon makes no claim about it: it is a toggle, not an open/closed indicator.
//
// Rooted on BarWidget (the base every omarchy bar widget extends), not Panel.
BarWidget {
  id: root
  moduleName: "io.github.sadsfae.nota"

  readonly property string pluginId: "io.github.sadsfae.nota"
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property string assetPath: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/" + root.pluginId + "/assets/nota.svg"

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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
      Image {
        width: 24
        height: 24
        source: "file://" + root.assetPath
        fillMode: Image.PreserveAspectFit
        smooth: true
      }
    }

    onPressed: function(buttonCode) { root.toggle() }
  }
}
