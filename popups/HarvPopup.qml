import Quickshell
import QtQuick
import "root:/services"   // MediaService
import "root:/"           // Config

PopupWindow {
    id: root
    property var ctx
    property real px: 0
    property real py: 0
    property real revealProgress: 0
    property real positionSeconds: 0
    property real volumeLevel: 1
    property bool seeking: false
    property bool changingVolume: false
    property bool previousRestartPending: false
    property double previousRestartDeadline: 0

    readonly property var harv: MediaService.harvPlayer
    readonly property real durationSeconds: harv ? harv.length : 0
    readonly property var lyricsPayload: {
        if (!harv) return null
        const encoded = harv.metadata["x-harv:lyrics"]
        return encoded ? JSON.parse(encoded) : null
    }
    readonly property var lyricsLines: lyricsPayload && lyricsPayload.ready ? lyricsPayload.lines : []
    readonly property int activeLyricIndex: {
        if (lyricsLines.length === 0) return -1
        if (lyricsLines.length === 1 || lyricsLines[0].time === lyricsLines[1].time) return 0
        let active = 0
        for (let i = 1; i < lyricsLines.length; i++) {
            if (positionSeconds < lyricsLines[i].time) break
            active = i
        }
        return active
    }

    function openAt(x, y) {
        hideTimer.stop()
        px = x
        py = y
        visible = true
        revealProgress = 1
        syncPlayer()
    }

    function close() {
        revealProgress = 0
        hideTimer.restart()
    }

    function syncPlayer() {
        if (!harv) return
        if (previousRestartPending && !seeking) {
            if (harv.position <= 3.0) {
                previousRestartPending = false
                positionSeconds = 0
            } else if (Date.now() >= previousRestartDeadline) {
                previousRestartPending = false
                positionSeconds = harv.position
            }
        } else if (!seeking) {
            positionSeconds = harv.position
        }
        if (!changingVolume) volumeLevel = harv.volume
    }

    function previousTrack() {
        if (!harv) return
        if (harv.position > 3.0) {
            positionSeconds = 0
            previousRestartPending = true
            previousRestartDeadline = Date.now() + 2000
        }
        MediaService.harvPrevious()
    }

    function seekAt(x) {
        if (!harv || !harv.canSeek || durationSeconds <= 0) return
        const ratio = Math.max(0, Math.min(1, x / progressTrack.width))
        positionSeconds = ratio * durationSeconds
    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        return Math.floor(total / 60) + ":" + ("0" + (total % 60)).slice(-2)
    }

    Timer {
        id: hideTimer
        interval: Config.capsuleAnim
        onTriggered: root.visible = false
    }
    Timer {
        interval: 250
        repeat: true
        running: root.visible
        onTriggered: root.syncPlayer()
    }

    onVisibleChanged: if (!visible && revealProgress > 0) {
        visible = true
        close()
    }
    onHarvChanged: syncPlayer()

    anchor.window: ctx
    anchor.rect.x: px - root.implicitWidth / 2
    anchor.rect.y: py + Config.dracoPopupGap
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: Config.dracoHarvPopupW
    implicitHeight: Config.dracoHarvPopupH
    color: "transparent"
    visible: false
    grabFocus: visible && revealProgress > 0

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.close()

        Item {
            id: revealClip
            width: root.implicitWidth
            height: root.revealProgress * root.implicitHeight
            clip: true

            Canvas {
                id: card
                width: root.implicitWidth
                height: root.implicitHeight
                antialiasing: true
                property color background: Config.dracoPopupBg
                property real cornerRadius: Config.dracoRadius
                onBackgroundChanged: requestPaint()
                onCornerRadiusChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d")
                    g.reset()
                    const w = width, h = height
                    const r = Math.max(0, Math.min(card.cornerRadius, w / 2, h / 2))
                    g.beginPath()
                    g.moveTo(0, 0)
                    g.lineTo(w, 0)
                    g.lineTo(w, h - r)
                    g.arcTo(w, h, w - r, h, r)
                    g.lineTo(r, h)
                    g.arcTo(0, h, 0, h - r, r)
                    g.closePath()
                    g.fillStyle = card.background
                    g.fill()
                }

                Row {
                    id: layout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Column {
                        id: playbackPane
                        width: layout.width - layout.spacing
                        height: layout.height
                        spacing: 7
                        readonly property real sliderWidth: Math.max(0, width - 24)

                        Row {
                            width: parent.width
                            height: coverBox.height + bottomPadding
                            bottomPadding: 12
                            spacing: 8

                            Rectangle {
                                id: coverBox
                                width: 128
                                height: 128
                                radius: Config.dracoRadius / 2
                                color: Config.dracoCapsuleBg
                                clip: true

                                Image {
                                    id: cover
                                    anchors.fill: parent
                                    source: root.harv ? root.harv.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Config.iconMedia
                                    font.family: Config.iconFont
                                    font.pixelSize: 24
                                    color: Config.dracoAccent
                                    visible: cover.status !== Image.Ready
                                }
                            }

                            Column {
                                id: textColumn
                                width: Math.max(0, parent.width - coverBox.width - parent.spacing)
                                leftPadding: 18
                                // largura útil, já descontado o padding
                                readonly property real innerWidth: Math.max(0, width - leftPadding - rightPadding)
                                anchors.verticalCenter: coverBox.verticalCenter
                                spacing: 4

                                Item {
                                    id: titleViewport
                                    width: textColumn.innerWidth
                                    height: titleLabel.implicitHeight
                                    clip: true
                                    onWidthChanged: if (titleLabel.implicitWidth <= width) titleLabel.x = 0

                                    Text {
                                        id: titleLabel
                                        width: implicitWidth
                                        height: parent.height
                                        text: root.harv
                                            ? (root.harv.trackTitle || "Harv")
                                            : MediaService.harvLaunchError || (MediaService.harvLaunching ? "Iniciando Harv…" : "Harv sem reprodução")
                                        color: Config.dracoText
                                        font.pixelSize: Config.dracoTextSize + 1
                                        font.bold: true
                                        wrapMode: Text.NoWrap
                                        onTextChanged: x = 0
                                        onImplicitWidthChanged: if (implicitWidth <= titleViewport.width) x = 0
                                    }

                                    SequentialAnimation {
                                        running: titleLabel.implicitWidth > titleViewport.width
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: 700 }
                                        NumberAnimation {
                                            target: titleLabel
                                            property: "x"
                                            to: Math.min(0, titleViewport.width - titleLabel.implicitWidth)
                                            duration: Math.max(1000, (titleLabel.implicitWidth - titleViewport.width) * 35)
                                        }
                                        PauseAnimation { duration: 900 }
                                        NumberAnimation {
                                            target: titleLabel
                                            property: "x"
                                            to: 0
                                            duration: Math.max(1000, (titleLabel.implicitWidth - titleViewport.width) * 35)
                                        }
                                    }
                                }
                                Item {
                                    id: artistViewport
                                    width: textColumn.innerWidth
                                    height: artistLabel.implicitHeight
                                    clip: true
                                    onWidthChanged: if (artistLabel.implicitWidth <= width) artistLabel.x = 0

                                    Text {
                                        id: artistLabel
                                        width: implicitWidth
                                        height: parent.height
                                        text: root.harv
                                            ? (root.harv.trackArtist || "")
                                            : (MediaService.harvLaunchError ? "Verifique a instalação do Harv" : "Aguardando o player")
                                        color: Config.dracoSub
                                        font.pixelSize: Config.dracoTextSize
                                        wrapMode: Text.NoWrap
                                        onTextChanged: x = 0
                                        onImplicitWidthChanged: if (implicitWidth <= artistViewport.width) x = 0
                                    }

                                    SequentialAnimation {
                                        running: artistLabel.implicitWidth > artistViewport.width
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: 700 }
                                        NumberAnimation {
                                            target: artistLabel
                                            property: "x"
                                            to: Math.min(0, artistViewport.width - artistLabel.implicitWidth)
                                            duration: Math.max(1000, (artistLabel.implicitWidth - artistViewport.width) * 35)
                                        }
                                        PauseAnimation { duration: 900 }
                                        NumberAnimation {
                                            target: artistLabel
                                            property: "x"
                                            to: 0
                                            duration: Math.max(1000, (artistLabel.implicitWidth - artistViewport.width) * 35)
                                        }
                                    }
                                }

                                Row {
                                    id: controls
                                    topPadding: 14
                                    bottomPadding: 6
                                    spacing: 20
                                    // âncoras ignoram o padding da Column: compensa o leftPadding dela
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.horizontalCenterOffset: textColumn.leftPadding / 2

                                    Text {
                                        height: playButton.implicitHeight
                                        verticalAlignment: Text.AlignVCenter
                                        text: Config.iconMediaPrevious
                                        color: Config.dracoText
                                        font.family: Config.iconFont
                                        font.pixelSize: Config.dracoIconSize + 2
                                        opacity: root.harv && root.harv.canGoPrevious ? 1 : 0.45
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            enabled: root.harv && root.harv.canGoPrevious
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.previousTrack()
                                        }
                                    }
                                    Text {
                                        id: playButton
                                        verticalAlignment: Text.AlignVCenter
                                        text: root.harv && root.harv.isPlaying
                                            ? Config.iconMediaPause : Config.iconMediaPlay
                                        color: Config.dracoAccent
                                        font.family: Config.iconFont
                                        font.pixelSize: Config.dracoIconSize + 4
                                        opacity: root.harv ? 1 : 0.45
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            enabled: root.harv && root.harv.canTogglePlaying
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: MediaService.harvToggle()
                                        }
                                    }
                                    Text {
                                        height: playButton.implicitHeight
                                        verticalAlignment: Text.AlignVCenter
                                        text: Config.iconMediaNext
                                        color: Config.dracoText
                                        font.family: Config.iconFont
                                        font.pixelSize: Config.dracoIconSize + 2
                                        opacity: root.harv && root.harv.canGoNext ? 1 : 0.45
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6
                                            enabled: root.harv && root.harv.canGoNext
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: MediaService.harvNext()
                                        }
                                    }
                                }

                                Row {
                                    id: volumeRow
                                    width: textColumn.innerWidth
                                    height: 14
                                    spacing: 3

                                    Text {
                                        id: volumeIcon
                                        text: Config.iconOutput
                                        color: Config.dracoSub
                                        font.family: Config.iconFont
                                        font.pixelSize: Config.dracoIconSize
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Item {
                                        id: volumeTrack
                                        // o que sobra da largura útil depois do ícone, do label e dos gaps
                                        width: Math.max(0, volumeRow.width - volumeIcon.implicitWidth
                                            - volumeLabel.width - 2 * volumeRow.spacing)
                                        height: 7.3
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: Config.dracoCapsuleBg
                                        }
                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, root.volumeLevel))
                                            height: parent.height
                                            radius: height / 2
                                            color: Config.dracoAccent
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: root.harv && root.harv.volumeSupported
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            function setVolume(mouseX) {
                                                root.volumeLevel = Math.max(0, Math.min(1, mouseX / volumeTrack.width))
                                            }
                                            onPressed: (mouse) => { root.changingVolume = true; setVolume(mouse.x) }
                                            onPositionChanged: (mouse) => { if (pressed) setVolume(mouse.x) }
                                            onReleased: {
                                                if (root.harv && root.harv.volumeSupported) root.harv.volume = root.volumeLevel
                                                root.changingVolume = false
                                            }
                                            onCanceled: root.changingVolume = false
                                        }
                                    }
                                    Text {
                                        id: volumeLabel
                                        leftPadding: 3
                                        // largura fixa (a do maior valor): a barra não muda de tamanho ao arrastar
                                        width: volumeSample.advanceWidth + leftPadding
                                        horizontalAlignment: Text.AlignRight
                                        text: Math.round(root.volumeLevel * 100) + "%"
                                        color: Config.dracoSub
                                        font.pixelSize: Config.dracoTextSize - 2
                                        anchors.verticalCenter: parent.verticalCenter

                                        TextMetrics {
                                            id: volumeSample
                                            font: volumeLabel.font
                                            text: "100%"
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: playbackPane.sliderWidth
                            x: (parent.width - width) / 2
                            height: 7

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Config.dracoCapsuleBg
                            }
                            Rectangle {
                                width: root.durationSeconds > 0
                                    ? parent.width * Math.max(0, Math.min(1, root.positionSeconds / root.durationSeconds))
                                    : 0
                                height: parent.height
                                radius: height / 2
                                color: Config.dracoAccent
                            }
                            MouseArea {
                                id: progressTrack
                                anchors.fill: parent
                                enabled: root.harv && root.harv.canSeek && root.durationSeconds > 0
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPressed: (mouse) => { root.seeking = true; root.seekAt(mouse.x) }
                                onPositionChanged: (mouse) => { if (pressed) root.seekAt(mouse.x) }
                                onReleased: {
                                    if (root.harv && root.harv.canSeek) root.harv.position = root.positionSeconds
                                    root.seeking = false
                                }
                                onCanceled: root.seeking = false
                            }
                        }

                        Item {
                            width: parent.width
                            height: 12

                            Text {
                                id: elapsedTime
                                anchors.left: parent.left
                                text: root.formatTime(root.positionSeconds)
                                color: Config.dracoSub
                                font.pixelSize: Config.dracoTextSize - 2
                            }
                            Text {
                                id: durationTime
                                anchors.right: parent.right
                                text: root.formatTime(root.durationSeconds)
                                color: Config.dracoSub
                                font.pixelSize: Config.dracoTextSize - 2
                            }
                        }
                    }
                }
            }
        }
    }

    Behavior on revealProgress {
        NumberAnimation { duration: Config.capsuleAnim; easing.type: Easing.OutCubic }
    }
}
