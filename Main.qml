import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.VectorImage
import QtMultimedia
import "components"

Window {
    id: root
    visible: true
    width: 1260
    height: 820
    minimumWidth: 860
    minimumHeight: 600
    title: "ClipCut"
    color: theme.canvas

    property string themeMode: "ClipCut"
    property bool reducedMotion: false
    property string activeTool: "Corte"
    property string selectedCodec: "h264"
    property string selectedQuality: "Alta qualidade"
    property string selectedRatio: "Original"
    property string customRatioValue: "3:2"
    property string lastValidCustomRatio: "3:2"
    property bool includeAudio: true
    property bool audioMuted: false
    property bool targetSizeEnabled: false
    property string targetSizeValue: "100"
    property bool playSelection: true
    property bool pendingAutoplay: false
    property bool dragHover: false
    property bool showExport: false
    property bool showSettings: false
    property bool showDiagnostics: false
    property bool showOverwrite: false
    property bool folderDialogForExport: false
    property bool folderDialogForQueue: false
    property string diagnosticsText: ""
    property string outputDirectory: ""
    property string outputName: "clip-clipcut"
    property string outputFormat: "mp4"
    property string pendingOutput: ""
    property string notice: ""
    property bool noticeError: false
    property real cropPressX: 0
    property real cropPressY: 0
    property real cropCenterX: 0.5
    property real cropCenterY: 0.5
    readonly property bool isPlaying: player.playbackState === MediaPlayer.PlayingState
    readonly property var tokens: theme
    readonly property var clipBackend: backend
    readonly property var mediaPlayer: player
    readonly property bool customRatioValid: /^[1-9][0-9]{0,3}:[1-9][0-9]{0,3}$/.test(customRatioValue)
    // The crop overlay only makes sense once the video frame is on screen:
    // until then VideoOutput.contentRect still covers the whole panel.
    readonly property bool showCropOverlay: backend.hasVideo &&
                                           root.activeTool === "Enquadrar" &&
                                           videoOutput.sourceRect.width > 0
    readonly property bool outputNameValid: outputName.trim().length > 0 &&
                                            outputName.trim() !== "." && outputName.trim() !== ".." &&
                                            !/[\/\\\x00-\x1f]/.test(outputName)

    Component.onCompleted: {
        const lastDirectory = backend.localPath(backend.lastExportDirectoryUrl.toString())
        if (!outputDirectory && lastDirectory) {
            outputDirectory = lastDirectory
            pendingOutput = generatedOutputPath(lastDirectory)
        }
    }

    DesignTokens {
        id: theme
        mode: root.themeMode
        reducedMotion: root.reducedMotion
        systemColors: backend.themePalette
    }

    function formatTime(seconds) {
        seconds = Math.max(0, Number(seconds) || 0)
        const rounded = Math.round(seconds * 100) / 100
        const minutes = Math.floor(rounded / 60)
        const rest = Math.round((rounded - minutes * 60) * 100) / 100
        return String(minutes).padStart(2, "0") + ":" + rest.toFixed(2).padStart(5, "0")
    }
    function applyRatio(ratio) {
        // The framing centre is preserved on purpose: only the crop window
        // changes, so a carefully placed crop is not thrown away.
        root.selectedRatio = ratio
        const custom = root.customRatioValid ? root.customRatioValue : root.lastValidCustomRatio
        backend.setCropRatio(ratio, custom)
    }
    function applyCustomRatio(ratio) {
        root.customRatioValue = ratio
        if (!root.customRatioValid) return
        root.lastValidCustomRatio = ratio
        backend.setCropRatio("Livre", ratio)
    }
    function showNotice(message, isError) {
        notice = message
        noticeError = isError
        noticeTimer.restart()
    }
    function defaultOutputName() {
        const sourceName = backend.fileName || "clip"
        const dot = sourceName.lastIndexOf(".")
        const stem = dot > 0 ? sourceName.slice(0, dot) : sourceName
        return stem + "-clipcut"
    }
    function updateOutputName(value) {
        let name = value.trim()
        name = name.replace(/\.(mp4|mkv)$/i, "").replace(/[. ]+$/, "")
        if (!name || name === "." || name === ".." || /[\/\\\x00-\x1f]/.test(name)) {
            showNotice("Use um nome de arquivo válido, sem barras.", true)
            return
        }
        outputName = name
        if (outputDirectory) {
            pendingOutput = generatedOutputPath(outputDirectory)
        }
    }
    function seekTo(seconds) {
        if (backend.hasVideo) player.position = Math.max(0, Math.min(player.duration, seconds * 1000))
    }
    function generatedOutputPath(directory) {
        const folder = directory === "/" ? "" : directory.replace(/\/+$/, "")
        return folder + "/" + (outputName.trim() || "clip-clipcut") + "." + outputFormat
    }
    function useGpuForSelectedCodec() {
        return selectedCodec !== "copy" && backend.preferGpu &&
               backend.hardwareEncoderAvailable(selectedCodec)
    }
    function togglePlayback() {
        if (!backend.hasVideo || backend.busy || textEntryHasFocus()) return
        if (isPlaying) {
            player.pause()
        } else {
            if (playSelection && (player.position < backend.clipStart * 1000 || player.position >= backend.clipEnd * 1000))
                player.position = backend.clipStart * 1000
            player.play()
        }
        appSurface.forceActiveFocus()
    }
    function textEntryHasFocus() {
        const item = activeFocusItem
        return item && (item instanceof TextInput || item instanceof TextEdit ||
                        item instanceof Controls.Control || item instanceof ActionButton)
    }
    function editorShortcutsAllowed() {
        return backend.hasVideo && !backend.busy && !root.showExport && !root.showSettings && !root.showDiagnostics &&
               !root.showOverwrite && !openDialog.visible && !folderDialog.visible && !textEntryHasFocus()
    }
    function chooseOutputDirectory(forExport) {
        folderDialogForExport = forExport
        folderDialog.currentFolder = backend.lastExportDirectoryUrl
        folderDialog.open()
    }
    function startExport(overwrite) {
        const target = targetSizeEnabled ? Number(targetSizeValue) : 0
        const ratio = selectedRatio
        if (targetSizeEnabled && (!Number.isFinite(target) || target <= 0)) {
            showNotice("Informe um tamanho-alvo válido em MB.", true)
            return
        }
        if (ratio === "Livre" && !customRatioValid) {
            showNotice("Use uma proporção válida, por exemplo 3:2.", true)
            return
        }
        if (!pendingOutput) {
            chooseOutputDirectory(true)
            return
        }
        backend.exportFile(pendingOutput, selectedCodec, ratio, customRatioValue,
                            selectedQuality, useGpuForSelectedCodec(), overwrite, target, includeAudio)
        showOverwrite = false
        showExport = false
    }
    function enqueueCurrentExport() {
        const target = targetSizeEnabled ? Number(targetSizeValue) : 0
        if (targetSizeEnabled && (!Number.isFinite(target) || target <= 0)) {
            showNotice("Informe um tamanho-alvo válido em MB.", true)
            return
        }
        if (selectedRatio === "Livre" && !customRatioValid) {
            showNotice("Use uma proporção válida, por exemplo 3:2.", true)
            return
        }
        if (!outputNameValid) {
            showNotice("Use um nome de arquivo válido, sem barras.", true)
            return
        }
        if (!outputDirectory) {
            folderDialogForQueue = true
            chooseOutputDirectory(false)
            return
        }
        pendingOutput = generatedOutputPath(outputDirectory)
        if (backend.enqueueExport(pendingOutput, selectedCodec, selectedRatio, customRatioValue,
                                 selectedQuality, useGpuForSelectedCodec(), target, includeAudio))
            showExport = false
    }
    function acceptOutputDirectory(directory, beginExport) {
        outputDirectory = directory
        pendingOutput = generatedOutputPath(directory)
        if (!beginExport) return
        if (!outputNameValid) {
            showNotice("Use um nome de arquivo válido, sem barras.", true)
            return
        }
        if (backend.outputIsSource(pendingOutput)) {
            showNotice("O vídeo original não pode ser o destino.", true)
            return
        }
        if (backend.outputExists(pendingOutput)) showOverwrite = true
        else startExport(false)
    }

    Timer { id: noticeTimer; interval: 5500; onTriggered: root.notice = "" }
    AudioOutput {
        id: audioOutput
        objectName: "clipcutAudioOutput"
        volume: inspector.volume
        muted: root.audioMuted
    }
    MediaPlayer {
        id: player
        objectName: "clipcutMediaPlayer"
        audioOutput: audioOutput
        videoOutput: videoOutput
        onPositionChanged: backend.setPlaybackPosition(position / 1000)
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && root.pendingAutoplay) {
                root.pendingAutoplay = false
                play()
            }
            if (mediaStatus === MediaPlayer.EndOfMedia && root.playSelection) {
                pause()
                position = backend.clipStart * 1000
            }
        }
        onErrorOccurred: function(error, errorString) {
            root.showNotice("Falha de reprodução: " + errorString, true)
        }
    }
    Timer {
        interval: 40
        repeat: true
        running: root.playSelection && root.isPlaying
        onTriggered: {
            if (backend.duration > 0 && player.position >= backend.clipEnd * 1000) {
                player.pause()
                player.position = backend.clipStart * 1000
            }
        }
    }
    Connections {
        target: backend
        function onFileChanged() {
            root.pendingAutoplay = !!backend.mediaUrl.toString()
            player.stop()
            player.source = backend.mediaUrl
            root.outputName = root.defaultOutputName()
            if (root.outputDirectory) {
                root.pendingOutput = root.generatedOutputPath(root.outputDirectory)
            }
        }
        function onExportDone(success, message) { root.showNotice(message, !success) }
    }

    FileDialog {
        id: openDialog
        objectName: "openFileDialog"
        title: "Abrir vídeo"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Vídeos (*.mp4 *.mkv *.mov *.webm *.avi *.m4v *.ts)", "Todos os arquivos (*)"]
        onAccepted: backend.openLocalUrl(selectedFile.toString())
    }
    FolderDialog {
        id: folderDialog
        objectName: "outputFolderDialog"
        title: "Escolher pasta de exportação"
        onAccepted: {
            const directory = backend.localPath(selectedFolder.toString())
            if (directory) {
                backend.rememberExportDirectory(directory)
                root.acceptOutputDirectory(directory, root.folderDialogForExport)
                if (root.folderDialogForQueue) {
                    root.folderDialogForQueue = false
                    root.enqueueCurrentExport()
                }
            }
            else {
                root.folderDialogForQueue = false
                root.showNotice("Escolha uma pasta local.", true)
            }
            root.folderDialogForExport = false
        }
        onRejected: {
            root.folderDialogForQueue = false
            root.folderDialogForExport = false
        }
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
            if (root.showOverwrite) root.showOverwrite = false
            else if (root.showExport) root.showExport = false
            else if (root.showDiagnostics) root.showDiagnostics = false
            else if (root.showSettings) root.showSettings = false
        }
    }
    Shortcut {
        sequence: "I"
        context: Qt.WindowShortcut
        enabled: root.editorShortcutsAllowed()
        onActivated: backend.markIn()
    }
    Shortcut {
        sequence: "O"
        context: Qt.WindowShortcut
        enabled: root.editorShortcutsAllowed()
        onActivated: backend.markOut()
    }
    Shortcut {
        sequence: "Left"
        context: Qt.WindowShortcut
        enabled: root.editorShortcutsAllowed()
        onActivated: root.seekTo(player.position / 1000 - (backend.fps > 0 ? 1 / backend.fps : 1 / 30))
    }
    Shortcut {
        sequence: "Right"
        context: Qt.WindowShortcut
        enabled: root.editorShortcutsAllowed()
        onActivated: root.seekTo(player.position / 1000 + (backend.fps > 0 ? 1 / backend.fps : 1 / 30))
    }
    Shortcut {
        sequence: "Ctrl+A"
        context: Qt.WindowShortcut
        enabled: root.editorShortcutsAllowed()
        onActivated: {
            backend.setRange(0, backend.duration)
            player.position = 0
        }
    }
    Rectangle {
        id: appSurface
        objectName: "appSurface"
        focus: true
        anchors.fill: parent
        anchors.margins: theme.outerMargin
        radius: theme.radiusExtraLarge
        color: theme.surface
        border.color: theme.outline
        border.width: 1
        Component.onCompleted: forceActiveFocus()
        Keys.onSpacePressed: function(event) {
            if (root.showExport || root.showSettings || root.showOverwrite ||
                    openDialog.visible || folderDialog.visible || root.textEntryHasFocus())
                return
            root.togglePlayback()
            event.accepted = true
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 0

            // Unified top rail: actions live in one softly connected surface.
            Row {
                id: toolbar
                width: parent.width
                height: theme.toolbarHeight
                spacing: 8

                VectorImage {
                    objectName: "clipcutBrandIcon"
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("assets/branding/clipcut-split-timeline-smooth.svg")
                    fillMode: VectorImage.PreserveAspectFit
                    preferredRendererType: VectorImage.CurveRenderer
                }
                Column {
                    id: projectColumn
                    width: Math.min(280, Math.max(150, parent.width * 0.24))
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "ClipCut"; color: theme.foreground; font.pixelSize: theme.textMd; font.weight: Font.DemiBold }
                    Text {
                        width: parent.width
                        text: backend.fileName || "Um corte, sem complicação"
                        color: theme.muted
                        font.pixelSize: theme.textXs
                        elide: Text.ElideMiddle
                    }
                }
                Item {
                    width: Math.max(0, parent.width - 48 - 38 - projectColumn.width - statusPill.width - openVideoButton.width - 128 - 108)
                    height: 1
                }
                Rectangle {
                    id: statusPill
                    width: root.notice || backend.filePath || backend.busy ? Math.min(200, Math.max(64, parent.width * 0.16)) : 0
                    height: 30
                    radius: theme.radiusFull
                    color: theme.surfaceLow
                    anchors.verticalCenter: parent.verticalCenter
                    Row {
                        anchors.centerIn: parent
                        spacing: 7
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: root.noticeError ? theme.danger : backend.busy ? theme.accent : theme.success
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.notice || backend.status
                            color: root.noticeError ? theme.danger : theme.muted
                            font.pixelSize: theme.textXs
                            elide: Text.ElideRight
                            width: Math.max(28, statusPill.width - 44)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                ActionButton {
                    id: openVideoButton
                    objectName: "openVideoButton"
                    tokens: root.tokens
                    text: "Abrir"
                    symbol: "+"
                    width: backend.filePath || backend.busy ? implicitWidth : 0
                    visible: width > 0
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: openDialog.open()
                }
                ActionButton {
                    tokens: root.tokens
                    text: "Preferências"
                    symbol: "⚙"
                    kind: "quiet"
                    compact: true
                    implicitWidth: 120
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: { root.showSettings = !root.showSettings; root.showExport = false }
                }
                ActionButton {
                    tokens: root.tokens
                    text: "Exportar"
                    symbol: "↗"
                    kind: "primary"
                    enabled: backend.hasVideo && !backend.busy
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: { root.showExport = true; root.showSettings = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: theme.outline; opacity: 0.72 }

            Row {
                id: workspace
                objectName: "editorWorkspace"
                width: parent.width
        height: Math.max(230, parent.height - toolbar.height - timelineDock.height - footer.height - 9)
                spacing: theme.space4

                // Navigation and inspector belong to the same editor surface.
                Rectangle {
                    id: toolRail
                    objectName: "toolRail"
                    width: 72
                    height: parent.height
                    color: "transparent"
                    Column {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 12
                        spacing: 8
                        Repeater {
                            model: [
                                { name: "Corte", glyph: "⌁" },
                                { name: "Enquadrar", glyph: "◱" },
                                { name: "Áudio", glyph: "♫" }
                            ]
                            delegate: ToolTab {
                                required property var modelData
                                tokens: root.tokens
                                title: modelData.name
                                symbol: modelData.glyph
                                selected: root.activeTool === modelData.name
                                enabled: modelData.name === "Corte" || backend.hasVideo
                                onClicked: {
                                    root.activeTool = modelData.name
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    objectName: "previewPanel"
                    width: Math.max(180, parent.width - toolRail.width - inspector.width - workspace.spacing * 2)
                    height: parent.height - 16
                    anchors.verticalCenter: parent.verticalCenter
                    radius: theme.radiusLarge
                    color: theme.preview
                    clip: true

                    VideoOutput {
                        id: videoOutput
                        objectName: "clipcutVideoOutput"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: transport.top
                        fillMode: VideoOutput.PreserveAspectFit
                    }
                    Image {
                        anchors.fill: videoOutput
                        source: backend.previewUrl
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        visible: status === Image.Ready &&
                                 (player.error !== MediaPlayer.NoError || player.mediaStatus === MediaPlayer.NoMedia)
                    }

                        Column {
                            anchors.centerIn: videoOutput
                            spacing: 8
                            visible: !backend.filePath
                            VectorImage {
                                width: 44; height: 44
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: Qt.resolvedUrl("assets/branding/clipcut-split-timeline-smooth.svg")
                                fillMode: VectorImage.PreserveAspectFit
                                preferredRendererType: VectorImage.CurveRenderer
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Seu próximo corte começa aqui"; color: theme.foreground; font.pixelSize: theme.textLg; font.weight: Font.DemiBold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Abra um vídeo ou solte-o nesta janela"; color: theme.muted; font.pixelSize: theme.textSm }
                            ActionButton { anchors.horizontalCenter: parent.horizontalCenter; tokens: root.tokens; text: "Abrir vídeo"; symbol: "+"; kind: "tonal"; onClicked: openDialog.open() }
                    }

                    Rectangle {
                        anchors.centerIn: videoOutput
                        visible: player.mediaStatus === MediaPlayer.LoadingMedia
                        width: loadingLabel.implicitWidth + 32
                        height: 38
                        radius: theme.radiusFull
                        color: "#dc191a20"
                        Text { id: loadingLabel; anchors.centerIn: parent; text: "Lendo seu vídeo…"; color: theme.foreground; font.pixelSize: theme.textSm }
                    }

                    // Four quiet masks leave the actual crop boundary unobscured.
                    Rectangle {
                        visible: root.showCropOverlay && backend.cropRect.width < 0.999
                        x: videoOutput.contentRect.x; y: videoOutput.contentRect.y
                        width: videoOutput.contentRect.width * backend.cropRect.x; height: videoOutput.contentRect.height
                        color: "#b5000000"
                    }
                    Rectangle {
                        visible: root.showCropOverlay && backend.cropRect.width < 0.999
                        x: videoOutput.contentRect.x + videoOutput.contentRect.width * (backend.cropRect.x + backend.cropRect.width)
                        y: videoOutput.contentRect.y
                        width: videoOutput.contentRect.width * (1 - backend.cropRect.x - backend.cropRect.width)
                        height: videoOutput.contentRect.height
                        color: "#b5000000"
                    }
                    Rectangle {
                        visible: root.showCropOverlay && backend.cropRect.height < 0.999
                        x: videoOutput.contentRect.x + videoOutput.contentRect.width * backend.cropRect.x
                        y: videoOutput.contentRect.y
                        width: videoOutput.contentRect.width * backend.cropRect.width
                        height: videoOutput.contentRect.height * backend.cropRect.y
                        color: "#b5000000"
                    }
                    Rectangle {
                        visible: root.showCropOverlay && backend.cropRect.height < 0.999
                        x: videoOutput.contentRect.x + videoOutput.contentRect.width * backend.cropRect.x
                        y: videoOutput.contentRect.y + videoOutput.contentRect.height * (backend.cropRect.y + backend.cropRect.height)
                        width: videoOutput.contentRect.width * backend.cropRect.width
                        height: videoOutput.contentRect.height * (1 - backend.cropRect.y - backend.cropRect.height)
                        color: "#b5000000"
                    }
                    Rectangle {
                        objectName: "cropFrame"
                        visible: root.showCropOverlay && backend.cropActive
                        x: videoOutput.contentRect.x + videoOutput.contentRect.width * backend.cropRect.x
                        y: videoOutput.contentRect.y + videoOutput.contentRect.height * backend.cropRect.y
                        width: videoOutput.contentRect.width * backend.cropRect.width
                        height: videoOutput.contentRect.height * backend.cropRect.height
                        color: "transparent"
                        border.color: theme.accent
                        border.width: 2
                        radius: 4
                        MouseArea {
                            objectName: "cropDragArea"
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            onPressed: function(mouse) {
                                const point = mapToItem(videoOutput, mouse.x, mouse.y)
                                root.cropPressX = point.x; root.cropPressY = point.y
                                root.cropCenterX = backend.cropRect.x + backend.cropRect.width / 2
                                root.cropCenterY = backend.cropRect.y + backend.cropRect.height / 2
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed || videoOutput.contentRect.width <= 0 || videoOutput.contentRect.height <= 0) return
                                const point = mapToItem(videoOutput, mouse.x, mouse.y)
                                backend.moveCrop(root.cropCenterX + (point.x - root.cropPressX) / videoOutput.contentRect.width,
                                                 root.cropCenterY + (point.y - root.cropPressY) / videoOutput.contentRect.height)
                            }
                        }
                    }

                    // The framing keeps applying to the export even when another
                    // tab is active, so make it visible instead of invisible.
                    Rectangle {
                        visible: backend.hasVideo && backend.cropActive &&
                                 root.activeTool !== "Enquadrar" &&
                                 videoOutput.sourceRect.width > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        width: badgeLabel.implicitWidth + 20
                        height: 26
                        radius: theme.radiusFull
                        color: theme.surfaceHigh
                        border.color: theme.accent
                        border.width: 1
                        Text {
                            id: badgeLabel
                            anchors.centerIn: parent
                            text: "Recorte " + root.selectedRatio + " aplicado"
                            color: theme.foreground
                            font.pixelSize: theme.textXs
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: root.dragHover
                        color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.08)
                        border.color: theme.accent
                        border.width: 2
                        radius: theme.radiusLarge
                        z: 12
                        Text {
                            anchors.centerIn: parent
                            text: "Solte o vídeo para abrir"
                            color: theme.foreground
                            font.pixelSize: theme.textMd
                            font.weight: Font.DemiBold
                        }
                    }

                    // Playback controls float over the image and morph with press/hover.
                    Rectangle {
                        id: transport
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        width: Math.min(parent.width - 24, 520)
                        height: 48
                        radius: theme.radiusFull
                        color: "#e21b1d24"
                        border.color: "#30ffffff"
                        opacity: backend.hasVideo ? 1 : 0.72
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 6
                            ActionButton {
                                tokens: root.tokens; text: "− quadro"; compact: true; kind: "quiet"
                                anchors.verticalCenter: parent.verticalCenter
                                enabled: backend.hasVideo
                                onClicked: root.seekTo(player.position / 1000 - (backend.fps > 0 ? 1 / backend.fps : 1 / 30))
                            }
                            ActionButton {
                                tokens: root.tokens
                                text: root.isPlaying ? "Pausar" : "Reproduzir"
                                symbol: root.isPlaying ? "Ⅱ" : "▶"
                                kind: "tonal"
                                anchors.verticalCenter: parent.verticalCenter
                                enabled: backend.hasVideo
                                onClicked: {
                                    if (root.isPlaying) player.pause()
                                    else {
                                        if (root.playSelection && (player.position < backend.clipStart * 1000 || player.position >= backend.clipEnd * 1000))
                                            player.position = backend.clipStart * 1000
                                        player.play()
                                    }
                                }
                            }
                            ActionButton {
                                tokens: root.tokens; text: "+ quadro"; compact: true; kind: "quiet"
                                anchors.verticalCenter: parent.verticalCenter
                                enabled: backend.hasVideo
                                onClicked: root.seekTo(player.position / 1000 + (backend.fps > 0 ? 1 / backend.fps : 1 / 30))
                            }
                            Item { width: Math.max(0, parent.width - 500); height: 1 }
                            Text {
                                text: root.formatTime(player.position / 1000) + " / " + root.formatTime(backend.duration)
                                color: theme.foreground
                                font.pixelSize: theme.textSm
                                 font.family: "monospace"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                ToolInspector {
                    id: inspector
                    objectName: "inspectorPanel"
                    height: parent.height
                    tokens: root.tokens
                    clipBackend: root.clipBackend
                    selectedTool: root.activeTool
                    selectedRatio: root.selectedRatio
                    customRatioValue: root.customRatioValue
                    customRatioValid: root.customRatioValid
                    selectedCodec: root.selectedCodec
                    includeAudio: root.includeAudio
                    audioMuted: root.audioMuted
                }
                Connections {
                    target: inspector
                    function onRatioRequested(ratio) { root.applyRatio(ratio) }
                    function onCustomRatioRequested(ratio) { root.applyCustomRatio(ratio) }
                    function onCenterCropRequested() { backend.centerCrop() }
                    function onIncludeAudioToggled(value) { root.includeAudio = value }
                    function onAudioMuteToggled(value) { root.audioMuted = value }
                }
            }

            Item { width: parent.width; height: theme.space4 }

            ClipTimeline {
                id: timelineDock
                objectName: "timelinePanel"
                width: parent.width
                height: theme.timelineHeight
                tokens: root.tokens
                clipBackend: root.clipBackend
                mediaPlayer: root.mediaPlayer
                playSelection: root.playSelection
                onPlaySelectionToggled: value => root.playSelection = value
            }

            Row {
                id: footer
                width: parent.width
                height: backend.exporting ? 25 : 0
                spacing: 8
                Item { width: Math.max(0, parent.width - 140); height: 1 }
                ProgressRail {
                    tokens: root.tokens
                    visible: backend.exporting && backend.progress > 0
                    value: backend.progress / 100
                    width: 110
                    anchors.verticalCenter: parent.verticalCenter
                }
                ActionButton {
                    visible: backend.exporting
                    tokens: root.tokens
                    text: "Cancelar"
                    kind: "danger"
                    compact: true
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: backend.cancelExport()
                }
            }
        }
    }

    // The export sheet grows from the toolbar edge; scrim is intentionally restrained.
    Rectangle {
        anchors.fill: parent
        z: 20
        visible: root.showExport || root.showSettings || root.showDiagnostics || root.showOverwrite
        opacity: visible ? 1 : 0
        color: root.showExport || root.showOverwrite ? "#55090a0f" : "transparent"
        Behavior on opacity { NumberAnimation { duration: theme.effectDefault; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: { root.showExport = false; root.showSettings = false; root.showDiagnostics = false; if (!root.showOverwrite) root.showOverwrite = false } }
    }

    ExportPopover {
        objectName: "exportPopover"
        tokens: root.tokens
        clipBackend: root.clipBackend
        windowWidth: root.width
        windowHeight: root.height
        open: root.showExport
        selectedCodec: root.selectedCodec
        selectedQuality: root.selectedQuality
        selectedRatio: root.selectedRatio
        customRatioValue: root.customRatioValue
        customRatioValid: root.customRatioValid
        includeAudio: root.includeAudio
        targetSizeEnabled: root.targetSizeEnabled
        targetSizeValue: root.targetSizeValue
        outputDirectory: root.outputDirectory
        outputName: root.outputName
        outputNameValid: root.outputNameValid
        outputFormat: root.outputFormat
        onCodecChanged: codec => root.selectedCodec = codec
        onEncoderPreferenceChanged: useGpu => backend.setPreferGpu(useGpu)
        onQualityChanged: quality => root.selectedQuality = quality
        onRatioChanged: ratio => root.applyRatio(ratio)
        onCustomRatioChanged: ratio => root.applyCustomRatio(ratio)
        onAudioInclusionRequested: enabled => root.includeAudio = enabled
        onTargetEnabledRequested: enabled => root.targetSizeEnabled = enabled
        onTargetValueEdited: value => root.targetSizeValue = value
        onOutputNameRequested: name => root.updateOutputName(name)
        onOutputFormatRequested: format => {
            root.outputFormat = format
            if (root.outputDirectory) root.pendingOutput = root.generatedOutputPath(root.outputDirectory)
        }
        onBrowseRequested: root.chooseOutputDirectory(false)
        onQueueRequested: root.enqueueCurrentExport()
        onStartQueueRequested: {
            root.showExport = false
            backend.startExportQueue()
        }
        onRemoveQueueRequested: jobId => backend.removeQueuedExport(jobId)
        onClearQueueRequested: backend.clearExportQueue()
        onExportRequested: {
            if (!root.outputDirectory) root.chooseOutputDirectory(true)
            else root.acceptOutputDirectory(root.outputDirectory, true)
        }
        onCloseRequested: root.showExport = false
    }

    Rectangle {
        objectName: "settingsPopover"
        z: 22
        visible: root.showSettings || opacity > 0.01
        enabled: root.showSettings
        width: Math.min(340, root.width - 32)
        height: Math.min(360, root.height - 36)
        x: root.showSettings ? root.width - width - 18 : root.width + 8
        y: 18
        radius: theme.radiusExtraLarge
        color: theme.panel
        border.color: theme.outline
        opacity: root.showSettings ? 1 : 0
        scale: root.showSettings ? 1 : 0.96
        transformOrigin: Item.TopRight
        Behavior on x { NumberAnimation { duration: theme.spatialFast; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: theme.effectDefault } }
        Behavior on scale { NumberAnimation { duration: theme.spatialFast; easing.type: Easing.OutCubic } }
        Column {
            anchors.fill: parent; anchors.margins: 18; spacing: 10
            Row {
                width: parent.width; height: 38
                Text { text: "Preferências"; color: theme.foreground; font.pixelSize: theme.textXl; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                Item { width: Math.max(0, parent.width - 150); height: 1 }
                ActionButton { tokens: root.tokens; text: "×"; kind: "quiet"; compact: true; onClicked: root.showSettings = false }
            }
            Rectangle { width: parent.width; height: 1; color: theme.outline }
            Text { text: "APARÊNCIA"; color: theme.muted; font.pixelSize: theme.textXs; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Row {
                spacing: 7
                ActionButton { tokens: root.tokens; text: "ClipCut"; checked: root.themeMode === "ClipCut"; onClicked: root.themeMode = "ClipCut" }
                ActionButton { tokens: root.tokens; text: "Seguir o KDE"; checked: root.themeMode === "KDE"; onClicked: root.themeMode = "KDE" }
            }
            Text { width: parent.width; text: root.themeMode === "KDE" ? "Usa as cores do esquema ativo do KDE." : "Grafite escuro e lavanda suave."; color: theme.muted; font.pixelSize: theme.textXs; wrapMode: Text.WordWrap }
            Rectangle { width: parent.width; height: 1; color: theme.outline }
            Row {
                width: parent.width; height: 42; spacing: 10
                Rectangle { width: 38; height: 24; radius: theme.radiusFull; color: root.reducedMotion ? theme.accentSoft : theme.surfaceHigh; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { x: root.reducedMotion ? 18 : 3; y: 3; width: 18; height: 18; radius: 9; color: root.reducedMotion ? theme.accent : theme.muted; Behavior on x { NumberAnimation { duration: theme.effectFast } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.reducedMotion = !root.reducedMotion }
                }
                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: "Reduzir movimento"; color: theme.foreground; font.pixelSize: theme.textSm }
                    Text { text: "Animações mais discretas"; color: theme.muted; font.pixelSize: theme.textXs }
                }
            }
            Row {
                width: parent.width; height: 42; spacing: 10
                Rectangle {
                    width: 38; height: 24; radius: theme.radiusFull
                    color: backend.preferGpu && backend.gpuAvailable ? theme.accentSoft : theme.surfaceHigh
                    opacity: backend.gpuAvailable ? 1 : 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        x: backend.preferGpu ? 18 : 3; y: 3; width: 18; height: 18; radius: 9
                        color: backend.preferGpu ? theme.accent : theme.muted
                        Behavior on x { NumberAnimation { duration: theme.effectFast } }
                    }
                    MouseArea {
                        anchors.fill: parent; enabled: backend.gpuAvailable
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: backend.setPreferGpu(!backend.preferGpu)
                    }
                }
                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Text { text: "Usar aceleração de GPU quando compatível"; color: theme.foreground; font.pixelSize: theme.textSm }
                    Text { text: backend.gpuName; color: theme.muted; font.pixelSize: theme.textXs; elide: Text.ElideRight; width: 250 }
                }
            }
            ActionButton {
                tokens: root.tokens
                text: "Diagnóstico de exportação"
                compact: true
                onClicked: {
                    root.diagnosticsText = backend.diagnosticReport()
                    root.showSettings = false
                    root.showDiagnostics = true
                }
            }
        }
    }

    Rectangle {
        objectName: "diagnosticsPopover"
        z: 26
        visible: root.showDiagnostics
        width: Math.min(560, root.width - 40)
        height: Math.min(440, root.height - 40)
        anchors.centerIn: parent
        radius: theme.radiusExtraLarge
        color: theme.panel
        border.color: theme.outline
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12
            Row {
                width: parent.width
                Text { text: "Diagnóstico de exportação"; color: theme.foreground; font.pixelSize: theme.textXl; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                Item { width: Math.max(0, parent.width - 300); height: 1 }
                ActionButton { tokens: root.tokens; text: "×"; compact: true; kind: "quiet"; onClicked: root.showDiagnostics = false }
            }
            Text {
                width: parent.width
                text: "O relatório mostra versões e encoders detectados; não inclui caminhos dos vídeos. Confira o modelo da GPU antes de compartilhar."
                color: theme.muted
                font.pixelSize: theme.textXs
                wrapMode: Text.WordWrap
            }
            Controls.ScrollView {
                width: parent.width
                height: Math.max(120, parent.height - 118)
                clip: true
                Controls.TextArea {
                    text: root.diagnosticsText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: theme.foreground
                    font.family: "monospace"
                    background: Rectangle { color: theme.surface; radius: theme.radiusMedium }
                }
            }
            ActionButton {
                tokens: root.tokens
                text: "Copiar diagnóstico"
                kind: "primary"
                onClicked: backend.copyDiagnosticReport()
            }
        }
    }

    Rectangle {
        z: 30
        visible: root.showOverwrite
        width: Math.min(430, root.width - 40)
        height: 220
        anchors.centerIn: parent
        radius: theme.radiusExtraLarge
        color: theme.panel
        border.color: theme.outline
        scale: root.showOverwrite ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: theme.spatialFast; easing.type: Easing.OutCubic } }
        Column {
            anchors.fill: parent; anchors.margins: 24; spacing: 12
            Text { text: "Substituir este arquivo?"; color: theme.foreground; font.pixelSize: theme.textXl; font.weight: Font.DemiBold }
            Text { width: parent.width; text: "A versão atual só será trocada quando a nova exportação terminar e passar na validação."; color: theme.muted; font.pixelSize: theme.textSm; wrapMode: Text.WordWrap }
            Text { width: parent.width; text: root.pendingOutput; color: theme.accent; font.pixelSize: theme.textXs; elide: Text.ElideMiddle }
            Item { width: 1; height: 1 }
            Row {
                anchors.right: parent.right; spacing: 8
                ActionButton { tokens: root.tokens; text: "Cancelar"; kind: "quiet"; onClicked: root.showOverwrite = false }
                ActionButton { tokens: root.tokens; text: "Substituir"; kind: "primary"; onClicked: root.startExport(true) }
            }
        }
    }

    Rectangle {
        z: 40
        visible: root.notice.length > 0
        opacity: visible ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: Math.min(parent.width - 40, toastLabel.implicitWidth + 52)
        height: 42
        radius: theme.radiusFull
        color: root.noticeError ? "#603837" : theme.surfaceHighest
        border.color: root.noticeError ? theme.danger : theme.outline
        Text { id: toastLabel; anchors.centerIn: parent; text: root.notice; color: root.noticeError ? theme.danger : theme.foreground; font.pixelSize: theme.textSm; elide: Text.ElideRight; width: parent.width - 28 }
        Behavior on opacity { NumberAnimation { duration: theme.effectDefault } }
    }

    MultiEffect {
        anchors.fill: appSurface
        z: 80
        source: appSurface
        visible: backend.exporting
        blurEnabled: true
        blur: backend.exporting ? 0.72 : 0
        blurMax: 48
    }

    Rectangle {
        objectName: "renderProgressOverlay"
        anchors.fill: parent
        z: 81
        visible: backend.exporting
        color: "#98090a0f"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: theme.effectDefault; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        Rectangle {
            objectName: "renderProgressCard"
            width: Math.min(460, parent.width - 36)
            height: 216
            anchors.centerIn: parent
            radius: theme.radiusExtraLarge
            color: theme.panel
            border.color: theme.outline
            border.width: 1
            opacity: backend.exporting ? 1 : 0
            scale: backend.exporting ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: theme.effectDefault; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: theme.spatialFast; easing.type: Easing.OutCubic } }

            Column {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 16
                Row {
                    width: parent.width
                    spacing: 14
                    Rectangle {
                        width: 42; height: 42
                        radius: theme.radiusMedium
                        color: theme.accentSoft
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "↗"
                            color: theme.accent
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }
                    }
                    Column {
                        width: parent.width - 58
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Text {
                            text: "Renderizando vídeo"
                            color: theme.foreground
                            font.pixelSize: theme.textXl
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: backend.status
                            color: theme.muted
                            font.pixelSize: theme.textSm
                            elide: Text.ElideRight
                        }
                    }
                }

                ProgressRail {
                    width: parent.width
                    height: 6
                    tokens: root.tokens
                    value: backend.progress / 100
                    fillColor: theme.accent
                }

                Row {
                    width: parent.width
                    height: 36
                    spacing: 12
                    Text {
                        width: Math.max(0, parent.width - renderCancelButton.implicitWidth - parent.spacing)
                        text: backend.progress > 0 ? backend.progress + "%" : "Preparando…"
                        color: theme.foreground
                        font.pixelSize: theme.textSm
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ActionButton {
                        id: renderCancelButton
                        objectName: "renderCancelButton"
                        tokens: root.tokens
                        text: "Cancelar"
                        kind: "danger"
                        compact: true
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: backend.cancelExport()
                    }
                }
            }
        }
    }

    DropArea {
        objectName: "videoDropArea"
        anchors.fill: parent
        z: 50
        onDropped: function(drop) {
            root.dragHover = false
            if (!drop.hasUrls || !drop.urls.length)
                return
            const url = drop.urls[0].toString()
            if (url.startsWith("file:")) {
                drop.acceptProposedAction()
                backend.openLocalUrl(url)
            }
        }
        onEntered: root.dragHover = true
        onExited: root.dragHover = false
    }
}
