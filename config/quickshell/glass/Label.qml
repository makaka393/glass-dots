import QtQuick

// Текст в стиле M3 Expressive: Google Sans Flex со скруглением (ROND)
Text {
    property int size: 14
    property int weight: 500
    property real round: 100

    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: size
    font.variableAxes: ({ "wght": weight, "ROND": round, "opsz": Math.max(6, Math.min(144, size)) })
    font.features: ({ "tnum": 1 })
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    Behavior on color { ColorAnimation { duration: 300 } }
}
