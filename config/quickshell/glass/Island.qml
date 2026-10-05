import QtQuick

// «Остров» из матового стекла. Размеры меняются пружинной анимацией —
// получается эффект Dynamic Island. Blur делает Hyprland (layerrule).
Item {
    id: root

    property real targetWidth: 120
    property real targetHeight: Theme.barHeight
    property bool strong: false                    // плотнее стекло (для раскрытых карточек)
    readonly property bool hovered: hover.hovered
    readonly property real radius: Math.min(height / 2, Theme.radiusCard)
    default property alias content: inner.data

    implicitWidth: targetWidth
    implicitHeight: targetHeight
    Behavior on implicitWidth { Anim {} }
    Behavior on implicitHeight { Anim {} }

    HoverHandler { id: hover }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: root.strong ? Theme.glassStrong : Theme.glass
        border.width: 1
        border.color: Theme.glassBorder
        Behavior on color { ColorAnimation { duration: 350 } }
    }

    // блик сверху — даёт ощущение толщины стекла
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassSheen }
            GradientStop { position: 0.45; color: "transparent" }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
        clip: true
    }
}
