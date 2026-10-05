import QtQuick
import Qt5Compat.GraphicalEffects

// Свечение по краям экрана в стиле Gemini — то же, что при скриншотах.
// Маска из двух готовых картинок (rim.png, blob.png), цвета вращаются по кругу.
Item {
    id: g
    property bool shown: false
    property real t: 0
    property color c1: "#a8c7fa"
    property color c2: "#ddbce0"
    property color c3: "#bec6dc"
    property color c4: c1
    property color c5: c2
    property real strength: 0.9
    property real speed: 1.0

    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: g.shown ? 500 : 700; easing.type: Easing.OutCubic } }

    FrameAnimation {
        running: g.opacity > 0
        onTriggered: g.t += frameTime * g.speed
    }

    function perim(p) {
        const W = width, H = height;
        let d = ((p % 1) + 1) % 1 * 2 * (W + H);
        if (d < W) return { x: d, y: 0, v: false };
        d -= W;
        if (d < H) return { x: W, y: d, v: true };
        d -= H;
        if (d < W) return { x: W - d, y: H, v: false };
        d -= W;
        return { x: 0, y: H - d, v: true };
    }

    Item {
        id: maskSrc
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))

        BorderImage {
            anchors.fill: parent
            source: "rim.png"
            border { left: 150; right: 150; top: 150; bottom: 150 }
            horizontalTileMode: BorderImage.Stretch
            verticalTileMode: BorderImage.Stretch
            opacity: 0.8
        }
        Repeater {
            model: 7
            Image {
                required property int index
                readonly property real sp: [0.018, -0.013, 0.015, -0.021, 0.010, -0.017, 0.012][index]
                readonly property var pt: g.perim(index / 7 + g.t * sp)
                readonly property real thick: (150 + 90 * Math.sin(g.t * 0.9 + index * 1.7)) * (pt.y > g.height * 0.6 ? 1.8 : 1.0)
                readonly property real len: 700 + 320 * Math.sin(g.t * 0.6 + index * 2.3)
                source: "blob.png"
                smooth: true
                width: pt.v ? thick : len
                height: pt.v ? len : thick
                x: pt.x - width / 2
                y: pt.y - height / 2
                opacity: 0.55 + 0.45 * Math.sin(g.t * 1.3 + index * 0.9)
            }
        }
    }

    ConicalGradient {
        id: colors
        anchors.fill: parent
        visible: false
        angle: g.t * 24
        gradient: Gradient {
            GradientStop { position: 0.00; color: g.c1 }
            GradientStop { position: 0.20; color: g.c2 }
            GradientStop { position: 0.40; color: g.c3 }
            GradientStop { position: 0.60; color: g.c4 }
            GradientStop { position: 0.80; color: g.c5 }
            GradientStop { position: 1.00; color: g.c1 }
        }
    }

    OpacityMask {
        anchors.fill: parent
        source: colors
        maskSource: maskSrc
        opacity: g.strength
    }
}
