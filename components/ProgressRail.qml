import QtQuick

Rectangle {
    id: root
    property var tokens
    property real value: 0
    property color fillColor: tokens.accent
    implicitWidth: 120
    implicitHeight: 4
    radius: tokens.radiusFull
    color: tokens.surfaceHighest
    Rectangle {
        width: Math.max(0, Math.min(1, root.value)) * parent.width
        height: parent.height
        radius: parent.radius
        color: root.fillColor
        Behavior on width { NumberAnimation { duration: root.tokens.effectFast; easing.type: Easing.OutCubic } }
    }
}
