import QtQuick
import Quickshell

// Кнопка питания. Клик — остров раскрывается вниз в меню.
// Опасные действия (выход, перезагрузка, выключение) — по второму клику.
Island {
    id: root
    objectName: "power"

    property bool open: false
    property string armed: ""           // действие, ждущее подтверждения

    strong: open
    targetWidth: open ? 250 : Theme.barHeight
    targetHeight: open ? 56 + actions.length * 44 + 8 : Theme.barHeight

    readonly property var actions: [
        { id: "lock",     icon: "lock",              label: "Заблокировать", cmd: ["hyprlock"],                               confirm: false },
        { id: "suspend",  icon: "bedtime",           label: "Сон",           cmd: ["systemctl", "suspend"],                   confirm: false },
        { id: "logout",   icon: "logout",            label: "Выйти",         cmd: ["hyprctl", "dispatch", "exit"],            confirm: true },
        { id: "reboot",   icon: "restart_alt",       label: "Перезагрузка",  cmd: ["systemctl", "reboot"],                    confirm: true },
        { id: "poweroff", icon: "power_settings_new", label: "Выключение",   cmd: ["systemctl", "poweroff"],                  confirm: true }
    ]

    function run(a) {
        if (a.confirm && armed !== a.id) {
            armed = a.id;
            disarm.restart();
            return;
        }
        open = false;
        armed = "";
        Quickshell.execDetached(a.cmd);
    }

    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }
    Timer { id: collapse; interval: 450; onTriggered: if (!root.hovered) { root.open = false; root.armed = ""; } }
    onHoveredChanged: if (!hovered && open) collapse.restart()

    // ── кнопка в баре
    Item {
        id: head
        anchors { top: parent.top; right: parent.right }
        width: Theme.barHeight
        height: Theme.barHeight

        Icon {
            anchors.centerIn: parent
            name: root.open ? "close" : "power_settings_new"
            size: 20
            fill: 1
            color: root.open ? Theme.fg : Theme.error
            rotation: root.open ? 90 : 0
            scale: headMouse.pressed ? 0.8 : headMouse.containsMouse ? 1.12 : 1
            Behavior on rotation { Anim { kind: "fast" } }
            Behavior on scale { Anim { kind: "fast" } }
        }
        MouseArea {
            id: headMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.open = !root.open; root.armed = ""; }
        }
    }

    // ── заголовок меню
    Label {
        anchors { left: parent.left; leftMargin: 20; verticalCenter: head.verticalCenter }
        text: "Питание"
        size: 15
        weight: 700
        opacity: root.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { kind: "effects" } }
    }

    // ── пункты
    Column {
        anchors { top: head.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
        spacing: 4
        opacity: root.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { kind: "effects"; duration: root.open ? 320 : 120 } }

        Repeater {
            model: root.actions

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool armedHere: root.armed === modelData.id
                readonly property bool danger: modelData.id === "poweroff"
                width: parent.width
                height: 40

                // пункты «выезжают» по очереди
                opacity: root.open ? 1 : 0
                property real yOff: root.open ? 0 : -8 * (row.index + 1)
                Behavior on yOff { Anim { kind: "fast" } }
                transform: Translate { y: row.yOff }
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: root.open ? row.index * 35 : 0 } Anim { kind: "effects" } } }

                Rectangle {
                    anchors.fill: parent
                    radius: row.armedHere ? 14 : height / 2
                    color: row.armedHere ? (row.danger ? Theme.error : Theme.primary)
                         : rowMouse.containsMouse ? Theme.glassChip : "transparent"
                    Behavior on radius { Anim { kind: "fast" } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 12
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon
                        size: 20
                        fill: row.armedHere ? 1 : 0
                        color: row.armedHere ? (row.danger ? Theme.surface : Theme.primaryFg)
                             : row.danger ? Theme.error : Theme.fg
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.armedHere ? "Нажми ещё раз" : row.modelData.label
                        size: 14
                        weight: row.armedHere ? 700 : 550
                        color: row.armedHere ? (row.danger ? Theme.surface : Theme.primaryFg)
                             : row.danger ? Theme.error : Theme.fg
                        elide: Text.ElideNone
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.run(row.modelData)
                }
            }
        }
    }
}
