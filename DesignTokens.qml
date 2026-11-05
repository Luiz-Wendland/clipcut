import QtQuick

QtObject {
    id: tokens

    property string mode: "ClipCut"
    property bool reducedMotion: false
    property var systemColors: ({})

    readonly property color canvas: mode === "KDE"
                                    ? (systemColors.bg || "#141212") : "#111216"
    readonly property color surface: mode === "KDE"
                                    ? (systemColors.viewbg || "#101116") : "#191a20"
    readonly property color surfaceLow: mode === "KDE"
                                       ? (systemColors.bg || "#141212") : "#1d1e25"
    readonly property color surfaceHigh: mode === "KDE"
                                        ? (systemColors.buttonbg || "#24262e") : "#24262e"
    readonly property color surfaceHighest: mode === "KDE"
                                           ? (systemColors.buttonalt || "#2d3039") : "#2d3039"
    readonly property color panel: mode === "KDE"
                                  ? (systemColors.bg || "#141212") : surfaceHigh
    readonly property color control: mode === "KDE"
                                    ? (systemColors.buttonbg || surfaceHigh) : surfaceLow
    readonly property color controlHover: mode === "KDE"
                                         ? (systemColors.buttonalt || surfaceHighest) : surfaceHighest
    readonly property color foreground: mode === "KDE"
                                       ? (systemColors.fg || "#f4f1ee") : "#eeeaf4"
    readonly property color muted: mode === "KDE"
                                  ? (systemColors.fgdim || "#a8a4a0") : "#aaa6b3"
    readonly property color accent: mode === "KDE"
                                   ? (systemColors.accent || "#d0bcff") : "#d0bcff"
    readonly property color onAccent: mode === "KDE"
                                     ? (systemColors.onaccent || "#271d37") : "#302746"
    readonly property color accentSoft: mode === "KDE"
                                        ? Qt.rgba(accent.r, accent.g, accent.b, 0.22) : "#332c3d"
    readonly property color accentHover: mode === "KDE"
                                         ? (systemColors.accentHover || Qt.lighter(accent, 1.08)) : "#41384f"
    readonly property color decoration: mode === "KDE"
                                       ? (systemColors.decoration || systemColors.focus || foreground) : "#b7b1c2"
    readonly property color outline: mode === "KDE"
                                     ? Qt.rgba(decoration.r, decoration.g, decoration.b, 0.2)
                                     : "#30313a"
    readonly property color danger: mode === "KDE" ? (systemColors.negative || "#ffb4ab") : "#ffb4ab"
    readonly property color success: mode === "KDE" ? (systemColors.positive || "#b9d6c3") : "#b9d6c3"
    readonly property color warning: mode === "KDE" ? (systemColors.neutral || "#e4c48e") : "#e4c48e"
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
