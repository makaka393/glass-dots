import QtQuick

// Волнистый прогресс-бар из Android / M3 Expressive.
// Волна бежит, пока играет, и разглаживается в прямую на паузе.
Item {
    id: root

    property real value: 0                  // 0..1
    property bool playing: false
    property color activeColor: Theme.primary
    property color trackColor: Qt.alpha(Theme.fg, 0.22)
    property real wavelength: 26
    property real stroke: 4
    signal seek(real fraction)

    implicitHeight: 22

    property real amp: playing ? 3.4 : 0
    Behavior on amp { Anim { kind: "effects"; duration: 450 } }

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown { enabled: !drag.pressed; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    property real phase: 0
    NumberAnimation on phase {
        from: 0; to: Math.PI * 2
        duration: 1600
        loops: Animation.Infinite
        running: root.playing && root.visible
    }

    onPhaseChanged: canvas.requestPaint()
    onAmpChanged: canvas.requestPaint()
    onShownChanged: canvas.requestPaint()
    onActiveColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, mid = height / 2, sw = root.stroke, gap = 6;
            const head = Math.max(sw / 2, Math.min(w - sw / 2, root.shown * w));
            ctx.lineCap = "round";
            ctx.lineWidth = sw;

            // остаток трека
            if (head + gap + sw < w - sw / 2) {
                ctx.strokeStyle = Theme.css(root.trackColor);
                ctx.beginPath();
                ctx.moveTo(head + gap + sw / 2, mid);
                ctx.lineTo(w - sw / 2, mid);
                ctx.stroke();
            }

            // волна
            ctx.strokeStyle = Theme.css(root.activeColor);
            ctx.beginPath();
            const k = 2 * Math.PI / root.wavelength;
            for (let x = sw / 2; x <= head; x += 1) {
                // волна плавно гасится у самого начала и у головы
                const fade = Math.min(1, (x - sw / 2) / 10, (head - x) / 10 + 0.15);
                const y = mid + root.amp * Math.max(0, fade) * Math.sin(k * x - root.phase);
                if (x === sw / 2) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.stroke();

            // «голова» — вертикальная чёрточка как у M3 слайдера
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(head, mid - 7);
            ctx.lineTo(head, mid + 7);
            ctx.stroke();
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        cursorShape: Qt.PointingHandCursor
        function frac(x) { return Math.max(0, Math.min(1, x / width)); }
        onPressed: m => root.shown = frac(m.x)
        onPositionChanged: m => { if (pressed) root.shown = frac(m.x); }
        onReleased: m => root.seek(frac(m.x))
    }
}
