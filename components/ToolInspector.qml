import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "inspectorPanel"
    property var tokens
    property var clipBackend
    property string selectedTool: "Trim"
    property string selectedRatio: "Original"
    property string customRatioValue: "3:2"
    property bool customRatioValid: true
    property string selectedCodec: "h264"
    property bool includeAudio: true
    property bool audioMuted: false
    property alias volume: volumeSlider.value

    signal ratioRequested(string ratio)
    signal customRatioRequested(string ratio)
    signal centerCropRequested
    signal includeAudioToggled(bool value)
    signal audioMuteToggled(bool value)
    signal returnFocusRequested

    function outputSummary() {
        if (!root.clipBackend.hasVideo) return ""
        const source = root.clipBackend.videoWidth + " × " + root.clipBackend.videoHeight
        if (root.selectedCodec === "copy") return source + " · " + qsTr("uncropped (stream copy)")
        const size = root.clipBackend.cropSize
        if (!size.cropped) return source + " · " + qsTr("uncropped")
        const ratio = root.selectedRatio === "Custom" ? qsTr("Custom") : root.selectedRatio
        return source + " → " + size.width + " × " + size.height + " · " + ratio
    }

    width: selectedTool === "Trim" ? 0 : Math.min(252, Math.max(220, parent.width * 0.26))
    height: parent.height
    visible: width > 0
    enabled: selectedTool !== "Trim"
    color: "transparent"
    clip: true

    StackLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 8
        anchors.topMargin: 16
        anchors.bottomMargin: 14
        currentIndex: root.selectedTool === "Audio" ? 1 : 0

        Column {
            spacing: 12
            Text { text: qsTr("Crop"); color: root.tokens.foreground; font.pixelSize: root.tokens.textXl; font.weight: Font.DemiBold }
            Text { text: qsTr("ASPECT RATIO"); color: root.tokens.muted; font.pixelSize: root.tokens.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: ["Original", "4:3", "16:9", "21:9", "9:16", "1:1", "4:5", "Custom"]
                    delegate: ActionButton {
                        required property string modelData
                        tokens: root.tokens; text: modelData === "Custom" ? qsTr("Custom") : modelData; compact: true
                        checked: root.selectedRatio === modelData
                        onClicked: root.ratioRequested(modelData)
                    }
                }
            }
            LineEdit {
                id: customRatioInput
                width: parent.width; tokens: root.tokens
                visible: root.selectedRatio === "Custom"
                text: root.customRatioValue; placeholderText: qsTr("e.g. 3:2")
                invalid: !root.customRatioValid
                onTextEdited: text => root.customRatioRequested(text)
                onEditingFinished: root.customRatioRequested(text)
                onAccepted: root.returnFocusRequested()
            }
            // Typing in the field breaks the text binding, so mirror the shared
            // value back whenever it changes somewhere else.
            Connections {
                target: root
                function onCustomRatioValueChanged() {
                    if (!customRatioInput.activeFocus) customRatioInput.text = root.customRatioValue
                }
            }
            ActionButton { tokens: root.tokens; text: qsTr("Center crop"); symbol: "⊙"; enabled: root.clipBackend.hasVideo; onClicked: root.centerCropRequested() }
            Rectangle { width: parent.width; height: 1; color: root.tokens.outline }
            Text {
                width: parent.width
                visible: root.clipBackend.hasVideo
                text: root.outputSummary()
                color: root.tokens.muted; font.pixelSize: root.tokens.textXs
                wrapMode: Text.WordWrap
            }
        }

        Column {
            spacing: 13
            Text { text: qsTr("Audio"); color: root.tokens.foreground; font.pixelSize: root.tokens.textXl; font.weight: Font.DemiBold }
            Rectangle { width: parent.width; height: 1; color: root.tokens.outline }
            RowLayout {
                width: parent.width; height: 42; spacing: 10
                Rectangle {
                    width: 38; height: 24; radius: root.tokens.radiusFull
                    color: root.includeAudio ? root.tokens.accentSoft : root.tokens.surfaceHigh
                    border.width: activeFocus ? 2 : 0
                    border.color: root.tokens.accent
                    activeFocusOnTab: true
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: qsTr("Include audio")
                    Accessible.checked: root.includeAudio
                    Keys.onSpacePressed: function(event) { root.includeAudioToggled(!root.includeAudio); event.accepted = true }
                    Keys.onReturnPressed: function(event) { root.includeAudioToggled(!root.includeAudio); event.accepted = true }
                    Layout.alignment: Qt.AlignVCenter
                    Rectangle { x: root.includeAudio ? 18 : 3; y: 3; width: 18; height: 18; radius: 9; color: root.includeAudio ? root.tokens.accent : root.tokens.muted; Behavior on x { NumberAnimation { duration: root.tokens.effectFast } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.includeAudioToggled(!root.includeAudio) }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: inspectorAudioLabelCol.implicitHeight
                    Column {
                        id: inspectorAudioLabelCol
                        width: parent.width
                        spacing: 2
                        Text { width: parent.width; text: qsTr("Include audio"); color: root.tokens.foreground; font.pixelSize: root.tokens.textSm; font.weight: Font.Medium; elide: Text.ElideRight }
                        Text { width: parent.width; text: root.clipBackend.hasAudio ? qsTr("Stereo AAC · 192 kb/s") : qsTr("No audio track detected"); color: root.tokens.muted; font.pixelSize: root.tokens.textXs; elide: Text.ElideRight }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.includeAudioToggled(!root.includeAudio) }
                }
            }
            Text { text: qsTr("PREVIEW VOLUME"); color: root.tokens.muted; font.pixelSize: root.tokens.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            RowLayout {
                width: parent.width; spacing: 8
                ActionButton { tokens: root.tokens; text: root.audioMuted ? qsTr("Unmute") : qsTr("Mute"); compact: true; kind: "quiet"; Layout.alignment: Qt.AlignVCenter; onClicked: root.audioMuteToggled(!root.audioMuted) }
                TonalSlider { id: volumeSlider; objectName: "volumeSlider"; tokens: root.tokens; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; from: 0; to: 1; value: 0.8 }
            }
        }
    }
}
