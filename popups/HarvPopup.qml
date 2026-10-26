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
                property color background: Config.dracoBg
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
                        width: (layout.width - layout.spacing) * 0.45
                        height: layout.height
                        spacing: 7
                        readonly property real sliderWidth: Math.max(0, width - 24)

                        Row {
                            width: parent.width
                            height: 128
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

                            //padding do bloco ao lado da imagem
                            Item {
                                id: coverGap
                                width: 10
                                height: 1
                            }

                            Column {
                                // espaço restante = Row - capa - espaçador - 2 gaps do spacing
                                width: Math.max(0, parent.width - coverBox.width - coverGap.width - 2 * parent.spacing)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Item {
                                    id: titleViewport
                                    width: parent.width
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
                                    width: parent.width
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

                                Item {
                                    width: 1
                                    height: 10
                                }

                                Row {
                                    id: controls
                                    anchors.horizontalCenter: parent.verticalCenter
                                    spacing: 20

                                    Text {
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
                            }
                        }

                        //paddimg no topo das barras
                        Item {
                            width: 1
                            height: 5
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

                        Row {
                            width: parent.width
                            height: 12

                            Text {
                                id: elapsedTime
                                text: root.formatTime(root.positionSeconds)
                                color: Config.dracoSub
                                font.pixelSize: Config.dracoTextSize - 2
                            }
                            Item {
                                width: parent.width - elapsedTime.implicitWidth - durationTime.implicitWidth
                                height: 1
                            }
                            Text {
                                id: durationTime
                                text: root.formatTime(root.durationSeconds)
                                color: Config.dracoSub
                                font.pixelSize: Config.dracoTextSize - 2
                            }
                        }

                        Row {
                            id: volumeRow
                            width: playbackPane.sliderWidth + volumeIcon.implicitWidth
                                + volumeLabel.implicitWidth + 2 * spacing + 1
                            x: (playbackPane.width - width) / 2 + 5
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
                                width: playbackPane.sliderWidth - 14
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

                            Item {
                                width: 0.1
                                height: 1
                            }

                            Text {
                                id: volumeLabel
                                text: Math.round(root.volumeLevel * 100) + "%"
                                color: Config.dracoSub
                                font.pixelSize: Config.dracoTextSize - 2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: Config.dracoSub
                        opacity: 0.35
                    }

                    Column {
                        id: lyricsPane
                        width: layout.width - playbackPane.width - layout.spacing - 1
                        height: layout.height
                        spacing: 6

                        Text {
                            text: "LETRAS"
                            color: Config.dracoSub
                            font.pixelSize: Config.dracoTextSize - 1
                            font.bold: true
                        }

                        Item {
                            width: parent.width
                            height: parent.height - 18

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                horizontalAlignment: Text.AlignHCenter
                                text: !root.harv ? "Aguardando o Harv…"
                                    : !root.lyricsPayload ? "Buscando letras…"
                                    : root.lyricsLines.length === 0 ? "Nenhuma letra disponível"
                                    : ""
                                color: Config.dracoSub
                                font.pixelSize: Config.dracoTextSize
                                wrapMode: Text.Wrap
                                visible: text.length > 0
                            }

                            Flickable {
                                id: lyricsFlick
                                anchors.fill: parent
                                clip: true
                                visible: root.lyricsLines.length > 0
                                contentWidth: width
                                contentHeight: lyricsColumn.implicitHeight
                                contentY: Math.max(0, Math.min(contentHeight - height,
                                    (root.activeLyricIndex + 0.5) * 36 - height / 2))
                                Behavior on contentY {
                                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                }

                                Column {
                                    id: lyricsColumn
                                    width: lyricsFlick.width

                                    Repeater {
                                        model: root.lyricsLines
                                        delegate: Text {
                                            required property var modelData
                                            required property int index
                                            width: lyricsColumn.width
                                            height: 36
                                            text: modelData.text
                                            color: index === root.activeLyricIndex
                                                ? Config.dracoAccent : Config.dracoSub
                                            opacity: index === root.activeLyricIndex ? 1 : 0.65
                                            font.pixelSize: Config.dracoTextSize + (index === root.activeLyricIndex ? 1 : 0)
                                            font.bold: index === root.activeLyricIndex
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
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
