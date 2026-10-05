//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

// Отдельный мини-шелл для скриншотов (бар от него не зависит):
//  • выделение области со скруглёнными углами и затемнением вокруг
//  • мягкое свечение по краям экрана в цветах темы (как у Gemini)
// Вызывается из ~/.config/hypr/scripts/screenshot.sh:
//   qs ipc -c glow call shot start <region|pretty> <монитор>
//   qs ipc -c glow call glow show|hide|toggle   — только свечение
ShellRoot {
    id: shell

    // ───────── цвета темы (matugen, обновляются сами) ─────────
    FileView {
        path: Quickshell.env("HOME") + "/.cache/matugen/colors.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: c
            property string primary: "#a8c7fa"
            property string primaryFg: "#062e6f"
            property string secondary: "#bec6dc"
            property string tertiary: "#ddbce0"
            property string surfaceLowest: "#0c0e13"
            property string surfaceFg: "#e2e2e9"
        }
    }

    // ───────── свечение по краям в стиле Gemini (Pixel) ─────────
    // Мягкий свет облегает скруглённые края экрана, по периметру плывут «капли» света
    // (снизу гуще), цвета темы медленно вращаются по кругу. Без размытия в реальном
    // времени: маска собрана из двух маленьких картинок с готовым мягким затуханием.
    component EdgeGlow: Item {
        id: g
        property bool shown: false
        property real t: 0                          // время, сек
        property color c1: c.primary
        property color c2: c.tertiary
        property color c3: c.secondary
        property color c4: c.primary
        property color c5: c.tertiary
        property real cornerRadius: 30
        property real strength: 0.9

        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: g.shown ? 500 : 260; easing.type: Easing.OutCubic } }

        FrameAnimation {
            running: g.opacity > 0
            onTriggered: g.t += frameTime
        }

        // точка на периметре: p ∈ [0,1) по часовой от левого верхнего угла → {x, y, side}
        function perim(p) {
            const W = width, H = height, L = 2 * (W + H);
            let d = ((p % 1) + 1) % 1 * L;
            if (d < W) return { x: d, y: 0, v: false };
            d -= W;
            if (d < H) return { x: W, y: d, v: true };
            d -= H;
            if (d < W) return { x: W - d, y: H, v: false };
            d -= W;
            return { x: 0, y: H - d, v: true };
        }

        // ── маска (белое = свет): мягкий ободок по скруглённому краю + плывущие капли.
        // Всё из двух маленьких картинок с готовым мягким затуханием — без размытия в реальном времени.
        Item {
            id: maskSrc
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))

            BorderImage {
                anchors.fill: parent
                source: Qt.resolvedUrl("rim.png")
                border { left: 150; right: 150; top: 150; bottom: 150 }
                horizontalTileMode: BorderImage.Stretch
                verticalTileMode: BorderImage.Stretch
                opacity: 0.8
            }

            Repeater {
                model: 7
                Image {
                    required property int index
                    readonly property real speed: [0.018, -0.013, 0.015, -0.021, 0.010, -0.017, 0.012][index]
                    readonly property real base: index / 7
                    readonly property var pt: g.perim(base + g.t * speed)
                    // толщина «дышит», снизу свет гуще — как у Gemini
                    readonly property real thick: (150 + 90 * Math.sin(g.t * 0.9 + index * 1.7))
                                                  * (pt.y > g.height * 0.6 ? 1.8 : 1.0)
                    readonly property real len: 700 + 320 * Math.sin(g.t * 0.6 + index * 2.3)
                    source: Qt.resolvedUrl("blob.png")
                    smooth: true
                    width: pt.v ? thick : len
                    height: pt.v ? len : thick
                    x: pt.x - width / 2
                    y: pt.y - height / 2
                    opacity: 0.55 + 0.45 * Math.sin(g.t * 1.3 + index * 0.9)
                }
            }
        }

        // ── цвета: медленно вращаются по кругу
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

    // ───────── только свечение (по запросу) ─────────
    PanelWindow {
        id: glowWin
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: glowOnly.shown || glowOnly.opacity > 0
        mask: Region {}
        WlrLayershell.namespace: "quickshell-glow"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        IpcHandler {
            target: "glow"
            function show(): void { glowOnly.shown = true; }
            function hide(): void { glowOnly.shown = false; }
            function toggle(): void { glowOnly.shown = !glowOnly.shown; }
        }
        EdgeGlow { id: glowOnly; anchors.fill: parent }
    }

    // ───────── выделение области ─────────
    PanelWindow {
        id: sel

        property bool active: false
        property string mode: "region"
        property string monitor: ""
        // выделение (локальные координаты окна)
        property real sx: 0
        property real sy: 0
        property real sw: 0
        property real sh: 0
        property real ox: 0
        property real oy: 0
        property bool dragging: false
        readonly property bool hasSel: sw > 2 && sh > 2
        readonly property real r: Math.min(18, sw / 3, sh / 3)
        readonly property color veil: Qt.alpha(Qt.color(c.surfaceLowest), 0.45)

        screen: Quickshell.screens.find(s => s.name === sel.monitor) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: active
        WlrLayershell.namespace: "quickshell-glow"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        IpcHandler {
            target: "shot"
            function start(mode: string, monitor: string): void {
                sel.mode = mode;
                sel.monitor = monitor;
                sel.sx = 0; sel.sy = 0; sel.sw = 0; sel.sh = 0;
                sel.dragging = false;
                sel.active = true;
                edge.shown = true;
                focusTimer.restart();
            }
        }
        Timer { id: focusTimer; interval: 40; onTriggered: input.forceActiveFocus() }

        function close() {
            active = false;
            edge.shown = false;
            Quickshell.execDetached(["rm", "-f", Quickshell.env("XDG_RUNTIME_DIR") + "/shake-lens.lock"]);
        }
        function done(x, y, w, h) {
            close();
            if (w < 3 || h < 3) return;
            const gx = Math.round(x + (sel.screen?.x ?? 0)), gy = Math.round(y + (sel.screen?.y ?? 0));
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot.sh",
                "capture", sel.mode, gx + "," + gy + " " + Math.round(w) + "x" + Math.round(h)]);
        }

        // затемнение: целиком, пока ничего не выделено
        Rectangle {
            anchors.fill: parent
            color: sel.veil
            visible: !sel.hasSel
        }
        // затемнение со скруглённой «дыркой»: очень толстая рамка вокруг выделения
        Rectangle {
            readonly property real b: 6000
            visible: sel.hasSel
            x: sel.sx - b; y: sel.sy - b
            width: sel.sw + b * 2; height: sel.sh + b * 2
            radius: sel.r + b
            color: "transparent"
            border.width: b
            border.color: sel.veil
        }

        // в режиме Google Lens — цвета Google/Gemini вместо цветов темы
        readonly property bool lens: mode === "lens"
        readonly property color accent: lens ? "#4285F4" : c.primary
        EdgeGlow {
            id: edge
            anchors.fill: parent
            // Lens: цвета Google (синий, красный, жёлтый, зелёный) + фиолетовый Gemini
            c1: sel.lens ? "#4285F4" : c.primary
            c2: sel.lens ? "#EA4335" : c.tertiary
            c3: sel.lens ? "#FBBC04" : c.secondary
            c4: sel.lens ? "#34A853" : c.primary
            c5: sel.lens ? "#9177C7" : c.tertiary
        }

        // рамка выделения + мягкое свечение
        Item {
            visible: sel.hasSel
            x: sel.sx; y: sel.sy; width: sel.sw; height: sel.sh
            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                radius: sel.r + 5
                color: "transparent"
                border.width: 5
                border.color: Qt.alpha(sel.accent, 0.25)
            }
            Rectangle {
                anchors.fill: parent
                radius: sel.r
                color: "transparent"
                border.width: 2.5
                border.color: sel.accent
            }
        }

        // размер выделения
        Rectangle {
            visible: sel.hasSel && sel.sw > 60
            x: Math.max(8, Math.min(sel.width - width - 8, sel.sx + sel.sw / 2 - width / 2))
            y: sel.sy + sel.sh + 12 + height > sel.height ? sel.sy - height - 12 : sel.sy + sel.sh + 12
            width: sizeText.implicitWidth + 22
            height: 28
            radius: 14
            color: Qt.alpha(Qt.color(c.surfaceLowest), 0.85)
            border.width: 1
            border.color: Qt.alpha(Qt.color(c.surfaceFg), 0.12)
            Text {
                id: sizeText
                anchors.centerIn: parent
                text: Math.round(sel.sw) + " × " + Math.round(sel.sh)
                color: c.surfaceFg
                font.family: "Google Sans Flex"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        Item {
            id: input
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: sel.close()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.CrossCursor
                onPressed: m => {
                    if (m.button === Qt.RightButton) { sel.close(); return; }
                    sel.ox = m.x; sel.oy = m.y;
                    sel.sx = m.x; sel.sy = m.y; sel.sw = 0; sel.sh = 0;
                    sel.dragging = true;
                }
                onPositionChanged: m => {
                    if (!sel.dragging) return;
                    sel.sx = Math.min(sel.ox, m.x); sel.sy = Math.min(sel.oy, m.y);
                    sel.sw = Math.abs(m.x - sel.ox); sel.sh = Math.abs(m.y - sel.oy);
                }
                onReleased: m => {
                    if (m.button !== Qt.LeftButton || !sel.dragging) return;
                    sel.dragging = false;
                    if (sel.hasSel) sel.done(sel.sx, sel.sy, sel.sw, sel.sh);
                    else sel.done(0, 0, sel.width, sel.height);   // просто клик — весь экран
                }
            }
        }
    }

    // ───────── «потряси мышкой» → чёрные рамки экрана растут ─────────
    // Прогресс присылает ~/.config/hypr/scripts/shake-lens.py через сокет: строки «p 0.42».
    property real shake: 0
    SocketServer {
        active: true
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-glow.sock"
        handler: Socket {
            parser: SplitParser {
                onRead: msg => {
                    const p = msg.trim().split(" ");
                    if (p[0] === "p") shell.shake = Math.max(0, Math.min(1, parseFloat(p[1]) || 0));
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bezel
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            visible: frame.t > 0.5
            mask: Region {}
            WlrLayershell.namespace: "quickshell-glow"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                id: frame
                anchors.fill: parent
                property real t: shell.shake * 32          // толщина рамки, px (максимум)
                Behavior on t { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                readonly property real inner: Math.min(36, t * 0.7)   // скругление внутренних углов
                // одна очень толстая рамка, внешние углы уходят за экран
                Rectangle {
                    readonly property real off: 60
                    x: -off; y: -off
                    width: parent.width + off * 2
                    height: parent.height + off * 2
                    radius: frame.inner + frame.t + off
                    color: "transparent"
                    border.width: frame.t + off
                    border.color: "black"
                }
            }
        }
    }
}
