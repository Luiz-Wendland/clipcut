import QtQuick

Rectangle {
    id: root

    property var tokens
    property string text: ""
    property string symbol: ""
    property string kind: "tonal" // primary, tonal, quiet, danger
    property bool checked: false
    property bool compact: false
    property int radiusOverride: -1

    signal clicked

    activeFocusOnTab: enabled
    Keys.onSpacePressed: function(event) { root.clicked(); event.accepted = true }
    Keys.onReturnPressed: function(event) { root.clicked(); event.accepted = true }

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    implicitWidth: Math.max(36, label.implicitWidth + (symbol.length ? 60 : 34))
    implicitHeight: compact ? 32 : 38
    radius: radiusOverride >= 0 ? radiusOverride : (pressed ? tokens.radiusMedium : tokens.radiusFull)
    color: {
        if (!enabled) return tokens.surfaceHigh
        if (kind === "primary") return pressed ? Qt.darker(tokens.accent, 1.08) : tokens.accent
        if (kind === "danger") return pressed ? "#8f403d" : "#633b3d"
        if (kind === "quiet") return hovered || checked ? tokens.controlHover : "transparent"
        return checked ? tokens.accentSoft : hovered ? tokens.controlHover : tokens.control
    }
    opacity: enabled ? 1 : 0.52
    border.width: activeFocus ? 2 : 0
    border.color: tokens.accent

    Behavior on color {
        ColorAnimation { duration: root.tokens.effectFast; easing.type: Easing.OutCubic }
    }
    Behavior on radius {
        NumberAnimation { duration: root.tokens.spatialFast; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
    }
    Behavior on scale {
        NumberAnimation { duration: root.tokens.effectFast; easing.type: Easing.OutCubic }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.symbol && root.text ? 7 : 0
        Text {
            visible: root.symbol.length > 0
            text: root.symbol
            color: root.kind === "primary" && root.enabled ? root.tokens.onAccent :
                   root.kind === "danger" ? root.tokens.foreground : root.tokens.foreground
            font.pixelSize: 15
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: label
            text: root.text
            visible: root.text.length > 0
            color: root.kind === "primary" && root.enabled ? root.tokens.onAccent : root.tokens.foreground
            font.pixelSize: root.compact ? root.tokens.textXs : root.tokens.textSm
            font.weight: root.kind === "primary" ? Font.DemiBold : Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: root.scale = 0.97
        onReleased: root.scale = 1
        onCanceled: root.scale = 1
        onClicked: root.clicked()
    }
}
