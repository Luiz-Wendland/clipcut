import QtQuick
import QtQuick.Controls as Controls

Rectangle {
    id: root
    property var tokens
    property alias text: input.text
    property alias fontFamily: input.font.family
    property string placeholderText: ""
    property bool readOnly: false
    property bool invalid: false
    signal editingFinished
    signal textEdited(string text)
    implicitHeight: 38
    radius: tokens.radiusSmall
    color: input.activeFocus ? tokens.surfaceHigh : tokens.surfaceLow
    border.width: input.activeFocus ? 1 : 0
    border.color: invalid ? tokens.danger : tokens.accent
    Behavior on color { ColorAnimation { duration: root.tokens.effectFast } }

    Controls.TextField {
        id: input
        objectName: "lineEditInput"
        anchors.fill: parent
        leftPadding: 12
        rightPadding: 12
        topPadding: 6
        bottomPadding: 6
        color: root.tokens.foreground
        placeholderText: root.placeholderText
        placeholderTextColor: root.tokens.muted
        readOnly: root.readOnly
        selectByMouse: true
        font.pixelSize: root.tokens.textSm
        background: Item {}
        onEditingFinished: root.editingFinished()
        onTextEdited: root.textEdited(text)
    }
}
