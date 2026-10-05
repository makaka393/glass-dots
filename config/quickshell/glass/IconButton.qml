import QtQuick

// Круглая кнопка-иконка с «пружинным» нажатием
Item {
    id: root
    property string icon: ""
    property int size: 36
    property int iconSize: 22
    property color color: Theme.fg
    property color bg: "transparent"
    property real fill: 1
    signal clicked()

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: mouse.pressed ? 10 : height / 2
        color: !mouse.containsMouse ? root.bg : root.bg.a > 0 ? Qt.lighter(root.bg, 1.15) : Theme.glassChip
        Behavior on radius { Anim { kind: "fast" } }
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        fill: root.fill
        color: root.color
        scale: mouse.pressed ? 0.85 : 1
        Behavior on scale { Anim { kind: "fast" } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
