import QtQuick

Rectangle {
    id: root
    property var tokens
    property string title: ""
    property string symbol: ""
    property bool selected: false
    signal clicked

    activeFocusOnTab: enabled
    Keys.onSpacePressed: function(event) { root.clicked(); event.accepted = true }
    Keys.onReturnPressed: function(event) { root.clicked(); event.accepted = true }

    implicitWidth: 64
    implicitHeight: 54
    radius: selected ? tokens.radiusMedium : tokens.radiusLarge
    color: selected ? tokens.accentSoft : mouse.containsMouse ? tokens.controlHover : "transparent"
    opacity: enabled ? 1 : 0.45
    border.width: activeFocus ? 2 : 0
    border.color: tokens.accent
    Behavior on color { ColorAnimation { duration: root.tokens.effectFast } }
    Behavior on radius { NumberAnimation { duration: root.tokens.spatialFast; easing.type: Easing.OutCubic } }

    Column {
        anchors.centerIn: parent
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.symbol
            color: root.selected ? root.tokens.accent : root.tokens.muted
            font.pixelSize: 17
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: root.selected ? root.tokens.foreground : root.tokens.muted
            font.pixelSize: 11
            font.weight: root.selected ? Font.DemiBold : Font.Normal
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
