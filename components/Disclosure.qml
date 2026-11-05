import QtQuick

Column {
    id: root
    property var tokens
    property string title: ""
    property string detail: ""
    property bool expanded: true
    default property alias contentData: content.data
    spacing: 0

    Rectangle {
        width: parent.width
        height: 38
        radius: tokens.radiusMedium
        color: headerMouse.containsMouse ? tokens.controlHover : "transparent"
        Behavior on color { ColorAnimation { duration: root.tokens.effectFast } }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8
            Text {
                text: root.title
                color: root.tokens.foreground
                font.pixelSize: root.tokens.textSm
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.detail
                visible: root.detail.length > 0
                color: root.tokens.muted
                font.pixelSize: root.tokens.textXs
                elide: Text.ElideRight
                width: Math.max(0, parent.width - 84)
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: 1; height: 1 }
            Text {
                text: "⌄"
                color: root.tokens.muted
                rotation: root.expanded ? 180 : 0
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
                Behavior on rotation { NumberAnimation { duration: root.tokens.effectFast; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }
    Item {
        id: body
        width: parent.width
        height: root.expanded ? content.implicitHeight : 0
        clip: true
        Behavior on height { NumberAnimation { duration: root.tokens.spatialFast; easing.type: Easing.OutCubic } }
        Column {
            id: content
            width: parent.width
            spacing: 9
            padding: 4
            onImplicitHeightChanged: body.height = root.expanded ? implicitHeight : 0
        }
    }
}
