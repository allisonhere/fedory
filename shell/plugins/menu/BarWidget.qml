import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "fedory.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\ue900"
    fontFamily: "fedory"
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("fedory-shell shell toggle fedory.menu '{\"menu\":\"root\"}'")
    }
  }
}
