import QtQuick

QtObject {
    id: tokens

    property bool reducedMotion: false

    readonly property color canvas: "#111216"
    readonly property color surface: "#191a20"
    readonly property color surfaceLow: "#1d1e25"
    readonly property color surfaceHigh: "#24262e"
    readonly property color surfaceHighest: "#2d3039"
    readonly property color panel: surfaceHigh
    readonly property color control: surfaceLow
    readonly property color controlHover: surfaceHighest
    readonly property color foreground: "#eeeaf4"
    readonly property color muted: "#aaa6b3"
    readonly property color accent: "#d0bcff"
    readonly property color accentForeground: "#302746"
    readonly property color accentSoft: "#332c3d"
    readonly property color accentHover: "#41384f"
    readonly property color decoration: "#b7b1c2"
    readonly property color outline: "#30313a"
    readonly property color danger: "#ffb4ab"
    readonly property color success: "#b9d6c3"
    readonly property color warning: "#e4c48e"
    readonly property color preview: "#090a0d"

    readonly property int radiusSmall: 10
    readonly property int radiusMedium: 16
    readonly property int radiusLarge: 24
    readonly property int radiusExtraLarge: 32
    readonly property int radiusFull: 999

    readonly property int space2: 4
    readonly property int space4: 8
    readonly property int space6: 12
    readonly property int space8: 16
    readonly property int space10: 20
    readonly property int space14: 28
    readonly property int space16: 32

    readonly property int textXs: 12
    readonly property int textSm: 13
    readonly property int textMd: 14
    readonly property int textLg: 17
    readonly property int textXl: 22

    readonly property int effectFast: reducedMotion ? 1 : 150
    readonly property int effectDefault: reducedMotion ? 1 : 200
    readonly property int effectSlow: reducedMotion ? 1 : 300
    readonly property int spatialFast: reducedMotion ? 1 : 350
    readonly property int spatialDefault: reducedMotion ? 1 : 500
    readonly property int spatialSlow: reducedMotion ? 1 : 650

    readonly property int outerMargin: 14
    readonly property int toolbarHeight: 56
    readonly property int inspectorWidth: 292
    readonly property int timelineHeight: 178
}
