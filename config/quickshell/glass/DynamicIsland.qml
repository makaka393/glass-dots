import QtQuick
import Quickshell
import Quickshell.Widgets

// Центральный остров в духе Dynamic Island.
//  compact — часы · погода · текущий трек
//  media   — наведи на трек: остров перетекает в карточку плеера
//  weather — клик по часам/погоде: прогноз
Island {
    id: root
    objectName: "island"

    property string mode: "compact"
    readonly property var player: Players.active
    readonly property bool hasPlayer: player !== null && (player.trackTitle ?? "") !== ""

    strong: mode !== "compact"
    targetWidth: mode === "media" ? 520 : mode === "weather" ? 520 : compact.implicitWidth + 30
    targetHeight: mode === "media" ? 184 : mode === "weather" ? 196 : Theme.barHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── сворачивание с задержкой, чтобы не дёргалось
    Timer { id: collapse; interval: 380; onTriggered: if (!root.hovered) root.mode = "compact" }
    Timer { id: openMedia; interval: 140; onTriggered: if (mediaHover.hovered && root.hasPlayer) root.mode = "media" }
    onHoveredChanged: if (!hovered && mode !== "compact") collapse.restart()

    // ── «подглядывание» при смене трека
    Timer { id: peek; interval: 2600; onTriggered: if (!root.hovered && root.mode === "media") root.mode = "compact" }
    Connections {
        target: root.player
        enabled: Theme.mediaPeek
        function onTrackTitleChanged() {
            if (root.mode === "compact" && !root.hovered && root.hasPlayer && root.player.isPlaying) {
                root.mode = "media";
                peek.restart();
            }
        }
    }

    // ───────────── compact ─────────────
    Row {
        id: compact
        anchors.horizontalCenter: parent.horizontalCenter
        y: (Theme.barHeight - height) / 2
        height: 28
        spacing: 12
        opacity: root.mode === "compact" ? 1 : 0
        scale: root.mode === "compact" ? 1 : 0.86
        visible: opacity > 0
        Behavior on opacity { Anim { kind: "effects" } }
        Behavior on scale { Anim { kind: "fast" } }

        // часы + погода (клик → прогноз)
        Row {
            id: clockWeather
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clock.date, "HH:mm")
                    size: 16
                    weight: 700
                    elide: Text.ElideNone
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: clock.date.toLocaleDateString(Qt.locale(), "ddd, d MMM")
                    size: 13
                    weight: 500
                    color: Theme.fgVariant
                    elide: Text.ElideNone
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: Weather.ready
                Icon { anchors.verticalCenter: parent.verticalCenter; name: Weather.icon(Weather.code, Weather.isDay); size: 20; fill: 1; color: Theme.tertiary }
                Label { anchors.verticalCenter: parent.verticalCenter; text: Math.round(Weather.temp) + "°"; size: 14; weight: 650; elide: Text.ElideNone }
            }
            TapHandler { onTapped: root.mode = root.mode === "weather" ? "compact" : "weather" }
        }

        // трек
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasPlayer
            width: 4; height: 4; radius: 2
            color: Qt.alpha(Theme.fg, 0.35)
        }
        Row {
            id: mediaChip
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasPlayer
            spacing: 8
            HoverHandler { id: mediaHover; onHoveredChanged: if (hovered) openMedia.restart() }
            TapHandler { onTapped: root.mode = "media" }

            ClippingRectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                radius: root.player?.isPlaying ? 7 : 12
                color: Theme.surfaceHigh
                Behavior on radius { Anim { kind: "fast" } }
                Image {
                    anchors.fill: parent
                    source: Players.art(root.player)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 48; sourceSize.height: 48
                    asynchronous: true
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 260)
                text: (root.player?.trackTitle ?? "") + ((root.player?.trackArtist ?? "") !== "" ? "  ·  " + root.player.trackArtist : "")
                size: 13
                weight: 550
            }
            Equalizer {
                anchors.verticalCenter: parent.verticalCenter
                playing: root.player?.isPlaying ?? false
            }
        }
    }

    // ───────────── expanded ─────────────
    Loader {
        anchors.fill: parent
        active: root.mode === "media" || opacity > 0
        opacity: root.mode === "media" ? 1 : 0
        scale: root.mode === "media" ? 1 : 0.94
        Behavior on opacity { Anim { kind: "effects"; duration: root.mode === "media" ? 320 : 160 } }
        Behavior on scale { Anim { kind: "spatial" } }
        sourceComponent: MediaCard { player: root.player }
    }
    Loader {
        anchors.fill: parent
        active: root.mode === "weather" || opacity > 0
        opacity: root.mode === "weather" ? 1 : 0
        scale: root.mode === "weather" ? 1 : 0.94
        Behavior on opacity { Anim { kind: "effects"; duration: root.mode === "weather" ? 320 : 160 } }
        Behavior on scale { Anim { kind: "spatial" } }
        sourceComponent: WeatherCard { now: clock.date }
    }
}
