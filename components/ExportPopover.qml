import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "exportPopover"
    property var tokens
    property var clipBackend
    property real windowWidth: parent ? parent.width : 1200
    property real windowHeight: parent ? parent.height : 800
    property bool open: false
    property string selectedCodec: "h264"
    property string selectedQuality: "High quality"
    property string selectedRatio: "Original"
    property string customRatioValue: "3:2"
    property bool customRatioValid: true
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
        // Stream copy keeps the source untouched, so it must report the source size.
        if (root.selectedCodec === "copy")
            return root.clipBackend.videoWidth + " × " + root.clipBackend.videoHeight
        const size = root.clipBackend.cropSize
        return size.width + " × " + size.height
    }
    function framingSummary() {
        if (!root.clipBackend.hasVideo) return ""
        if (root.selectedCodec === "copy") return qsTr("uncropped (stream copy)")
        const size = root.clipBackend.cropSize
        if (!size.cropped) return qsTr("Original framing")
        return qsTr("Crop %1 · %2 × %3").arg(root.ratioLabel(root.selectedRatio)).arg(size.width).arg(size.height)
    }
    function ratioLabel(ratio) {
        return ratio === "Custom" ? qsTr("Custom") : ratio
    }
    function qualityLabel(quality) {
        if (quality === "High quality") return qsTr("High quality")
        if (quality === "Maximum quality") return qsTr("Maximum quality")
        return qsTr("Compact")
    }
    function encoderSummary() {
        if (root.selectedCodec === "copy") return qsTr("Stream copy")
        const codecName = ({ h264: "H.264", hevc: "HEVC", av1: "AV1" })[root.selectedCodec] || root.selectedCodec
        const gpuAvailable = root.clipBackend.hardwareEncoderAvailable(root.selectedCodec)
        if (root.clipBackend.preferGpu && !gpuAvailable)
            return codecName + " · " + qsTr("CPU (GPU unavailable)")
        const encoder = root.clipBackend.preferGpu
                ? root.clipBackend.hardwareEncoderName(root.selectedCodec) : "CPU"
        return codecName + " · " + encoder
    }
    function durationSummary() {
        const total = Math.max(0, root.clipBackend.clipEnd - root.clipBackend.clipStart)
        const rounded = Math.round(total * 100) / 100
        const minutes = Math.floor(rounded / 60)
        const seconds = Math.round((rounded - minutes * 60) * 100) / 100
        return String(minutes).padStart(2, "0") + ":" +
               seconds.toFixed(2).padStart(5, "0")
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
        RowLayout {
            width: parent.width; height: 44
            spacing: 8
            Column {
                Layout.fillWidth: true
                spacing: 2
                Text { text: qsTr("Export clip"); color: root.tokens.foreground; font.pixelSize: root.tokens.textXl; font.weight: Font.DemiBold }
                Text { text: root.clipBackend.fileName || qsTr("Choose output settings"); color: root.tokens.muted; font.pixelSize: root.tokens.textXs; elide: Text.ElideMiddle; width: parent.width }
            }
            ActionButton { tokens: root.tokens; text: "×"; kind: "quiet"; compact: true; Layout.alignment: Qt.AlignVCenter; onClicked: root.closeRequested() }
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
                    width: parent.width; tokens: root.tokens; title: qsTr("Folder and file name")
                    detail: root.outputName + "." + root.outputFormat
                    expanded: true
                    Row {
                        width: parent.width; spacing: 6
                        LineEdit {
                            width: parent.width - browseButton.width - 6; tokens: root.tokens
                            text: root.outputDirectory; placeholderText: qsTr("Choose a folder…"); readOnly: true
                        }
                        ActionButton { id: browseButton; tokens: root.tokens; text: qsTr("Browse…"); compact: true; onClicked: root.browseRequested() }
                    }
                    LineEdit {
                        id: outputNameField
                        objectName: "outputNameField"
                        width: parent.width
                        tokens: root.tokens
                        text: root.outputName
                        placeholderText: qsTr("Clip name")
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
                    title: qsTr("Video")
                    detail: root.selectedCodec.toUpperCase() + " · " + (root.selectedCodec === "copy" ? qsTr("copy") : root.qualityLabel(root.selectedQuality))
                    expanded: true
                    Text { text: qsTr("CODEC"); color: root.tokens.muted; font.pixelSize: root.tokens.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: [{ id: "h264", name: "H.264" }, { id: "hevc", name: "HEVC" }, { id: "av1", name: "AV1" }, { id: "copy", name: qsTr("Stream copy") }]
                            delegate: ActionButton {
                                required property var modelData
                                tokens: root.tokens; text: modelData.name; compact: true
                                checked: root.selectedCodec === modelData.id
                                onClicked: root.codecChanged(modelData.id)
                            }
                        }
                    }
                    Text {
                        text: qsTr("ENCODER")
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
                        text: qsTr(root.clipBackend.hardwareEncoderStatus(root.selectedCodec))
                        color: root.tokens.muted
                        font.pixelSize: root.tokens.textXs
                        wrapMode: Text.WordWrap
                    }
                    Text { text: qsTr("QUALITY"); visible: root.selectedCodec !== "copy"; color: root.tokens.muted; font.pixelSize: root.tokens.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
                    Flow {
                        width: parent.width; spacing: 6; visible: root.selectedCodec !== "copy"
                        Repeater {
                            model: ["High quality", "Maximum quality", "Compact"]
                            delegate: ActionButton {
                                required property string modelData
                                tokens: root.tokens
                                text: modelData === "High quality" ? qsTr("High") : modelData === "Maximum quality" ? qsTr("Maximum") : qsTr("Compact")
                                compact: true; checked: root.selectedQuality === modelData
                                onClicked: root.qualityChanged(modelData)
                            }
                        }
                    }
                    Text {
                        visible: root.selectedCodec === "copy"; width: parent.width
                            text: qsTr("Copies the original video without re-encoding. Crop, quality, and target size do not apply. Trim points may snap to keyframes.")
                        color: root.tokens.muted; font.pixelSize: root.tokens.textXs; wrapMode: Text.WordWrap
                    }
                }

                Disclosure {
                    width: parent.width; tokens: root.tokens; title: qsTr("Crop")
                    detail: root.selectedCodec === "copy" ? qsTr("not applicable") : root.ratioLabel(root.selectedRatio)
                    expanded: false
                    Flow {
                        width: parent.width; spacing: 6
                        enabled: root.selectedCodec !== "copy"
                        Repeater {
                            model: ["Original", "4:3", "16:9", "21:9", "9:16", "1:1", "4:5", "Custom"]
                            delegate: ActionButton {
                                required property string modelData
                                tokens: root.tokens; text: root.ratioLabel(modelData); compact: true
                                checked: root.selectedRatio === modelData
                                onClicked: root.ratioChanged(modelData)
                            }
                        }
                    }
                    LineEdit {
                        id: customRatioInput
                        width: parent.width; tokens: root.tokens
                        visible: root.selectedRatio === "Custom" && root.selectedCodec !== "copy"
                        text: root.customRatioValue; placeholderText: qsTr("Aspect ratio · e.g. 3:2")
                        invalid: !root.customRatioValid
                        onTextEdited: text => root.customRatioChanged(text)
                        onEditingFinished: root.customRatioChanged(text)
                    }
                    Text {
                        width: parent.width; visible: root.selectedCodec === "copy"
                        text: qsTr("Stream copy preserves the original dimensions, so cropping is disabled.")
                        color: root.tokens.muted; font.pixelSize: root.tokens.textXs; wrapMode: Text.WordWrap
                    }
                    Connections {
                        target: root
                        function onCustomRatioValueChanged() {
                            if (!customRatioInput.activeFocus) customRatioInput.text = root.customRatioValue
                        }
                    }
                }

                Disclosure {
                    width: parent.width; tokens: root.tokens; title: qsTr("Audio")
                    detail: !root.includeAudio ? qsTr("Off") :
                            root.clipBackend.hasAudio ? "AAC · 192 kb/s" : qsTr("No source audio")
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
                            Text { text: qsTr("Include audio track"); color: root.tokens.foreground; font.pixelSize: root.tokens.textSm }
                            Text { text: root.clipBackend.hasAudio ? qsTr("Stereo AAC, 192 kb/s") : qsTr("This file has no audio"); color: root.tokens.muted; font.pixelSize: root.tokens.textXs }
                        }
                    }
                }

                Disclosure {
                    width: parent.width; tokens: root.tokens; title: qsTr("Target size")
                    detail: root.targetSizeEnabled ? "~" + root.targetSizeValue + " MB" : qsTr("Off")
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
                        Text { text: qsTr("Estimated size"); color: root.tokens.foreground; font.pixelSize: root.tokens.textSm; anchors.verticalCenter: parent.verticalCenter }
                    }
                    LineEdit {
                        id: targetSizeInput
                        width: parent.width; tokens: root.tokens
                        visible: root.targetSizeEnabled
                        text: root.targetSizeValue
                        placeholderText: qsTr("Size in MB")
                        onTextEdited: text => root.targetValueEdited(text)
                        onEditingFinished: root.targetValueEdited(text)
                    }
                    Text { visible: root.targetSizeEnabled; width: parent.width; text: qsTr("Single-pass encoding; final size may vary."); color: root.tokens.muted; font.pixelSize: root.tokens.textXs; wrapMode: Text.WordWrap }
                }

                Disclosure {
                    width: parent.width
                    tokens: root.tokens
                    title: qsTr("Export queue")
                    detail: root.clipBackend.queuedExportCount === 1
                            ? qsTr("1 queued")
                            : qsTr("%1 queued").arg(root.clipBackend.queuedExportCount)
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
                                    queued: qsTr("Queued"), exporting: qsTr("Exporting"), done: qsTr("Completed"),
                                    failed: qsTr("Failed"), cancelled: qsTr("Canceled")
                                })[modelData.status]
                                color: root.tokens.foreground
                                font.pixelSize: root.tokens.textXs
                                elide: Text.ElideMiddle
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            ActionButton {
                                tokens: root.tokens
                                text: qsTr("Remove")
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
                            text: root.clipBackend.exportQueueRunning ? qsTr("Processing queue…") : qsTr("Run queue")
                            compact: true
                            kind: "primary"
                            enabled: root.clipBackend.queuedExportCount > 0 && !root.clipBackend.exportQueueRunning
                            onClicked: root.startQueueRequested()
                        }
                        ActionButton {
                            tokens: root.tokens
                            text: qsTr("Clear finished jobs")
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
            height: 94
            radius: root.tokens.radiusMedium
            color: root.tokens.surface
            border.color: root.tokens.outline
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3
                RowLayout {
                    width: parent.width
                    spacing: 8
                    Text {
                        text: root.outputResolution() + " px"
                        color: root.tokens.foreground
                        font.pixelSize: root.tokens.textSm
                        font.weight: Font.DemiBold
                        font.family: "monospace"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
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
                    text: root.encoderSummary() +
                          (root.clipBackend.fps > 0 ? " · " + Math.round(root.clipBackend.fps) + " fps" : "") +
                          " · " + root.outputFormat.toUpperCase() +
                          " · " + (root.includeAudio && root.clipBackend.hasAudio ? "AAC" : qsTr("no audio"))
                    color: root.tokens.muted
                    font.pixelSize: root.tokens.textXs
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: root.clipBackend.hasVideo
                    text: root.framingSummary()
                    color: root.tokens.muted
                    font.pixelSize: root.tokens.textXs
                    elide: Text.ElideRight
                }
                Text {
                    text: root.targetSizeEnabled && root.selectedCodec !== "copy"
                          ? qsTr("Approximate target size: %1 MB").arg(root.targetSizeValue)
                          : qsTr("Final size depends on the content")
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
                text: qsTr("Add to queue")
                compact: true
                kind: "tonal"
                enabled: root.clipBackend.hasVideo && !root.clipBackend.busy
                width: (parent.width - parent.spacing) / 2
                onClicked: {
                    if (outputNameField.text.trim() !== root.outputName) {
                        root.outputNameRequested(outputNameField.text)
                        const cleaned = outputNameField.text.trim().replace(/\.(mp4|mkv)$/i, "").replace(/[. ]+$/, "")
                        if (cleaned !== root.outputName) return
                    }
                    root.queueRequested()
                }
            }
            ActionButton {
                tokens: root.tokens
                text: root.clipBackend.busy ? qsTr("Canceling…") : qsTr("Export video")
                symbol: "↗"; kind: "primary"
                enabled: root.clipBackend.hasVideo && !root.clipBackend.busy
                width: (parent.width - parent.spacing) / 2
                onClicked: {
                    if (outputNameField.text.trim() !== root.outputName) {
                        root.outputNameRequested(outputNameField.text)
                        const cleaned = outputNameField.text.trim().replace(/\.(mp4|mkv)$/i, "").replace(/[. ]+$/, "")
                        if (cleaned !== root.outputName) return
                    }
                    root.exportRequested()
                }
            }
        }
    }

    Connections {
        target: root
        function onOutputNameChanged() { outputNameField.text = root.outputName }
    }
}
