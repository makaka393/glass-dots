import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    // окно выше самого бара — чтобы острова могли раскрываться вниз.
    // Пустые места прозрачны и пропускают клики (mask).
    implicitHeight: 320
    exclusiveZone: Theme.barHeight + Theme.outer + 2
    color: "transparent"

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region {
        Region { item: content.leftGroup }
        Region { item: content.centerGroup }
        Region { item: content.rightGroup }
    }

    BarContent {
        id: content
        anchors.fill: parent
        barWindow: bar
    }
}
