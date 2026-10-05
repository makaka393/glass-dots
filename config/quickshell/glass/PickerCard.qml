import QtQuick
import Quickshell.Widgets

// Содержимое выбора обоев: карусель превью + цвета с обоев + схема + тёмная/светлая тема
Item {
    id: root

    property var model: null            // ListModel { path, thumb }
    property string current: ""         // применённые обои
    property string scheme: "scheme-vibrant"
    property string mode: "dark"
    property bool busy: false
    property string currentSource: ""   // цвет, от которого построена текущая тема ("" — авто)
    // палитры для выбранных в карусели обоев: [{ src, p, s, t, pc }] — заполняет Picker
    property var palettes: []
    property bool palLoading: false
    property int palIdx: 0
    readonly property string selPath: model && list.currentIndex >= 0 && list.currentIndex < model.count ? model.get(list.currentIndex).path : ""
    readonly property string selThumb: model && list.currentIndex >= 0 && list.currentIndex < model.count ? model.get(list.currentIndex).thumb : ""
    readonly property string selColor: palettes.length > 0 ? palettes[Math.min(palIdx, palettes.length - 1)].src : ""
    signal apply(string path, string color)
    signal setScheme(string scheme)
    signal setMode(string mode)
    signal close()

    readonly property var schemes: [
        { id: "scheme-vibrant",     name: "Яркая" },
        { id: "scheme-expressive",  name: "Экспрессивная" },
        { id: "scheme-tonal-spot",  name: "Спокойная" },
        { id: "scheme-fidelity",    name: "Как на обоях" },
        { id: "scheme-rainbow",     name: "Радуга" },
        { id: "scheme-monochrome",  name: "Моно" }
    ]

    function focusList() { list.forceActiveFocus(); }
    // новые палитры пришли: для уже применённых обоев подсветить цвет, который стоит сейчас
    function setPalettes(arr) {
        let idx = 0;
        if (selPath === current && currentSource !== "")
            for (let i = 0; i < arr.length; i++)
                if (arr[i].src.toLowerCase() === currentSource.toLowerCase()) { idx = i; break; }
        palIdx = idx;
        palettes = arr;
    }
    function applySelected() { if (selPath !== "") apply(selPath, selColor); }
    function cyclePalette(d) { if (palettes.length > 1) palIdx = (palIdx + d + palettes.length) % palettes.length; }
    function selectCurrent() {
        if (!model) return;
        for (let i = 0; i < model.count; i++)
            if (model.get(i).path === current) { list.currentIndex = i; list.positionViewAtIndex(i, ListView.Center); return; }
    }

    // ── заголовок
    Row {
        id: header
        anchors { top: parent.top; left: parent.left; topMargin: 22; leftMargin: 28 }
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; name: "wallpaper"; size: 26; fill: 1; color: Theme.primary }
        Label { anchors.verticalCenter: parent.verticalCenter; text: "Обои и тема"; size: 22; weight: 750; elide: Text.ElideNone }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.model ? root.model.count : ""
            size: 13; weight: 600; color: Theme.fgVariant; elide: Text.ElideNone
        }
    }

    // ── справа: тёмная/светлая
    Rectangle {
        id: modeSwitch
        anchors { top: parent.top; right: parent.right; topMargin: 18; rightMargin: 24 }
        width: 96; height: 40; radius: 20
        color: Theme.glassChip
        Rectangle {
            x: root.mode === "dark" ? 4 : 50
            y: 4; width: 42; height: 32; radius: 16
            color: Theme.primary
            Behavior on x { Anim { kind: "fast" } }
        }
        Row {
            anchors.fill: parent
            anchors.margins: 4
            Repeater {
                model: [{ m: "dark", i: "dark_mode" }, { m: "light", i: "light_mode" }]
                Item {
                    required property var modelData
                    width: 44; height: 32
                    Icon {
                        anchors.centerIn: parent
                        name: modelData.i; size: 18; fill: 1
                        color: root.mode === modelData.m ? Theme.primaryFg : Theme.fgVariant
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.mode !== modelData.m) root.setMode(modelData.m)
                    }
                }
            }
        }
    }

    // ── схемы цветов
    Row {
        anchors { top: parent.top; right: modeSwitch.left; topMargin: 18; rightMargin: 12 }
        spacing: 6
        Repeater {
            model: root.schemes
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: root.scheme === modelData.id
                width: chipText.implicitWidth + (on ? 50 : 28)
                height: 40
                radius: on ? 14 : 20
                color: on ? Theme.secondaryContainer : chipMouse.containsMouse ? Qt.alpha(Theme.fg, 0.12) : Theme.glassChip
                Behavior on width { Anim { kind: "fast" } }
                Behavior on radius { Anim { kind: "fast" } }
                Behavior on color { ColorAnimation { duration: 180 } }
                Icon {
                    id: tick
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    name: "check"; size: 16
                    color: Theme.secondaryContainerFg
                    opacity: chip.on ? 1 : 0
                    scale: chip.on ? 1 : 0.3
                    Behavior on opacity { Anim { kind: "effects" } }
                    Behavior on scale { Anim { kind: "fast" } }
                }
                Label {
                    id: chipText
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: chip.modelData.name
                    size: 13; weight: chip.on ? 700 : 550
                    color: chip.on ? Theme.secondaryContainerFg : Theme.fg
                    elide: Text.ElideNone
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!chip.on) root.setScheme(chip.modelData.id)
                }
            }
        }
    }

    // ── карусель
    ListView {
        id: list
        // фиксированные размеры: если ListView меняет ширину при открытии окна,
        // Qt 6.11 падает (QQuickItemView::setPreferredHighlightEnd)
        anchors { horizontalCenter: parent.horizontalCenter; top: header.bottom; topMargin: 22 }
        width: 1200
        height: 230
        orientation: ListView.Horizontal
        spacing: 18
        clip: true
        model: root.model
        focus: true
        keyNavigationEnabled: true
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: 430
        preferredHighlightEnd: 770
        highlightMoveDuration: 380
        cacheBuffer: 2000

        Keys.onReturnPressed: root.applySelected()
        Keys.onEnterPressed: root.applySelected()
        Keys.onTabPressed: root.cyclePalette(1)
        Keys.onBacktabPressed: root.cyclePalette(-1)
        Keys.onDownPressed: root.cyclePalette(1)
        Keys.onUpPressed: root.cyclePalette(-1)
        Keys.onEscapePressed: root.close()

        WheelHandler {
            property real acc: 0
            onWheel: ev => {
                acc += ev.angleDelta.y + ev.angleDelta.x;
                if (Math.abs(acc) >= 120) {
                    acc > 0 ? list.decrementCurrentIndex() : list.incrementCurrentIndex();
                    acc = 0;
                }
            }
        }

        delegate: Item {
            id: card
            required property string path
            required property string thumb
            required property int index
            readonly property bool sel: ListView.isCurrentItem
            readonly property bool applied: root.current === path
            width: 340
            height: 230

            Item {
                anchors.centerIn: parent
                width: 340
                height: 192
                scale: card.sel ? 1.08 : mouse.containsMouse ? 1.03 : 0.92
                opacity: card.sel ? 1 : 0.62
                Behavior on scale { Anim { kind: "spatial" } }
                Behavior on opacity { Anim { kind: "effects" } }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: card.sel ? 22 : 30
                    color: Theme.surfaceHigh
                    Behavior on radius { Anim { kind: "fast" } }
                    Image {
                        anchors.fill: parent
                        source: card.thumb !== "" ? "file://" + card.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 480
                        sourceSize.height: 270
                    }
                }
                // рамка выбранного
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: (card.sel ? 22 : 30) + 5
                    color: "transparent"
                    border.width: 3
                    border.color: Theme.primary
                    opacity: card.sel ? 1 : 0
                    Behavior on opacity { Anim { kind: "effects" } }
                }
                // значок «видео» / «гиф»
                Rectangle {
                    readonly property string kind: /\.(mp4|webm|mkv|mov)$/i.test(card.path) ? "movie"
                                                 : /\.gif$/i.test(card.path) ? "gif" : ""
                    visible: kind !== ""
                    anchors { left: parent.left; top: parent.top; margins: 10 }
                    width: kindRow.implicitWidth + 16; height: 26; radius: 13
                    color: Qt.alpha(Theme.surfaceLowest, 0.7)
                    Row {
                        id: kindRow
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: parent.parent.kind === "movie" ? "play_circle" : "animation"; size: 15; fill: 1; color: Theme.primary }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.kind === "movie" ? "видео" : "GIF"; size: 11; weight: 700; elide: Text.ElideNone }
                    }
                }
                // значок «применено»
                Rectangle {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                    width: 34; height: 34; radius: 17
                    color: Theme.primary
                    opacity: card.applied ? 1 : 0
                    scale: card.applied ? 1 : 0.3
                    Behavior on opacity { Anim { kind: "effects" } }
                    Behavior on scale { Anim { kind: "fast" } }
                    Icon { anchors.centerIn: parent; name: "check"; size: 20; weight: 700; color: Theme.primaryFg }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // первый клик — выбрать (появятся цвета), второй — применить
                        if (list.currentIndex !== card.index) list.currentIndex = card.index;
                        else root.applySelected();
                    }
                }
            }
        }
    }

    // ── подпись: имя файла
    Label {
        id: fileName
        anchors { horizontalCenter: parent.horizontalCenter; top: list.bottom; topMargin: 6 }
        width: 600
        horizontalAlignment: Text.AlignHCenter
        text: root.selPath.split("/").pop()
        size: 13; weight: 600
    }

    // ── цвета с обоев: из какого строить тему (как «Обои и стиль» на Pixel)
    Item {
        id: palRow
        anchors { horizontalCenter: parent.horizontalCenter; top: fileName.bottom; topMargin: 12 }
        width: swatches.implicitWidth
        height: 60

        Row {
            id: swatches
            anchors.centerIn: parent
            spacing: 14
            opacity: root.palLoading ? 0.35 : 1
            Behavior on opacity { Anim { kind: "effects" } }

            Repeater {
                model: root.palettes
                Item {
                    id: sw
                    required property var modelData
                    required property int index
                    readonly property bool on: root.palIdx === index
                    readonly property bool applied: root.selPath === root.current && root.currentSource !== ""
                                                    && modelData.src.toLowerCase() === root.currentSource.toLowerCase()
                    width: 56; height: 56
                    scale: swMouse.pressed ? 0.9 : 1
                    Behavior on scale { Anim { kind: "fast" } }

                    // кольцо выбранного
                    Rectangle {
                        anchors.centerIn: parent
                        width: 56; height: 56
                        radius: sw.on ? 20 : 28
                        color: "transparent"
                        border.width: 3
                        border.color: Theme.primary
                        opacity: sw.on ? 1 : 0
                        Behavior on opacity { Anim { kind: "effects" } }
                        Behavior on radius { Anim { kind: "fast" } }
                    }
                    // сам свотч: сверху primary, снизу secondary + tertiary (четвертинки — тот же
                    // скруглённый прямоугольник, обрезанный обычным clip)
                    Item {
                        id: face
                        anchors.centerIn: parent
                        width: sw.on ? 42 : 46; height: width
                        readonly property real r: sw.on ? 14 : width / 2
                        Behavior on width { Anim { kind: "fast" } }
                        Rectangle { anchors.fill: parent; radius: face.r; color: sw.modelData.p }
                        Repeater {
                            model: 2
                            Item {
                                required property int index
                                x: index * face.width / 2; y: face.height / 2
                                width: face.width / 2; height: face.height / 2
                                clip: true
                                Rectangle {
                                    x: -parent.x; y: -face.height / 2
                                    width: face.width; height: face.height; radius: face.r
                                    color: index === 0 ? sw.modelData.s : sw.modelData.t
                                }
                            }
                        }
                        // кружок по центру — primary container, как на Pixel
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.42; height: width; radius: width / 2
                            color: sw.modelData.pc
                            Icon {
                                anchors.centerIn: parent
                                name: "check"; size: 14; weight: 700
                                color: sw.modelData.p
                                opacity: sw.applied ? 1 : 0
                            }
                        }
                    }
                    MouseArea {
                        id: swMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.palIdx = sw.index;
                            root.applySelected();
                            list.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    // ── подсказка
    Label {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
        text: root.busy ? "применяю…" : "← → обои  ·  ↑ ↓ цвет  ·  Enter применить  ·  Esc закрыть"
        size: 12; color: Theme.fgVariant; elide: Text.ElideNone
    }
}
