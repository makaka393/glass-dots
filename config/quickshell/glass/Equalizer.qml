import QtQuick

// Три прыгающие полоски, пока играет музыка
Row {
    id: root
    property bool playing: false
    spacing: 2
    height: 14

    Repeater {
        model: 3
        Rectangle {
            id: bar
            required property int index
            anchors.bottom: parent.bottom
            width: 3
            radius: 1.5
            color: Theme.primary
            height: 4
            SequentialAnimation on height {
                running: root.playing
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: [12, 8, 14][bar.index]; duration: [380, 300, 450][bar.index]; easing.type: Easing.InOutSine }
                NumberAnimation { to: 4; duration: [320, 420, 260][bar.index]; easing.type: Easing.InOutSine }
            }
        }
    }
}
