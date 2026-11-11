import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "inspectorPanel"
    property var tokens
    property var clipBackend
    property string selectedTool: "Corte"
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

    function outputSummary() {
        if (!root.clipBackend.hasVideo) return ""
        const source = root.clipBackend.videoWidth + " × " + root.clipBackend.videoHeight
        if (root.selectedCodec === "copy") return source + " · sem recorte (vídeo copiado)"
        const size = root.clipBackend.cropSize
        if (!size.cropped) return source + " · sem recorte"
        return source + " → " + size.width + " × " + size.height + " · " + root.selectedRatio
    }

    width: selectedTool === "Corte" ? 0 : Math.min(252, Math.max(220, parent.width * 0.26))
    height: parent.height
    color: "transparent"
    clip: true

    StackLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 8
        anchors.topMargin: 16
        anchors.bottomMargin: 14
        currentIndex: root.selectedTool === "Áudio" ? 1 : 0

        Column {
            spacing: 12
            Text { text: "Enquadrar"; color: root.tokens.foreground; font.pixelSize: root.tokens.textXl; font.weight: Font.DemiBold }
            Text { text: "PROPORÇÃO"; color: root.tokens.muted; font.pixelSize: root.tokens.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: ["Original", "4:3", "16:9", "21:9", "9:16", "1:1", "4:5", "Livre"]
                    delegate: ActionButton {
                        required property string modelData
                        tokens: root.tokens; text: modelData; compact: true
                        checked: root.selectedRatio === modelData
                        onClicked: root.ratioRequested(modelData)
                    }
                }
            }
            LineEdit {
                id: customRatioInput
                width: parent.width; tokens: root.tokens
                visible: root.selectedRatio === "Livre"
                text: root.customRatioValue; placeholderText: "Ex.: 3:2"
                invalid: !root.customRatioValid
                onEditingFinished: root.customRatioRequested(text)
            }
            // Typing in the field breaks the text binding, so mirror the shared
            // value back whenever it changes somewhere else.
            Connections {
                target: root
                function onCustomRatioValueChanged() {
                    if (!customRatioInput.activeFocus) customRatioInput.text = root.customRatioValue
                }
            }
            ActionButton { tokens: root.tokens; text: "Centralizar moldura"; symbol: "⊙"; enabled: root.clipBackend.hasVideo; onClicked: root.centerCropRequested() }
            Rectangle { width: parent.width; height: 1; color: root.tokens.outline }
            Text {
                visible: root.clipBackend.hasVideo
                text: root.outputSummary()
                color: root.tokens.muted; font.pixelSize: root.tokens.textXs
                wrapMode: Text.WordWrap
            }
        }

        Column {
            spacing: 13
            Text { text: "Áudio"; color: root.tokens.foreground; font.pixelSize: root.tokens.textXl; font.weight: Font.DemiBold }
            Rectangle { width: parent.width; height: 1; color: root.tokens.outline }
            Row {
                width: parent.width; height: 42; spacing: 10
                Rectangle {
                    width: 38; height: 24; radius: root.tokens.radiusFull
                    color: root.includeAudio ? root.tokens.accentSoft : root.tokens.surfaceHigh
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { x: root.includeAudio ? 18 : 3; y: 3; width: 18; height: 18; radius: 9; color: root.includeAudio ? root.tokens.accent : root.tokens.muted; Behavior on x { NumberAnimation { duration: root.tokens.effectFast } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.includeAudioToggled(!root.includeAudio) }
                }
                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: "Incluir áudio"; color: root.tokens.foreground; font.pixelSize: root.tokens.textSm; font.weight: Font.Medium }
                    Text { text: root.clipBackend.hasAudio ? "AAC estéreo · 192 kb/s" : "Nenhuma faixa de áudio detectada"; color: root.tokens.muted; font.pixelSize: root.tokens.textXs }
                }
            }
            Text { text: "VOLUME DA PRÉVIA"; color: root.tokens.muted; font.pixelSize: root.tokens.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Row {
                width: parent.width; spacing: 8
                ActionButton { tokens: root.tokens; text: root.audioMuted ? "Ativar" : "Mudo"; compact: true; kind: "quiet"; onClicked: root.audioMuteToggled(!root.audioMuted) }
                TonalSlider { id: volumeSlider; objectName: "volumeSlider"; tokens: root.tokens; width: Math.max(70, parent.width - 74); from: 0; to: 1; value: 0.8; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
