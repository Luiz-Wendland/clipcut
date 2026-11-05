import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Shapes

Rectangle {
    id: root
    property var tokens
    property var clipBackend
    property var mediaPlayer
    property bool playSelection: true
    property real duration: clipBackend.duration
    property bool dragging: false
    property bool resumePlayback: false
    property real clipStartOnPress: 0
    property real clipEndOnPress: 0
    property real viewZoom: 1
    property real viewStart: 0
    readonly property real maxZoom: 4
    readonly property int visibleThumbnailCount: thumbnailRepeater.count
    readonly property string firstThumbnailState: thumbnailRepeater.count > 0 && thumbnailRepeater.itemAt(0)
                                                  ? thumbnailRepeater.itemAt(0).loadState : "empty"
    signal playSelectionToggled(bool value)

    color: root.tokens.surfaceLow
    radius: root.tokens.radiusLarge
    border.width: 1
    border.color: root.tokens.outline

    function timecode(seconds) {
        seconds = Math.max(0, Number(seconds) || 0)
        const m = Math.floor(seconds / 60)
        return String(m).padStart(2, "0") + ":" + (seconds % 60).toFixed(2).padStart(5, "0")
    }
    function parseTime(value) {
        const text = String(value).trim()
        if (!text) return NaN
        const parts = text.split(":")
        if (parts.length === 1) return Number(parts[0])
        if (parts.some(part => part.trim() === "" || !Number.isFinite(Number(part)))) return NaN
        if (parts.length === 2) {
            const minutes = Number(parts[0]), seconds = Number(parts[1])
            return minutes >= 0 && seconds >= 0 && seconds < 60 ? minutes * 60 + seconds : NaN
        }
        if (parts.length === 3) {
            const hours = Number(parts[0]), minutes = Number(parts[1]), seconds = Number(parts[2])
            return hours >= 0 && minutes >= 0 && minutes < 60 && seconds >= 0 && seconds < 60
                    ? hours * 3600 + minutes * 60 + seconds : NaN
        }
        return NaN
    }
    function seek(x) {
        if (duration <= 0 || track.width <= 0) return
        mediaPlayer.position = Math.max(0, Math.min(mediaPlayer.duration,
            (viewStart + x / track.width * visibleDuration()) * 1000))
    }
    function visibleDuration() {
        return duration > 0 ? duration / viewZoom : 0
    }
    function clampViewStart(value) {
        return Math.max(0, Math.min(Math.max(0, duration - visibleDuration()), value))
    }
    function zoomAt(x, factor) {
        if (duration <= 0 || track.width <= 0) return
        const anchor = Math.max(0, Math.min(1, x / track.width))
        const anchorTime = viewStart + anchor * visibleDuration()
        viewZoom = Math.max(1, Math.min(maxZoom, viewZoom * factor))
        viewStart = clampViewStart(anchorTime - anchor * visibleDuration())
    }
    function panByFraction(fraction) {
        viewStart = clampViewStart(viewStart + visibleDuration() * fraction)
    }
    function thumbnailSampleCount() {
        return Math.min(clipBackend.timelineThumbnails.length,
                        Math.max(1, Math.round(12 * viewZoom)))
    }
    function visibleThumbnails() {
        const frames = clipBackend.timelineThumbnails
        const count = thumbnailSampleCount()
        if (!count) return []
        const interval = frames.length / count
        return Array.from({ length: count }, (_, index) => frames[Math.floor(index * interval)])
    }
    function thumbnailLoadError() {
        for (let i = 0; i < thumbnailRepeater.count; ++i) {
            const image = thumbnailRepeater.itemAt(i)
            if (image && image.loadState === "error") return true
        }
        return false
    }
    function thumbnailsStillLoading() {
        for (let i = 0; i < thumbnailRepeater.count; ++i) {
            const image = thumbnailRepeater.itemAt(i)
            if (image && image.loadState !== "ready" && image.loadState !== "error") return true
        }
        return false
    }
    function beginDrag() {
        resumePlayback = mediaPlayer.playbackState === 1
        if (resumePlayback) mediaPlayer.pause()
        dragging = true
    }
    function finishDrag() {
        dragging = false
        if (resumePlayback) {
            resumePlayback = false
            mediaPlayer.play()
        }
    }

    Connections {
        target: root.clipBackend
        function onRangeChanged() {
            if (!inTimeField.activeFocus) inTimeField.text = root.timecode(root.clipBackend.clipStart)
            if (!outTimeField.activeFocus) outTimeField.text = root.timecode(root.clipBackend.clipEnd)
        }
    }

    onDurationChanged: {
        viewZoom = 1
        viewStart = 0
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0

        RowLayout {
            width: parent.width
            height: 32
            spacing: root.tokens.space4
            Row {
                spacing: root.tokens.space2
                Text {
                    text: "IN"; color: root.tokens.muted; font.pixelSize: root.tokens.textSm
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        Controls.ToolTip.text: "Marcar entrada no quadro atual · I"
                        Controls.ToolTip.visible: containsMouse
                        Controls.ToolTip.delay: 600
                    }
                }
                LineEdit {
                    id: inTimeField
                    objectName: "timelineInField"
                    width: 92; height: 28; tokens: root.tokens
                     fontFamily: "monospace"
                    text: root.timecode(root.clipBackend.clipStart)
                    onEditingFinished: {
                        const seconds = root.parseTime(text)
                        if (Number.isFinite(seconds)) root.clipBackend.setRange(seconds, root.clipBackend.clipEnd)
                        text = root.timecode(root.clipBackend.clipStart)
                    }
                }
            }
            Row {
                spacing: root.tokens.space2
                Text {
                    text: "OUT"; color: root.tokens.muted; font.pixelSize: root.tokens.textSm
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        Controls.ToolTip.text: "Marcar saída no quadro atual · O"
                        Controls.ToolTip.visible: containsMouse
                        Controls.ToolTip.delay: 600
                    }
                }
                LineEdit {
                    id: outTimeField
                    objectName: "timelineOutField"
                    width: 92; height: 28; tokens: root.tokens
                     fontFamily: "monospace"
                    text: root.timecode(root.clipBackend.clipEnd)
                    onEditingFinished: {
                        const seconds = root.parseTime(text)
                        if (Number.isFinite(seconds)) root.clipBackend.setRange(root.clipBackend.clipStart, seconds)
                        text = root.timecode(root.clipBackend.clipEnd)
                    }
                }
            }
            Item { Layout.fillWidth: true; height: 1 }
            Column {
                spacing: 0
                Text { text: "Duração"; color: root.tokens.muted; font.pixelSize: root.tokens.textSm }
                Text {
                    text: root.timecode(root.clipBackend.clipEnd - root.clipBackend.clipStart)
                    color: root.tokens.accent
                    font.pixelSize: 14
                    font.weight: Font.Medium
                     font.family: "monospace"
                }
            }
            Row {
                spacing: 3
                Layout.leftMargin: 8
                ActionButton {
                    tokens: root.tokens; text: "−"; compact: true; enabled: root.viewZoom > 1
                    Controls.ToolTip.text: "Diminuir zoom"
                    onClicked: root.zoomAt(track.width / 2, 0.8)
                }
                ActionButton {
                    tokens: root.tokens; text: root.viewZoom.toFixed(1) + "×"; compact: true
                    Controls.ToolTip.text: "Ajustar à duração completa"
                    onClicked: { root.viewZoom = 1; root.viewStart = 0 }
                }
                ActionButton {
                    objectName: "timelineZoomIn"
                    tokens: root.tokens; text: "+"; compact: true; enabled: root.viewZoom < root.maxZoom
                    Controls.ToolTip.text: "Aumentar zoom (máximo 4×)"
                    onClicked: root.zoomAt(track.width / 2, 1.25)
                }
            }
            Row {
                spacing: 8
                Layout.leftMargin: 8
                Rectangle {
                    width: 34; height: 20; radius: 10
                    color: root.playSelection ? root.tokens.accentSoft : root.tokens.surfaceHigh
                    opacity: root.clipBackend.hasVideo ? 1 : 0.5
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        x: root.playSelection ? 16 : 2; y: 2; width: 16; height: 16; radius: 8
                        color: root.playSelection ? root.tokens.accent : root.tokens.muted
                        Behavior on x { NumberAnimation { duration: root.tokens.effectFast } }
                    }
                    MouseArea { anchors.fill: parent; enabled: root.clipBackend.hasVideo; cursorShape: Qt.PointingHandCursor; onClicked: root.playSelectionToggled(!root.playSelection) }
                }
                Text {
                    text: "Reproduzir só o trecho"
                    color: root.clipBackend.hasVideo ? root.tokens.foreground : root.tokens.muted
                    font.pixelSize: root.tokens.textSm
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; enabled: root.clipBackend.hasVideo; onClicked: root.playSelectionToggled(!root.playSelection) }
                }
            }
        }

        Item { width: 1; height: 10 }

        Rectangle {
            id: track
            objectName: "timelineTrackBackground"
            width: parent.width
            height: Math.max(60, parent.height - 42)
            radius: 13
            color: root.tokens.surfaceLow
            border.width: 1
            border.color: root.tokens.outline
            antialiasing: true
            clip: false

            Item {
                objectName: "timelineVisualLayer"
                anchors.fill: parent
                clip: true

            Repeater {
                id: thumbnailRepeater
                objectName: "timelineThumbnailRepeater"
                model: root.visibleThumbnails()
                delegate: Image {
                    required property var modelData
                    readonly property string loadState: status === Image.Ready ? "ready"
                                                      : status === Image.Error ? "error"
                                                      : status === Image.Loading ? "loading" : "null"
                    property real sampleSpan: root.duration / Math.max(1, root.visibleThumbnailCount)
                    property real timelineWidth: track.width * root.viewZoom
                    width: timelineWidth * sampleSpan / Math.max(root.duration, 0.001)
                    height: Math.min(track.height * 0.68, width * 9 / 16)
                    x: (modelData.time - sampleSpan / 2 - root.viewStart) /
                       Math.max(root.duration, 0.001) * timelineWidth
                    y: (track.height * 0.68 - height) / 2
                    source: modelData.url
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready && x + width > 0 && x < track.width
                    opacity: root.tokens.mode === "ClipCut" ? 0.86 : 0.78
                }
            }
            Text {
                x: 12
                y: 30
                width: Math.max(0, track.width - 24)
                z: 3
                horizontalAlignment: Text.AlignHCenter
                text: root.clipBackend.timelineImageStatus === "error"
                      ? "Miniaturas indisponíveis"
                      : root.thumbnailLoadError()
                        ? "Falha ao carregar miniaturas"
                      : root.clipBackend.timelineImageStatus === "ready"
                        ? "Carregando miniaturas…" : "Gerando miniaturas…"
                color: root.tokens.muted
                font.pixelSize: root.tokens.textXs
                visible: root.clipBackend.hasVideo &&
                         (root.clipBackend.timelineImageStatus !== "ready" ||
                          thumbnailRepeater.count === 0 || root.thumbnailLoadError() ||
                          root.thumbnailsStillLoading())
            }
            Rectangle {
                id: waveformSurface
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: track.height * 0.32
                color: root.tokens.surface
                opacity: 0.82
                visible: root.clipBackend.hasVideo
            }
            Image {
                id: waveformImage
                objectName: "timelineWaveformImage"
                readonly property string loadState: status === Image.Ready ? "ready"
                                                  : status === Image.Error ? "error"
                                                  : status === Image.Loading ? "loading" : "null"
                x: -root.viewStart / Math.max(root.duration, 0.001) * waveformSurface.width * root.viewZoom
                y: waveformSurface.y
                width: waveformSurface.width * root.viewZoom
                height: waveformSurface.height
                source: root.clipBackend.waveformUrl
                fillMode: Image.Stretch
                asynchronous: true
                cache: false
                visible: status === Image.Ready && root.clipBackend.hasAudio
                opacity: 0.92
            }
            Text {
                anchors.fill: waveformSurface
                z: 3
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: !root.clipBackend.hasAudio
                      ? "Sem faixa de áudio neste vídeo"
                      : root.clipBackend.waveformStatus === "error"
                      ? "Waveform indisponível"
                      : waveformImage.loadState === "error"
                        ? "Falha ao carregar waveform"
                      : root.clipBackend.waveformStatus === "ready"
                        ? "Carregando waveform…" : "Gerando waveform…"
                color: root.tokens.muted
                font.pixelSize: root.tokens.textXs
                visible: root.clipBackend.hasVideo &&
                         (!root.clipBackend.hasAudio || waveformImage.loadState !== "ready")
            }
            Rectangle {
                anchors.fill: parent
                color: root.tokens.canvas
                opacity: root.clipBackend.timelineThumbnails.length > 0 ? 0.22 : 0.74
            }

            Repeater {
                model: 9
                delegate: Item {
                    required property int index
                    width: 68
                    height: 19
                    x: Math.max(12, Math.min(track.width - width - 12, track.width * index / 8 - width / 2))
                    y: 5
                    visible: root.duration > 0
                    z: 3
                    Rectangle { anchors.fill: parent; radius: 5; color: "#c90a0b10"; border.color: "#33ffffff"; border.width: 1 }
                    Text {
                        anchors.centerIn: parent
                        text: root.timecode(root.viewStart + root.visibleDuration() * parent.index / 8)
                        color: "#FFFFFF"
                        font.pixelSize: 11
                         font.family: "monospace"
                    }
                    Rectangle {
                        x: parent.width / 2; y: parent.height + 1; width: 1; height: 5
                        color: "#D0BCFF"; opacity: 0.8
                    }
                }
            }

            Rectangle {
                id: range
                property real leftEdge: root.duration > 0
                                        ? (root.clipBackend.clipStart - root.viewStart) / root.visibleDuration() * track.width : 0
                property real rightEdge: root.duration > 0
                                         ? (root.clipBackend.clipEnd - root.viewStart) / root.visibleDuration() * track.width : track.width
                x: Math.max(0, Math.min(track.width, leftEdge))
                width: Math.max(0, Math.min(track.width, rightEdge) - Math.max(0, leftEdge))
                height: parent.height
                visible: root.clipBackend.hasVideo && rightEdge > 0 && leftEdge < track.width
                color: Qt.rgba(root.tokens.accent.r, root.tokens.accent.g, root.tokens.accent.b, 0.18)
                border.color: root.tokens.accent
                border.width: 2
                z: 2
                Behavior on x { NumberAnimation { duration: root.dragging ? 0 : root.tokens.effectFast; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: root.dragging ? 0 : root.tokens.effectFast; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                x: 0; y: 0
                width: Math.max(0, Math.min(track.width, range.leftEdge))
                height: parent.height
                color: "#ae090a0f"
                visible: root.clipBackend.hasVideo
                z: 1
            }
            Rectangle {
                x: Math.max(0, Math.min(track.width, range.rightEdge)); y: 0
                width: Math.max(0, track.width - Math.max(0, range.rightEdge))
                height: parent.height
                color: "#ae090a0f"
                visible: root.clipBackend.hasVideo
                z: 1
            }

            }

            Repeater {
                model: 4
                delegate: Shape {
                    required property int index
                    width: track.radius
                    height: track.radius
                    x: index % 2 ? track.width - width : 0
                    y: index >= 2 ? track.height - height : 0
                    z: 6
                    transform: Scale {
                        origin.x: track.radius / 2
                        origin.y: track.radius / 2
                        xScale: index % 2 ? -1 : 1
                        yScale: index >= 2 ? -1 : 1
                    }
                    ShapePath {
                        fillColor: track.color
                        strokeColor: "transparent"
                        startX: 0
                        startY: 0
                        PathLine { x: track.radius; y: 0 }
                        PathCubic {
                            control1X: track.radius
                            control1Y: track.radius * 0.448
                            control2X: track.radius * 0.448
                            control2Y: track.radius
                            x: 0
                            y: track.radius
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: track.radius
                color: "transparent"
                border.color: track.border.color
                border.width: track.border.width
                z: 7
            }

            Rectangle {
                x: Math.max(0, Math.min(track.width - width,
                        root.duration > 0 ? (root.clipBackend.position - root.viewStart) / root.visibleDuration() * track.width - 1 : 0))
                width: root.dragging ? 3 : 2
                height: track.height
                color: root.tokens.foreground
                z: 4
                visible: root.duration > 0 && root.clipBackend.position >= root.viewStart &&
                         root.clipBackend.position <= root.viewStart + root.visibleDuration()
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    width: 11
                    height: 11
                    radius: 6
                    color: root.tokens.foreground
                    border.color: root.tokens.surface
                    border.width: 2
                }
                Behavior on width { NumberAnimation { duration: root.tokens.effectFast } }
            }

            MouseArea {
                objectName: "timelineSeekArea"
                anchors.fill: parent
                z: 3
                hoverEnabled: true
                Controls.ToolTip.text: "Arraste para navegar · Ctrl+roda: zoom · Shift+roda: mover · duplo clique: ajustar"
                Controls.ToolTip.visible: containsMouse && root.clipBackend.hasVideo
                Controls.ToolTip.delay: 700
                onPressed: function(mouse) {
                    root.beginDrag()
                    root.seek(mouse.x)
                }
                onPositionChanged: function(mouse) { if (pressed) root.seek(mouse.x) }
                onReleased: root.finishDrag()
                onCanceled: root.finishDrag()
                onDoubleClicked: {
                    root.viewZoom = 1
                    root.viewStart = 0
                }
                onWheel: function(wheel) {
                    if (wheel.modifiers & Qt.ControlModifier) {
                        root.zoomAt(wheel.x, wheel.angleDelta.y > 0 ? 1.25 : 0.8)
                        wheel.accepted = true
                    } else if (wheel.modifiers & Qt.ShiftModifier) {
                        root.panByFraction(-wheel.angleDelta.y / 120 * 0.12)
                        wheel.accepted = true
                    }
                }
            }

            Rectangle {
                x: Math.max(0, Math.min(track.width - width, range.leftEdge - 4))
                width: 8
                height: parent.height
                radius: 4
                color: root.tokens.accent
                z: 5
                visible: root.clipBackend.hasVideo && root.clipBackend.clipStart >= root.viewStart &&
                         root.clipBackend.clipStart <= root.viewStart + root.visibleDuration()
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.SizeHorCursor
                    onPressed: function(mouse) {
                        root.beginDrag()
                        root.clipStartOnPress = root.clipBackend.clipStart
                        root.clipEndOnPress = root.clipBackend.clipEnd
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed || root.duration <= 0) return
                        const pos = root.viewStart + mapToItem(track, mouse.x, mouse.y).x / track.width * root.visibleDuration()
                        root.clipBackend.setRange(Math.max(0, Math.min(root.clipEndOnPress - 0.03, pos)), root.clipEndOnPress)
                    }
                    onReleased: root.finishDrag()
                    onCanceled: root.finishDrag()
                }
            }
            Rectangle {
                x: Math.max(0, Math.min(track.width - width, range.rightEdge - 4))
                width: 8
                height: parent.height
                radius: 4
                color: root.tokens.accent
                z: 5
                visible: root.clipBackend.hasVideo && root.clipBackend.clipEnd >= root.viewStart &&
                         root.clipBackend.clipEnd <= root.viewStart + root.visibleDuration()
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.SizeHorCursor
                    onPressed: function(mouse) {
                        root.beginDrag()
                        root.clipStartOnPress = root.clipBackend.clipStart
                        root.clipEndOnPress = root.clipBackend.clipEnd
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed || root.duration <= 0) return
                        const pos = root.viewStart + mapToItem(track, mouse.x, mouse.y).x / track.width * root.visibleDuration()
                        root.clipBackend.setRange(root.clipStartOnPress, Math.max(root.clipStartOnPress + 0.03,
                                                  Math.min(root.duration, pos)))
                    }
                    onReleased: root.finishDrag()
                    onCanceled: root.finishDrag()
                }
            }
        }

    }
}
