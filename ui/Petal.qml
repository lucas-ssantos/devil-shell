import QtQuick
import Quickshell.Services.SystemTray
import "root:/services"   // AudioService, CaptureService
import "root:/"           // Config (raiz)

// Uma pétala do menu radial (visual). Lê o estado do controlador `ctx` e os
// valores customizáveis de `Config`.
Item {
    id: petal
    property var ctx
    required property int index
    required property var modelData

    readonly property real angleDeg: ctx.petalAngle(index)
    readonly property real angleRad: angleDeg * Math.PI / 180
    readonly property bool hovered: ctx.hoverIndex === index
    readonly property bool selected: ctx.selectedIndex === index
    readonly property bool vanished: ctx.selectedIndex !== -1 && !selected

    width: ctx.petalW
    height: ctx.petalH
    transformOrigin: Item.Center
    rotation: 90 - angleDeg
    z: 1

    property real dist: !ctx.open ? 0
        : (hovered || selected)   ? ctx.petalDist
        : (ctx.hoverIndex !== -1) ? ctx.petalTouch   // outra em hover -> recua até a bola
        : ctx.petalDist
    x: ctx.ballCX + dist * Math.cos(angleRad) - width / 2
    y: ctx.ballCY - dist * Math.sin(angleRad) - height / 2

    opacity: (ctx.open && !vanished && !ctx.audioMode) ? 1.0 : 0.0

    Behavior on dist { NumberAnimation { duration: Config.petalDistAnim; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: Config.petalOpacityAnim } }

    // corpo da pétala (cresce no hover; base fica reta quando há hover ativo)
    Rectangle {
        anchors.fill: parent
        // em hover, estende a base ~5px em direção à bola (conecta melhor)
        anchors.bottomMargin: petal.hovered ? -Config.petalHoverExtend : 0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: Config.petalScaleAnim } }
        topLeftRadius: width / 2
        topRightRadius: width / 2
        bottomLeftRadius: (petal.ctx.hoverIndex !== -1) ? 0 : width / 2
        bottomRightRadius: (petal.ctx.hoverIndex !== -1) ? 0 : width / 2
        Behavior on bottomLeftRadius { NumberAnimation { duration: Config.petalRadiusAnim } }
        Behavior on bottomRightRadius { NumberAnimation { duration: Config.petalRadiusAnim } }
        transformOrigin: Item.Center
        scale: (petal.hovered || petal.selected) ? Config.petalHoverScale
             : (petal.ctx.hoverIndex !== -1)     ? petal.ctx.petalShrink
             : 1.0
        color: petal.hovered ? Config.petalHover : Config.petal
        Behavior on scale { NumberAnimation { duration: Config.petalScaleAnim; easing.type: Easing.OutQuad } }

        // cantos góticos da base (emergem só na pétala em hover)
        Canvas {
            id: pflare
            width: parent.width + 2 * petal.ctx.petalFlare
            height: petal.ctx.petalFlare + 2
            x: -petal.ctx.petalFlare
            y: parent.height - 1
            property real amt: (petal.hovered && petal.ctx.open) ? 1 : 0
            property color col: petal.hovered ? Config.petalHover : Config.petal
            Behavior on amt { NumberAnimation { duration: Config.petalFlareAnim; easing.type: Easing.OutQuad } }
            onAmtChanged: requestPaint()
            onColChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const g = getContext("2d")
                g.reset()
                if (amt <= 0.01) return
                const f = petal.ctx.petalFlare * amt
                const W = parent.width
                const xL = petal.ctx.petalFlare
                const xR = petal.ctx.petalFlare + W
                g.fillStyle = col
                // canto direito (côncavo)
                g.beginPath()
                g.moveTo(xR, f); g.lineTo(xR + f, f); g.lineTo(xR + f, 0)
                g.arc(xR, 0, f, 0, Math.PI / 2, false)
                g.closePath(); g.fill()
                // canto esquerdo (espelhado)
                g.beginPath()
                g.moveTo(xL, f); g.lineTo(xL - f, f); g.lineTo(xL - f, 0)
                g.arc(xL, 0, f, Math.PI, Math.PI / 2, true)
                g.closePath(); g.fill()
            }
        }

        // ── Painel de áudio: 3 botões + divisórias (só na pétala de áudio) ──
        Item {
            visible: petal.modelData.audio ?? false
            anchors.fill: parent
            anchors.margins: Config.audioBtnMargin

            // fundo do painel (um pouco mais escuro = clicável)
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.darker(Config.petal, Config.audioBtnDarken)
            }
            // destaque da seção sob o cursor
            Rectangle {
                visible: petal.hovered && petal.ctx.petalSection >= 0
                width: parent.width
                height: parent.height / 3
                y: (2 - petal.ctx.petalSection) * (parent.height / 3)   // sec2=topo … sec0=baixo
                radius: 6
                color: Qt.darker(Config.petal, Config.audioBtnHoverDarken)
            }
            // divisórias entre os botões
            Repeater {
                model: 2
                delegate: Rectangle {
                    required property int index
                    width: parent.width * 0.7
                    height: 1.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (index + 1) * (parent.height / 3) - height / 2
                    color: Config.petalIcon
                    opacity: 0.3
                }
            }
            // ícones (i0=headphone topo, i1=mic, i2=config baixo)
            Repeater {
                model: 3
                delegate: Text {
                    required property int index
                    readonly property bool muted: index === 0 ? AudioService.sinkMuted
                                                : index === 1 ? AudioService.sourceMuted : false
                    rotation: -petal.rotation
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: index * (parent.height / 3) + (parent.height / 3 - height) / 2
                    font.family: Config.iconFont
                    font.pixelSize: Config.audioIconSize
                    color: Config.petalIcon
                    opacity: muted ? 0.4 : 1.0
                    text: index === 0 ? (muted ? Config.iconOutputMuted : Config.iconOutput)
                        : index === 1 ? (muted ? Config.iconInputMuted : Config.iconInput)
                        : Config.iconConfig
                }
            }
        }

        // ── Painel de sistema: 3 botões (configurações + gravação + toggle de lock) ──
        Item {
            visible: petal.modelData.settings ?? false
            anchors.fill: parent
            anchors.margins: Config.audioBtnMargin

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.darker(Config.petal, Config.audioBtnDarken)
            }
            // destaque da seção sob o cursor (sec2=topo=config, sec1=meio=gravar, sec0=baixo=lâmpada)
            Rectangle {
                visible: petal.hovered && petal.ctx.petalSection >= 0
                width: parent.width
                height: parent.height / 3
                y: (2 - petal.ctx.petalSection) * (parent.height / 3)
                radius: 6
                color: Qt.darker(Config.petal, Config.audioBtnHoverDarken)
            }
            // divisórias entre os botões
            Repeater {
                model: 2
                delegate: Rectangle {
                    required property int index
                    width: parent.width * 0.7
                    height: 1.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (index + 1) * (parent.height / 3) - height / 2
                    color: Config.petalIcon
                    opacity: 0.3
                }
            }
            // ícones (i0=engrenagem topo=config, i1=gravar meio, i2=lâmpada baixo=toggle lock)
            Repeater {
                model: 3
                delegate: Text {
                    required property int index
                    readonly property bool rec: index === 1 && CaptureService.recording
                    // lâmpada "acesa" (cor de acento) quando o lock/idle está inibido
                    readonly property bool lampOn: index === 2 && IdleService.inhibited
                    rotation: -petal.rotation
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: index * (parent.height / 3) + (parent.height / 3 - height) / 2
                    font.family: Config.iconFont
                    font.pixelSize: Config.audioIconSize
                    color: rec ? Config.captureRecColor
                         : lampOn ? Config.idleOnColor : Config.petalIcon
                    opacity: (index === 2 && !IdleService.inhibited) ? 0.55 : 1.0
                    text: index === 0 ? Config.iconConfig
                        : index === 1 ? (rec ? Config.iconRecording : Config.iconRecord)
                        : Config.iconIdle
                }
            }
        }

        // ── Painel da bandeja (system tray): 1 seção por app (só na pétala da bandeja) ──
        Item {
            id: trayPanel
            visible: petal.modelData.tray ?? false
            anchors.fill: parent
            anchors.margins: Config.audioBtnMargin
            readonly property int count: SystemTray.items.values.length
            readonly property real slot: height / Math.max(1, count)

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.darker(Config.petal, Config.audioBtnDarken)
            }
            // destaque da seção (app) sob o cursor — seção 0 = junto à bola (baixo)
            Rectangle {
                visible: petal.hovered && petal.ctx.petalSection >= 0 && trayPanel.count > 0
                width: parent.width
                height: trayPanel.slot
                y: (trayPanel.count - 1 - petal.ctx.petalSection) * trayPanel.slot
                radius: 6
                color: Qt.darker(Config.petal, Config.audioBtnHoverDarken)
            }
            // divisórias entre os apps
            Repeater {
                model: Math.max(0, trayPanel.count - 1)
                delegate: Rectangle {
                    required property int index
                    width: parent.width * 0.7
                    height: 1.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (index + 1) * trayPanel.slot - height / 2
                    color: Config.petalIcon
                    opacity: 0.3
                }
            }
            // ícone genérico quando não há nenhum app na bandeja
            Text {
                visible: trayPanel.count === 0
                anchors.centerIn: parent
                rotation: -petal.rotation
                text: Config.iconTray
                font.family: Config.iconFont
                font.pixelSize: Config.audioIconSize
                color: Config.petalIcon
                opacity: 0.5
            }
            // ícones dos apps (item k = seção k; seção 0 junto à bola = embaixo)
            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: trayCell
                    required property var modelData
                    required property int index
                    width: trayPanel.width
                    height: trayPanel.slot
                    y: (trayPanel.count - 1 - index) * trayPanel.slot
                    Image {
                        id: trayImg
                        // só aparece quando carregou de fato (evita o ícone de "imagem quebrada"
                        // de apps com SNI torto, ex. pasystray, que erram no IconName)
                        visible: status === Image.Ready
                        anchors.centerIn: parent
                        rotation: -petal.rotation
                        source: trayCell.modelData.icon
                        sourceSize.width: Config.trayIconSize
                        sourceSize.height: Config.trayIconSize
                        width: Config.trayIconSize
                        height: Config.trayIconSize
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    // fallback: inicial do app quando o ícone não carrega
                    Text {
                        visible: trayImg.status !== Image.Ready
                        anchors.centerIn: parent
                        rotation: -petal.rotation
                        text: (trayCell.modelData.title || trayCell.modelData.id || "?").charAt(0).toUpperCase()
                        font.pixelSize: Config.trayIconSize - 2
                        font.bold: true
                        color: Config.petalIcon
                    }
                }
            }
        }
    }

    // ── Pétala normal: ícone único ──
    Text {
        visible: !(petal.modelData.audio ?? false) && !(petal.modelData.tray ?? false) && !(petal.modelData.settings ?? false)
        anchors.centerIn: parent
        rotation: -petal.rotation
        text: petal.modelData.icon ?? ""
        font.pixelSize: Config.petalIconSize
        color: Config.petalIcon
    }

}
