import QtQuick
import QtQuick.Controls as Controls

Rectangle {
    id: root
    objectName: "exportPopover"
    property var tokens
    property var clipBackend
    property real windowWidth: parent ? parent.width : 1200
    property real windowHeight: parent ? parent.height : 800
    property bool open: false
    property string selectedCodec: "h264"
    property string selectedQuality: "Alta qualidade"
    property string selectedRatio: "Original"
    property string customRatioValue: "3:2"
    property bool includeAudio: true
    property bool targetSizeEnabled: false
    property string targetSizeValue: "100"
    property string outputDirectory: ""
    property string outputName: "clip-clipcut"
    property bool outputNameValid: true
    property string outputFormat: "mp4"

    signal codecChanged(string codec)
    signal encoderPreferenceChanged(bool useGpu)
    signal qualityChanged(string quality)
    signal ratioChanged(string ratio)
    signal customRatioChanged(string ratio)
    signal audioInclusionRequested(bool enabled)
    signal targetEnabledRequested(bool enabled)
    signal targetValueEdited(string value)
    signal outputNameRequested(string name)
    signal outputFormatRequested(string format)
    signal browseRequested
    signal exportRequested
    signal queueRequested
    signal startQueueRequested
    signal removeQueueRequested(int jobId)
    signal clearQueueRequested
    signal cancelRequested
    signal closeRequested

    function outputResolution() {
        if (!root.clipBackend.hasVideo) return "—"
        const crop = root.clipBackend.cropRect
        const width = Math.max(2, Math.floor(root.clipBackend.videoWidth * crop.width / 2) * 2)
        const height = Math.max(2, Math.floor(root.clipBackend.videoHeight * crop.height / 2) * 2)
        return width + " × " + height
    }
    function encoderSummary() {
        if (root.selectedCodec === "copy") return "Sem recodificar"
        const codecName = ({ h264: "H.264", hevc: "HEVC", av1: "AV1" })[root.selectedCodec] || root.selectedCodec
        const gpuAvailable = root.clipBackend.hardwareEncoderAvailable(root.selectedCodec)
        if (root.clipBackend.preferGpu && !gpuAvailable)
            return codecName + " · CPU (GPU indisponível)"
        const encoder = root.clipBackend.preferGpu
                ? root.clipBackend.hardwareEncoderName(root.selectedCodec) : "CPU"
        return codecName + " · " + encoder
    }
    function durationSummary() {
        const seconds = Math.max(0, root.clipBackend.clipEnd - root.clipBackend.clipStart)
        return String(Math.floor(seconds / 60)).padStart(2, "0") + ":" +
               (seconds % 60).toFixed(2).padStart(5, "0")
    }

    width: Math.min(390, windowWidth - 32)
    height: Math.min(620, Math.max(320, windowHeight - tokens.timelineHeight - 110))
    x: open ? windowWidth - width - 18 : windowWidth + 8
    y: 18
    z: 21
    radius: tokens.radiusExtraLarge
    color: tokens.panel
    border.color: tokens.outline
    visible: open || opacity > 0.01
    enabled: open
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.96
    transformOrigin: Item.TopRight
    Behavior on x { NumberAnimation { duration: root.tokens.spatialFast; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: root.tokens.effectDefault } }
    Behavior on scale { NumberAnimation { duration: root.tokens.spatialFast; easing.type: Easing.OutCubic } }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 13
        Row {
            width: parent.width; height: 44
            Column { spacing: 2
                Text { text: "Exportar clipe"; color: root.tokens.foreground; font.pixelSize: root.tokens.textXl; font.weight: Font.DemiBold }
                Text { text: root.clipBackend.fileName || "Defina as opções de saída"; color: root.tokens.muted; font.pixelSize: root.tokens.textXs; elide: Text.ElideMiddle; width: 280 }
            }
            Item { width: Math.max(0, parent.width - 330); height: 1 }
            ActionButton { tokens: root.tokens; text: "×"; kind: "quiet"; compact: true; onClicked: root.closeRequested() }
        }
        Rectangle { width: parent.width; height: 1; color: root.tokens.outline }
        Controls.ScrollView {
            id: exportScroll
            width: parent.width
            height: Math.max(64, parent.height - 213)
            clip: true
            contentWidth: availableWidth
            Column {
                width: exportScroll.availableWidth
                spacing: 14
                Disclosure {
                    width: parent.width; tokens: root.tokens; title: "Pasta e nome"
                    detail: root.outputName + "." + root.outputFormat
                    expanded: true
                    Row {
                        width: parent.width; spacing: 6
                        LineEdit {
                            width: parent.width - browseButton.width - 6; tokens: root.tokens
                            text: root.outputDirectory; placeholderText: "Escolha uma pasta…"; readOnly: true
                        }
                        ActionButton { id: browseButton; tokens: root.tokens; text: "Escolher…"; compact: true; onClicked: root.browseRequested() }
                    }
                    LineEdit {
                        id: outputNameField
                        objectName: "outputNameField"
                        width: parent.width
                        tokens: root.tokens
                        text: root.outputName
                        placeholderText: "Nome do clipe"
                        invalid: !root.outputNameValid
                        onEditingFinished: root.outputNameRequested(text)
                    }
                    Flow {
                        width: parent.width; spacing: 6
                        ActionButton { tokens: root.tokens; text: "MP4"; compact: true; checked: root.outputFormat === "mp4"; onClicked: root.outputFormatRequested("mp4") }
                        ActionButton { tokens: root.tokens; text: "MKV"; compact: true; checked: root.outputFormat === "mkv"; onClicked: root.outputFormatRequested("mkv") }
                    }
                }

                Disclosure {
                    width: parent.width
                    tokens: root.tokens
                    title: "Vídeo"
                    detail: root.selectedCodec.toUpperCase() + " · " + (root.selectedCodec === "copy" ? "cópia" : root.selectedQuality)
                    expanded: true
                    Text { text: "CODEC"; color: root.tokens.muted; font.pixelSize: root.tokens.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: [{ id: "h264", name: "H.264" }, { id: "hevc", name: "HEVC" }, { id: "av1", name: "AV1" }, { id: "copy", name: "Sem recodificar" }]
                            delegate: ActionButton {
                                required property var modelData
                                tokens: root.tokens; text: modelData.name; compact: true
                                checked: root.selectedCodec === modelData.id
                                onClicked: root.codecChanged(modelData.id)
                            }
                        }
                    }
                    Text {
                        text: "ENCODER"
                        visible: root.selectedCodec !== "copy"
                        color: root.tokens.muted
                        font.pixelSize: root.tokens.textXs
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                    Flow {
                        width: parent.width; spacing: 6
                        visible: root.selectedCodec !== "copy"
                        ActionButton {
                            tokens: root.tokens
                            text: "CPU"
                            compact: true
                            checked: !root.clipBackend.preferGpu ||
                                     !root.clipBackend.hardwareEncoderAvailable(root.selectedCodec)
                            onClicked: root.encoderPreferenceChanged(false)
                        }
                        ActionButton {
                            tokens: root.tokens
                            text: root.clipBackend.hardwareEncoderAvailable(root.selectedCodec)
                                  ? "GPU · " + root.clipBackend.hardwareEncoderName(root.selectedCodec)
                                  : "GPU"
                            compact: true
                            enabled: root.clipBackend.hardwareEncoderAvailable(root.selectedCodec)
                            checked: root.clipBackend.preferGpu && enabled
                            onClicked: root.encoderPreferenceChanged(true)
                        }
                    }
                    Text {
                        width: parent.width
                        visible: root.selectedCodec !== "copy" &&
                                 !root.clipBackend.hardwareEncoderAvailable(root.selectedCodec)
                        text: root.clipBackend.hardwareEncoderStatus(root.selectedCodec)
                        color: root.tokens.muted
                        font.pixelSize: root.tokens.textXs
                        wrapMode: Text.WordWrap
                    }
                    Text { text: "QUALIDADE"; visible: root.selectedCodec !== "copy"; color: root.tokens.muted; font.pixelSize: root.tokens.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
                    Flow {
                        width: parent.width; spacing: 6; visible: root.selectedCodec !== "copy"
                        Repeater {
                            model: ["Alta qualidade", "Máxima qualidade", "Compacto"]
                            delegate: ActionButton {
                                required property string modelData
                                tokens: root.tokens
                                text: modelData === "Alta qualidade" ? "Alta" : modelData === "Máxima qualidade" ? "Máxima" : "Compacto"
                                compact: true; checked: root.selectedQuality === modelData
                                onClicked: root.qualityChanged(modelData)
                            }
                        }
                    }
                    Text {
                        visible: root.selectedCodec === "copy"; width: parent.width
                            text: "Mantém o vídeo original sem recodificar. Enquadramento, qualidade e tamanho-alvo não se aplicam; o corte pode alinhar aos quadros-chave."
                        color: root.tokens.muted; font.pixelSize: root.tokens.textXs; wrapMode: Text.WordWrap
                    }
                }

                Disclosure {
                    width: parent.width; tokens: root.tokens; title: "Enquadramento"; detail: root.selectedRatio; expanded: false
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: ["Original", "4:3", "16:9", "21:9", "9:16", "1:1", "4:5", "Livre"]
                            delegate: ActionButton {
                                required property string modelData
                                tokens: root.tokens; text: modelData; compact: true
                                checked: root.selectedRatio === modelData
                                onClicked: root.ratioChanged(modelData)
                            }
                        }
                    }
                    LineEdit {
                        width: parent.width; tokens: root.tokens; visible: root.selectedRatio === "Livre"
                        text: root.customRatioValue; placeholderText: "Proporção · ex.: 3:2"
                        invalid: !/^[1-9][0-9]*:[1-9][0-9]*$/.test(root.customRatioValue)
                        onEditingFinished: root.customRatioChanged(text)
                    }
                }

                Disclosure {
                    width: parent.width; tokens: root.tokens; title: "Áudio"
                    detail: !root.includeAudio ? "Desativado" :
                            root.clipBackend.hasAudio ? "AAC · 192 kb/s" : "Sem faixa de origem"
                    expanded: false
                    Row {
                        width: parent.width; height: 40; spacing: 9
                        Rectangle {
                            width: 38; height: 24; radius: root.tokens.radiusFull
                            color: root.includeAudio ? root.tokens.accentSoft : root.tokens.surfaceHigh
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { x: root.includeAudio ? 18 : 3; y: 3; width: 18; height: 18; radius: 9; color: root.includeAudio ? root.tokens.accent : root.tokens.muted; Behavior on x { NumberAnimation { duration: root.tokens.effectFast } } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.audioInclusionRequested(!root.includeAudio) }
                        }
                        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { text: "Incluir faixa de áudio"; color: root.tokens.foreground; font.pixelSize: root.tokens.textSm }
                            Text { text: root.clipBackend.hasAudio ? "AAC estéreo, 192 kb/s" : "O arquivo não contém áudio"; color: root.tokens.muted; font.pixelSize: root.tokens.textXs }
                        }
                    }
                }

                Disclosure {
                    width: parent.width; tokens: root.tokens; title: "Tamanho-alvo"
                    detail: root.targetSizeEnabled ? "~" + root.targetSizeValue + " MB" : "Desativado"
                    expanded: false; visible: root.selectedCodec !== "copy"
                    Row {
                        width: parent.width; height: 40; spacing: 9
                        Rectangle {
                            width: 38; height: 24; radius: root.tokens.radiusFull
                            color: root.targetSizeEnabled ? root.tokens.accentSoft : root.tokens.surfaceHigh
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { x: root.targetSizeEnabled ? 18 : 3; y: 3; width: 18; height: 18; radius: 9; color: root.targetSizeEnabled ? root.tokens.accent : root.tokens.muted; Behavior on x { NumberAnimation { duration: root.tokens.effectFast } } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.targetEnabledRequested(!root.targetSizeEnabled) }
                        }
                        Text { text: "Estimativa de tamanho"; color: root.tokens.foreground; font.pixelSize: root.tokens.textSm; anchors.verticalCenter: parent.verticalCenter }
                    }
                    LineEdit { width: parent.width; tokens: root.tokens; visible: root.targetSizeEnabled; text: root.targetSizeValue; placeholderText: "Tamanho em MB"; onEditingFinished: root.targetValueEdited(text) }
                    Text { visible: root.targetSizeEnabled; width: parent.width; text: "Bitrate de uma passagem; o tamanho final pode variar."; color: root.tokens.muted; font.pixelSize: root.tokens.textXs; wrapMode: Text.WordWrap }
                }

                Disclosure {
                    width: parent.width
                    tokens: root.tokens
                    title: "Fila de exportação"
                    detail: root.clipBackend.queuedExportCount + " pendente(s)"
                    expanded: false
                    visible: root.clipBackend.queuedExports.length > 0
                    Repeater {
                        model: root.clipBackend.queuedExports
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            height: 30
                            spacing: 6
                            Text {
                                width: parent.width - 104
                                text: modelData.name + " · " + ({
                                    queued: "Pendente", exporting: "Exportando", done: "Concluído",
                                    failed: "Falhou", cancelled: "Cancelado"
                                })[modelData.status]
                                color: root.tokens.foreground
                                font.pixelSize: root.tokens.textXs
                                elide: Text.ElideMiddle
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            ActionButton {
                                tokens: root.tokens
                                text: "Remover"
                                compact: true
                                visible: modelData.status === "queued"
                                onClicked: root.removeQueueRequested(modelData.id)
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 6
                        ActionButton {
                            tokens: root.tokens
                            text: root.clipBackend.exportQueueRunning ? "Exportando fila…" : "Exportar fila"
                            compact: true
                            kind: "primary"
                            enabled: root.clipBackend.queuedExportCount > 0 && !root.clipBackend.exportQueueRunning
                            onClicked: root.startQueueRequested()
                        }
                        ActionButton {
                            tokens: root.tokens
                            text: "Limpar concluídos/fila"
                            compact: true
                            enabled: root.clipBackend.queuedExports.length > 0
                            onClicked: root.clearQueueRequested()
                        }
                    }
                }

            }
        }

        Rectangle {
            width: parent.width
            height: 76
            radius: root.tokens.radiusMedium
            color: root.tokens.surface
            border.color: root.tokens.outline
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3
                Row {
                    width: parent.width
                    Text {
                        text: root.outputResolution() + " px"
                        color: root.tokens.foreground
                        font.pixelSize: root.tokens.textSm
                        font.weight: Font.DemiBold
                        font.family: "monospace"
                    }
                    Item { width: Math.max(0, parent.width - 170); height: 1 }
                    Text {
                        text: root.durationSummary()
                        color: root.tokens.accent
                        font.pixelSize: root.tokens.textSm
                        font.weight: Font.DemiBold
                        font.family: "monospace"
                    }
                }
                Text {
                    width: parent.width
                    text: root.encoderSummary() + " · " + Math.round(root.clipBackend.fps) + " fps · " +
                          root.outputFormat.toUpperCase() +
                          (root.includeAudio && root.clipBackend.hasAudio ? " · AAC" : " · sem áudio")
                    color: root.tokens.muted
                    font.pixelSize: root.tokens.textXs
                    elide: Text.ElideRight
                }
                Text {
                    text: root.targetSizeEnabled && root.selectedCodec !== "copy"
                          ? "Tamanho-alvo aproximado: " + root.targetSizeValue + " MB"
                          : "Tamanho final variável conforme o conteúdo"
                    color: root.tokens.muted
                    font.pixelSize: root.tokens.textXs
                    elide: Text.ElideRight
                }
            }
        }

        Row {
            width: parent.width; height: 40; spacing: 6
            ActionButton {
                tokens: root.tokens
                text: "Adicionar à fila"
                compact: true
                kind: "tonal"
                enabled: root.clipBackend.hasVideo && !root.clipBackend.busy
                width: (parent.width - parent.spacing) / 2
                onClicked: root.queueRequested()
            }
            ActionButton {
                tokens: root.tokens
                text: root.clipBackend.busy ? "Cancelando…" : "Exportar vídeo"
                symbol: "↗"; kind: "primary"
                enabled: root.clipBackend.hasVideo && !root.clipBackend.busy
                width: (parent.width - parent.spacing) / 2
                onClicked: root.exportRequested()
            }
        }
    }

    Connections {
        target: root
        function onOutputNameChanged() { outputNameField.text = root.outputName }
    }
}
