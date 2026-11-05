import QtQuick
import QtQuick.Controls as Controls

Controls.Slider {
    id: root
    property var tokens
    implicitWidth: 160
    implicitHeight: 28

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + (root.availableHeight - height) / 2
        width: root.availableWidth
        height: 4
        radius: 2
        color: root.tokens.surfaceHighest
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: root.tokens.accent
            Behavior on width { NumberAnimation { duration: root.tokens.effectFast; easing.type: Easing.OutCubic } }
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + (root.availableHeight - height) / 2
        width: root.pressed ? 17 : 13
        height: width
        radius: width / 2
        color: root.tokens.accent
        border.color: root.tokens.onAccent
        border.width: 2
        Behavior on width { NumberAnimation { duration: root.tokens.effectFast; easing.type: Easing.OutCubic } }
    }
}
