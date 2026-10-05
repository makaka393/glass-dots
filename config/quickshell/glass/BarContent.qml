import QtQuick

Item {
    id: root
    property var barWindow: null
    readonly property alias leftGroup: left
    readonly property alias centerGroup: center
    readonly property alias rightGroup: right

    Row {
        id: left
        anchors { top: parent.top; left: parent.left; topMargin: Theme.outer; leftMargin: Theme.outer }
        spacing: Theme.gap
        Workspaces {}
        Apps {}
    }

    DynamicIsland {
        id: center
        anchors { top: parent.top; topMargin: Theme.outer; horizontalCenter: parent.horizontalCenter }
    }

    Row {
        id: right
        anchors { top: parent.top; right: parent.right; topMargin: Theme.outer; rightMargin: Theme.outer }
        spacing: Theme.gap
        Lang {}
        Volume {}
        Power {}
    }
}
