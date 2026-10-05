import QtQuick
import QtQuick.Effects

// Экран входа Glass — в стиле рабочего стола: Material 3 Expressive + стекло.
// Обои (картинка / GIF / видео) и цвета приходят из matugen: changetheme.sh
// при каждой смене темы пишет их в user/theme.conf.user.
Rectangle {
    id: root
    width: 2560
    height: 1440
    color: col.surfaceLowest

    // ───────── настройки из theme.conf / theme.conf.user ─────────
    function cfg(k, d) {
        try {
            const v = config[k];
            if (v !== undefined && v !== null && String(v) !== "") return String(v);
        } catch (e) {}
        return d;
    }
    readonly property real s: Math.max(0.5, height / 1440)      // масштаб под разрешение

    QtObject {
        id: col
        readonly property color primary: root.cfg("primary", "#a8c7fa")
        readonly property color primaryFg: root.cfg("onPrimary", "#062e6f")
        readonly property color primaryContainer: root.cfg("primaryContainer", "#284777")
        readonly property color primaryContainerFg: root.cfg("onPrimaryContainer", "#d6e3ff")
        readonly property color secondaryContainer: root.cfg("secondaryContainer", "#3e4759")
        readonly property color secondaryContainerFg: root.cfg("onSecondaryContainer", "#dae2f9")
        readonly property color tertiary: root.cfg("tertiary", "#ddbce0")
        readonly property color surface: root.cfg("surface", "#111318")
        readonly property color surfaceLowest: root.cfg("surfaceLowest", "#0c0e13")
        readonly property color surfaceHigh: root.cfg("surfaceHigh", "#282a2f")
        readonly property color fg: root.cfg("onSurface", "#e2e2e9")
        readonly property color fgVariant: root.cfg("onSurfaceVariant", "#c4c6d0")
        readonly property color outline: root.cfg("outline", "#8e9099")
        readonly property color error: root.cfg("error", "#ffb4ab")
        readonly property color errorContainer: root.cfg("errorContainer", "#93000a")
        readonly property color errorContainerFg: root.cfg("onErrorContainer", "#ffdad6")
        // стекло — как у бара
        readonly property color glass: Qt.alpha(surfaceLowest, 0.42)
        readonly property color glassBorder: Qt.alpha(fg, 0.12)
        readonly property color chip: Qt.alpha(fg, 0.08)
    }

    // ───────── шрифты (лежат в теме: у sddm нет доступа к ~/.local/share/fonts) ─────────
    FontLoader { id: sans; source: "fonts/GoogleSansFlex.ttf" }
    FontLoader { id: symbols; source: "fonts/MaterialSymbolsRounded.ttf" }
    readonly property string fontSans: sans.status === FontLoader.Ready ? sans.name : "sans-serif"
    readonly property string fontIcons: symbols.status === FontLoader.Ready ? symbols.name : ""

    // ───────── кривые M3 Expressive ─────────
    readonly property var spatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
    readonly property var spatialFast: [0.42, 1.67, 0.21, 0.90, 1, 1]
    readonly property var effects: [0.34, 0.80, 0.34, 1.00, 1, 1]

    component Txt: Text {
        property int size: 16
        property int weight: 500
        color: col.fg
        font.family: root.fontSans
        font.pixelSize: size
        font.variableAxes: ({ "wght": weight, "ROND": 100, "opsz": Math.max(6, Math.min(144, size)) })
        font.features: ({ "tnum": 1 })
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: 250 } }
    }
    component Ico: Text {
        property string name: ""
        property real fill: 1
        property int size: 22
        text: name
        color: col.fg
        font.family: root.fontIcons
        font.pixelSize: size
        font.variableAxes: ({ "FILL": fill, "wght": 500, "opsz": Math.max(20, Math.min(48, size)), "GRAD": 0 })
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: root.fontIcons !== ""
        Behavior on color { ColorAnimation { duration: 250 } }
    }
    component Spring: NumberAnimation {
        property string kind: "spatial"
        duration: kind === "fast" ? 350 : kind === "effects" ? 220 : 520
        easing.type: Easing.BezierSpline
        easing.bezierCurve: kind === "fast" ? root.spatialFast : kind === "effects" ? root.effects : root.spatial
    }
    // стеклянная подложка: размытые обои под собой + тонировка + тонкий кант
    component Glass: Item {
        id: gl
        property real radius: 28 * root.s
        property color tint: col.glass
        Rectangle {
            id: glMask
            anchors.fill: parent
            radius: gl.radius
            visible: false
            layer.enabled: true
        }
        ShaderEffectSource {
            id: glSrc
            anchors.fill: parent
            sourceItem: blurredBg
            // mapToItem сам не обновляется — перечисляем всё, что двигает стекло
            sourceRect: {
                void [loginBox.y, infoPill.y, infoPill.width, field.width, field.shakeX, power.width, gl.width, gl.height, root.width, root.height];
                const p = gl.mapToItem(root, 0, 0);
                return Qt.rect(p.x, p.y, gl.width, gl.height);
            }
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: glSrc
            maskEnabled: true
            maskSource: glMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Rectangle { anchors.fill: parent; radius: gl.radius; color: gl.tint; border.width: 1; border.color: col.glassBorder }
        Rectangle {
            anchors.fill: parent; anchors.margins: 1; radius: gl.radius - 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }
    }

    // ───────── состояние ─────────
    property bool active: false          // проснулся: есть ввод → обои размываются, часы уезжают вверх
    property bool busy: false            // идёт проверка пароля
    property string message: ""
    property int userIdx: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    readonly property int sessionIdx: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property var curUser: users.count > 0 && users.itemAt(userIdx) ? users.itemAt(userIdx) : null
    readonly property string userName: curUser ? curUser.uname : userModel.lastUser
    readonly property string displayName: curUser && curUser.rname !== "" ? curUser.rname : userName

    function wake() { active = true; idleTimer.restart(); }
    function login() {
        if (busy || password.text === "") return;
        busy = true;
        message = "";
        glow.failed = false;
        sddm.login(root.userName, password.text, root.sessionIdx);
        loginGuard.restart();
    }
    // в --test-mode sddm не отвечает ни «успех», ни «ошибка» — не зависаем в «Вход…»
    Timer {
        id: loginGuard
        interval: 8000
        onTriggered: if (root.busy && !glow.success) {
            root.busy = false;
            root.message = "Нет ответа (тестовый режим?)";
            password.text = "";
            password.forceActiveFocus();
        }
    }

    Timer {
        id: idleTimer
        interval: 20000
        onTriggered: if (password.text === "" && !root.busy) root.active = false
    }

    // список пользователей (модель sddm отдаёт данные только через делегаты)
    Repeater {
        id: users
        model: userModel
        Item {
            required property string name
            required property string realName
            required property string icon
            readonly property string uname: name
            readonly property string rname: realName
            readonly property string face: icon
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.message = "Неверный пароль";
            password.text = "";
            glow.failed = true;
            failTimer.restart();
            shake.restart();
            password.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.message = "";
            glow.success = true;
        }
    }
    Timer { id: failTimer; interval: 1400; onTriggered: glow.failed = false }

    // ───────── обои ─────────
    readonly property string bgImage: cfg("background", "")
    readonly property string bgVideo: cfg("video", "")

    Item {
        id: bg
        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle { anchors.fill: parent; color: col.surfaceLowest }
        // картинка (для видео — его кадр, пока ролик не пошёл)
        Image {
            anchors.fill: parent
            visible: !/\.gif$/i.test(root.bgImage)
            source: root.bgImage !== "" ? "file://" + root.bgImage : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: root.width
            sourceSize.height: root.height
        }
        AnimatedImage {
            anchors.fill: parent
            visible: /\.gif$/i.test(root.bgImage)
            source: visible ? "file://" + root.bgImage : ""
            fillMode: Image.PreserveAspectCrop
            playing: visible
        }
        Loader {
            id: video
            anchors.fill: parent
            active: root.bgVideo !== ""
            source: "VideoBg.qml"
            onLoaded: item.source = "file://" + root.bgVideo
            opacity: item && item.playing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }
    }

    // размытая копия обоев: фон в режиме ввода и источник для «стекла»
    MultiEffect {
        id: blurredBg
        anchors.fill: parent
        source: bg
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.15
        brightness: -0.08
        visible: false
        layer.enabled: true
    }

    // что видно: чёткие обои ↔ размытые
    MultiEffect {
        anchors.fill: parent
        source: bg
        blurEnabled: true
        blurMax: 64
        blur: root.active ? 0.85 : 0
        Behavior on blur { Spring { kind: "effects"; duration: 450 } }
    }
    // затемнение для читаемости: снизу сильнее, в режиме ввода — везде
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(col.surfaceLowest, root.active ? 0.38 : 0.10) }
            GradientStop { position: 0.55; color: Qt.alpha(col.surfaceLowest, root.active ? 0.40 : 0.0) }
            GradientStop { position: 1.0; color: Qt.alpha(col.surfaceLowest, root.active ? 0.62 : 0.45) }
        }
    }

    // любое движение мыши «будит»
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        property point last: Qt.point(-1, -1)
        onPositionChanged: m => {
            if (last.x >= 0 && Math.abs(m.x - last.x) + Math.abs(m.y - last.y) > 6) root.wake();
            last = Qt.point(m.x, m.y);
        }
        onClicked: { root.wake(); password.forceActiveFocus(); }
    }

    // ───────── часы ─────────
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    readonly property var ru: Qt.locale("ru_RU")

    Item {
        id: clockBox
        anchors.horizontalCenter: parent.horizontalCenter
        width: clockCol.width
        height: clockCol.height
        y: root.active ? root.height * 0.10 : root.height * 0.17
        // размер меняем шрифтом, а не scale: масштабированный слой с текстом мылится
        property real zoom: root.active ? 0.72 : 1
        Behavior on y { Spring {} }
        Behavior on zoom { Spring {} }

        Column {
            id: clockCol
            readonly property bool stacked: root.cfg("stackedClock", "true") !== "false"
            spacing: -96 * root.s * clockBox.zoom       // цифры «столбиком» плотно, как на Pixel
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clockCol.stacked ? Qt.formatTime(root.now, "HH") : Qt.formatTime(root.now, "HH:mm")
                size: (clockCol.stacked ? 250 : 190) * root.s * clockBox.zoom
                weight: 650
                color: col.primary
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.alpha("black", 0.45); shadowBlur: 0.8; shadowVerticalOffset: 4 }
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: clockCol.stacked
                text: Qt.formatTime(root.now, "mm")
                size: 250 * root.s * clockBox.zoom
                weight: 650
                color: col.fg
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.alpha("black", 0.45); shadowBlur: 0.8; shadowVerticalOffset: 4 }
            }
        }
    }

    // дата + погода: стеклянная пилюля под часами
    Item {
        id: infoPill
        anchors.horizontalCenter: parent.horizontalCenter
        y: clockBox.y + clockBox.height + 26 * root.s
        width: infoRow.implicitWidth + 44 * root.s
        height: 52 * root.s
        Behavior on width { Spring { kind: "fast" } }

        Glass { anchors.fill: parent; radius: height / 2 }
        Row {
            id: infoRow
            anchors.centerIn: parent
            spacing: 12 * root.s
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const d = root.ru.toString(root.now, "dddd, d MMMM");
                    return d.charAt(0).toUpperCase() + d.slice(1);
                }
                size: 21 * root.s; weight: 600
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: weather.ready
                width: 5 * root.s; height: width; radius: width / 2
                color: col.fgVariant
            }
            Ico {
                anchors.verticalCenter: parent.verticalCenter
                visible: weather.ready && root.fontIcons !== ""
                name: weather.icon(weather.code, weather.isDay)
                size: 26 * root.s
                color: col.tertiary
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: weather.ready
                text: Math.round(weather.temp) + "°  " + weather.describe(weather.code)
                size: 21 * root.s; weight: 600
            }
        }
    }

    // ───────── вход: аватар, имя, пароль ─────────
    Column {
        id: loginBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - (root.active ? 150 : 110) * root.s
        spacing: 16 * root.s
        opacity: root.active ? 1 : 0.88
        Behavior on y { Spring {} }
        Behavior on opacity { Spring { kind: "effects" } }

        // аватар
        Item {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: (root.active ? 112 : 88) * root.s
            height: width
            Behavior on width { Spring {} }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -5 * root.s
                radius: width / 2
                color: "transparent"
                border.width: 3 * root.s
                border.color: col.primary
                opacity: password.activeFocus ? 1 : 0.0
                Behavior on opacity { Spring { kind: "effects" } }
            }
            Rectangle {
                id: avatarBase
                anchors.fill: parent
                radius: width / 2
                color: col.primaryContainer
                Txt {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: root.displayName.charAt(0).toUpperCase()
                    size: parent.width * 0.44; weight: 700
                    color: col.primaryContainerFg
                }
            }
            Image {
                id: face
                anchors.fill: parent
                source: root.curUser && root.curUser.face !== "" ? "file://" + root.curUser.face : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 256
                sourceSize.height: 256
                visible: false
                asynchronous: true
            }
            MultiEffect {
                anchors.fill: parent
                visible: face.status === Image.Ready
                source: face
                maskEnabled: true
                maskSource: avatarBase
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            Component.onCompleted: avatarBase.layer.enabled = true
            MouseArea {
                anchors.fill: parent
                cursorShape: users.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (users.count > 1) root.userIdx = (root.userIdx + 1) % users.count;
                    root.wake(); password.forceActiveFocus();
                }
            }
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.displayName
            size: 24 * root.s; weight: 700
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.alpha("black", 0.5); shadowBlur: 0.6 }
        }

        // поле пароля
        Item {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: (root.active ? 500 : 380) * root.s
            height: 64 * root.s
            Behavior on width { Spring {} }
            property real shakeX: 0
            transform: Translate { x: field.shakeX }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "shakeX"; to: -18 * root.s; duration: 50 }
                NumberAnimation { target: field; property: "shakeX"; to: 16 * root.s; duration: 70 }
                NumberAnimation { target: field; property: "shakeX"; to: -10 * root.s; duration: 70 }
                NumberAnimation { target: field; property: "shakeX"; to: 6 * root.s; duration: 70 }
                NumberAnimation { target: field; property: "shakeX"; to: 0; duration: 80 }
            }

            Glass {
                anchors.fill: parent
                radius: root.message !== "" ? 20 * root.s : height / 2
                tint: root.message !== "" ? Qt.alpha(col.errorContainer, 0.55) : col.glass
                Behavior on radius { Spring { kind: "fast" } }
            }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                border.width: 2
                border.color: col.primary
                opacity: password.activeFocus && root.message === "" ? 0.9 : 0
                Behavior on opacity { Spring { kind: "effects" } }
            }

            Ico {
                id: lockIcon
                anchors { left: parent.left; leftMargin: 22 * root.s; verticalCenter: parent.verticalCenter }
                name: root.message !== "" ? "error" : keyboard.capsLock ? "keyboard_capslock_badge" : "lock"
                size: 24 * root.s
                color: root.message !== "" ? col.error : keyboard.capsLock ? col.tertiary : col.fgVariant
            }

            TextInput {
                id: password
                anchors { left: lockIcon.right; leftMargin: 14 * root.s; right: go.left; rightMargin: 12 * root.s; verticalCenter: parent.verticalCenter }
                // сам текст невидим — вместо точек рисуются фигуры (PasswordShapes)
                echoMode: TextInput.Password
                passwordMaskDelay: 0
                readonly property bool shapes: shapesLoader.status === Loader.Ready
                passwordCharacter: "●"
                color: shapes ? "transparent" : col.fg
                selectionColor: shapes ? "transparent" : col.primary
                selectedTextColor: shapes ? "transparent" : col.primaryFg
                font.letterSpacing: shapes ? 0 : 4 * root.s
                cursorDelegate: Rectangle {
                    width: 2 * root.s
                    color: col.primary
                    visible: !password.shapes && password.activeFocus
                }
                font.pixelSize: 22 * root.s
                height: 40 * root.s
                clip: true
                focus: true
                enabled: !root.busy
                onTextChanged: { root.wake(); if (text !== "") root.message = ""; }
                Keys.onReturnPressed: root.login()
                Keys.onEnterPressed: root.login()
                Keys.onEscapePressed: { text = ""; root.active = false; }
                Keys.onPressed: root.wake()

                // фигуры грузятся через Loader: если что-то с ними не так —
                // пароль просто показывается точками, вход не ломается
                Loader {
                    id: shapesLoader
                    anchors.fill: parent
                    source: "PasswordShapes.qml"
                    onStatusChanged: if (status === Loader.Error) console.warn("glass: фигуры пароля не загрузились — показываю точки")
                }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "count"; value: password.text.length }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "size"; value: 24 * root.s }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "gap"; value: 5 * root.s }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "color"; value: col.fg }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "accent"; value: col.primary }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "errorColor"; value: col.error }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "busy"; value: root.busy }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "failed"; value: root.message !== "" }
                Binding { when: shapesLoader.item !== null; target: shapesLoader.item; property: "caret"; value: password.activeFocus && password.text.length > 0 }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    // проявляется, когда фигуры уже «улетели»
                    opacity: password.text === "" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: password.text === "" ? 380 : 60; easing.type: Easing.InQuad } }
                    text: root.message !== "" ? root.message
                        : keyboard.capsLock ? "Включён Caps Lock"
                        : root.busy ? "Вход…" : "Пароль"
                    size: 19 * root.s; weight: 550
                    color: root.message !== "" ? col.errorContainerFg : col.fgVariant
                }
            }

            // кнопка «войти»: M3 Expressive — круг, при нажатии становится квадратнее
            Rectangle {
                id: go
                anchors { right: parent.right; rightMargin: 8 * root.s; verticalCenter: parent.verticalCenter }
                width: 48 * root.s; height: width
                radius: goMouse.pressed || root.busy ? 14 * root.s : width / 2
                color: password.text !== "" || root.busy ? col.primary : col.chip
                Behavior on radius { Spring { kind: "fast" } }
                Behavior on color { ColorAnimation { duration: 200 } }
                Ico {
                    anchors.centerIn: parent
                    visible: !root.busy
                    name: "arrow_forward"
                    size: 24 * root.s
                    color: password.text !== "" ? col.primaryFg : col.fgVariant
                }
                Ico {
                    anchors.centerIn: parent
                    visible: root.busy
                    name: "progress_activity"
                    size: 24 * root.s
                    color: col.primaryFg
                    RotationAnimator on rotation { running: root.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                }
                MouseArea { id: goMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
            }
        }
    }

    // ───────── питание: справа снизу ─────────
    Item {
        id: power
        anchors { right: parent.right; bottom: parent.bottom; margins: 36 * root.s }
        width: powerRow.implicitWidth + 16 * root.s
        height: 60 * root.s
        property string armed: ""
        Behavior on width { Spring { kind: "fast" } }
        Timer { id: disarm; interval: 3000; onTriggered: power.armed = "" }

        Glass { anchors.fill: parent; radius: height / 2 }
        Row {
            id: powerRow
            anchors.centerIn: parent
            spacing: 6 * root.s
            Repeater {
                model: [
                    { id: "suspend", icon: "bedtime", label: "Сон", can: sddm.canSuspend },
                    { id: "reboot", icon: "restart_alt", label: "Перезагрузить", can: sddm.canReboot },
                    { id: "poweroff", icon: "power_settings_new", label: "Выключить", can: sddm.canPowerOff }
                ]
                Rectangle {
                    id: pb
                    required property var modelData
                    readonly property bool armed: power.armed === modelData.id
                    visible: modelData.can
                    height: 44 * root.s
                    width: armed ? pbLabel.implicitWidth + 64 * root.s : 44 * root.s
                    radius: armed ? 14 * root.s : height / 2
                    color: armed ? col.errorContainer : pbMouse.containsMouse ? Qt.alpha(col.fg, 0.12) : "transparent"
                    clip: true
                    Behavior on width { Spring { kind: "fast" } }
                    Behavior on radius { Spring { kind: "fast" } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Ico {
                        id: pbIcon
                        x: (44 * root.s - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        name: pb.modelData.icon
                        size: 22 * root.s
                        color: pb.armed ? col.errorContainerFg : col.fg
                    }
                    Txt {
                        id: pbLabel
                        anchors { left: parent.left; leftMargin: 44 * root.s; verticalCenter: parent.verticalCenter }
                        text: pb.modelData.label + "?"
                        size: 15 * root.s; weight: 650
                        color: col.errorContainerFg
                        opacity: pb.armed ? 1 : 0
                        Behavior on opacity { Spring { kind: "effects" } }
                    }
                    MouseArea {
                        id: pbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.wake();
                            // сон — сразу; перезагрузка и выключение — вторым нажатием
                            if (pb.modelData.id === "suspend") { sddm.suspend(); return; }
                            if (!pb.armed) { power.armed = pb.modelData.id; disarm.restart(); return; }
                            if (pb.modelData.id === "reboot") sddm.reboot(); else sddm.powerOff();
                        }
                    }
                }
            }
        }
    }

    // ───────── свечение по краям: пока проверяется пароль ─────────
    Loader {
        id: glowLoader
        anchors.fill: parent
        source: "Glow.qml"
        onLoaded: {
            item.c1 = Qt.binding(() => glow.failed ? col.error : col.primary);
            item.c2 = Qt.binding(() => glow.failed ? col.errorContainer : col.tertiary);
            item.c3 = Qt.binding(() => glow.failed ? col.error : col.primaryContainer);
            item.c4 = Qt.binding(() => glow.failed ? col.errorContainerFg : col.primary);
            item.c5 = Qt.binding(() => glow.failed ? col.error : col.tertiary);
            item.shown = Qt.binding(() => root.busy || glow.failed || glow.success);
            item.speed = Qt.binding(() => glow.success ? 3 : 1);
        }
    }
    QtObject {
        id: glow
        property bool failed: false
        property bool success: false
    }

    // ───────── погода (open-meteo) ─────────
    QtObject {
        id: weather
        property bool ready: false
        property real temp: 0
        property int code: 0
        property bool isDay: true

        function refresh() {
            const url = "https://api.open-meteo.com/v1/forecast?latitude=" + root.cfg("lat", "42.6977")
                + "&longitude=" + root.cfg("lon", "23.3219")
                + "&current=temperature_2m,weather_code,is_day&timezone=auto";
            const xhr = new XMLHttpRequest();
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (xhr.status !== 200) return;
                try {
                    const d = JSON.parse(xhr.responseText);
                    weather.temp = d.current.temperature_2m;
                    weather.code = d.current.weather_code;
                    weather.isDay = d.current.is_day === 1;
                    weather.ready = true;
                } catch (e) {}
            };
            xhr.open("GET", url);
            xhr.send();
        }
        function icon(c, day) {
            if (c === 0) return day ? "clear_day" : "clear_night";
            if (c <= 2) return day ? "partly_cloudy_day" : "partly_cloudy_night";
            if (c === 3) return "cloud";
            if (c === 45 || c === 48) return "foggy";
            if (c >= 51 && c <= 61) return "rainy_light";
            if (c === 63 || c === 80 || c === 81) return "rainy";
            if (c === 65 || c === 82) return "rainy_heavy";
            if (c === 66 || c === 67) return "rainy_snow";
            if (c >= 71 && c <= 77) return "weather_snowy";
            if (c === 85 || c === 86) return "snowing";
            if (c >= 95) return "thunderstorm";
            return "cloud";
        }
        function describe(c) {
            if (c === 0) return "ясно";
            if (c === 1) return "почти ясно";
            if (c === 2) return "облачно";
            if (c === 3) return "пасмурно";
            if (c === 45 || c === 48) return "туман";
            if (c >= 51 && c <= 57) return "морось";
            if (c >= 61 && c <= 67) return "дождь";
            if (c >= 71 && c <= 77) return "снег";
            if (c >= 80 && c <= 82) return "ливень";
            if (c === 85 || c === 86) return "снегопад";
            if (c >= 95) return "гроза";
            return "";
        }
    }
    // сеть при загрузке поднимается не сразу: пробуем каждые 20 с, потом раз в 15 мин
    Timer {
        interval: weather.ready ? 15 * 60 * 1000 : 20000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: weather.refresh()
    }

    Component.onCompleted: password.forceActiveFocus()
}
