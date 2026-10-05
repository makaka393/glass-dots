pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Все настройки бара в одном месте. Цвета берутся из matugen
// (~/.cache/matugen/colors.json) и плавно перетекают при смене обоев.
Singleton {
    id: root

    // ───────── настройки ─────────
    readonly property string city: "София"
    readonly property real lat: 42.6977
    readonly property real lon: 23.3219
    readonly property int workspaceCount: 5
    readonly property bool mediaPeek: true      // при смене трека остров на 2.5с раскрывается в плеер
    readonly property real glassOpacity: 0.34   // прозрачность стекла (0 — только blur, 1 — сплошной фон)
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Downloads/Wallpapers"   // папка с обоями для выбора

    // ───────── размеры ─────────
    readonly property int barHeight: 40
    readonly property int outer: 8              // отступ от края экрана
    readonly property int gap: 8                // между островами
    readonly property int radiusCard: 28        // M3 extra-large

    // ───────── шрифты ─────────
    readonly property string font: "Google Sans Flex"
    readonly property string iconFont: "Material Symbols Rounded"

    // ───────── motion: токены M3 Expressive ─────────
    readonly property var spatial: [0.38, 1.21, 0.22, 1.00, 1, 1]       // default spatial, 500ms
    readonly property var spatialFast: [0.42, 1.67, 0.21, 0.90, 1, 1]   // fast spatial, 350ms
    readonly property var effects: [0.34, 0.80, 0.34, 1.00, 1, 1]       // default effects, 200ms
    readonly property var emphasized: [0.05, 0.70, 0.10, 1.00, 1, 1]
    readonly property int durSpatial: 500
    readonly property int durFast: 350
    readonly property int durEffects: 220

    // ───────── цвета (Material 3) ─────────
    readonly property color primary: c.primary
    readonly property color primaryFg: c.primaryFg
    readonly property color primaryContainer: c.primaryContainer
    readonly property color primaryContainerFg: c.primaryContainerFg
    readonly property color secondary: c.secondary
    readonly property color secondaryContainer: c.secondaryContainer
    readonly property color secondaryContainerFg: c.secondaryContainerFg
    readonly property color tertiary: c.tertiary
    readonly property color tertiaryContainer: c.tertiaryContainer
    readonly property color tertiaryContainerFg: c.tertiaryContainerFg
    readonly property color error: c.error
    readonly property color surface: c.surface
    readonly property color surfaceLowest: c.surfaceLowest
    readonly property color surfaceLow: c.surfaceLow
    readonly property color surfaceMid: c.surfaceMid
    readonly property color surfaceHigh: c.surfaceHigh
    readonly property color surfaceHighest: c.surfaceHighest
    readonly property color fg: c.surfaceFg
    readonly property color fgVariant: c.surfaceVariantFg
    readonly property color outline: c.outline
    readonly property color outlineVariant: c.outlineVariant

    // стекло
    readonly property color glass: Qt.alpha(surfaceLowest, glassOpacity)
    readonly property color glassStrong: Qt.alpha(surfaceLowest, Math.min(1, glassOpacity + 0.25))
    readonly property color glassBorder: Qt.alpha(fg, 0.10)
    readonly property color glassSheen: Qt.rgba(1, 1, 1, 0.06)
    readonly property color glassChip: Qt.alpha(fg, 0.08)

    function css(col) {
        return "rgba(" + Math.round(col.r * 255) + "," + Math.round(col.g * 255) + ","
               + Math.round(col.b * 255) + "," + col.a + ")";
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/matugen/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: c
            property string primary: "#a8c7fa"
            property string primaryFg: "#062e6f"
            property string primaryContainer: "#284777"
            property string primaryContainerFg: "#d6e3ff"
            property string secondary: "#bec6dc"
            property string secondaryContainer: "#3e4759"
            property string secondaryContainerFg: "#dae2f9"
            property string tertiary: "#ddbce0"
            property string tertiaryContainer: "#573e5c"
            property string tertiaryContainerFg: "#fad8fd"
            property string error: "#ffb4ab"
            property string surface: "#111318"
            property string surfaceLowest: "#0c0e13"
            property string surfaceLow: "#191c20"
            property string surfaceMid: "#1d2024"
            property string surfaceHigh: "#282a2f"
            property string surfaceHighest: "#33353a"
            property string surfaceFg: "#e2e2e9"
            property string surfaceVariantFg: "#c4c6d0"
            property string outline: "#8e9099"
            property string outlineVariant: "#44474f"
        }
    }
}
