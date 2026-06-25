import QtQuick

// Uma pétala do menu radial (visual). Lê o estado do controlador `ctx` e os
// valores customizáveis de `Config`. A 1ª pétala (index 0) mostra a sigla do
// layout atual; as demais, o ícone do item.
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

    opacity: (ctx.open && !vanished && !ctx.layoutMode && !ctx.audioMode) ? 1.0 : 0.0

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

        // ── Painel de áudio: 3 botões + divisórias (só na 5ª pétala) ──
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

        // ── Painel de captura: 2 botões (só na 4ª pétala) ──
        Item {
            visible: petal.modelData.capture ?? false
            anchors.fill: parent
            anchors.margins: Config.audioBtnMargin

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.darker(Config.petal, Config.audioBtnDarken)
            }
            // destaque (sec1=topo, sec0=baixo)
            Rectangle {
                visible: petal.hovered && petal.ctx.petalSection >= 0
                width: parent.width
                height: parent.height / 2
                y: (1 - petal.ctx.petalSection) * (parent.height / 2)
                radius: 6
                color: Qt.darker(Config.petal, Config.audioBtnHoverDarken)
            }
            // divisória
            Rectangle {
                width: parent.width * 0.7
                height: 1.5
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - height / 2
                color: Config.petalIcon
                opacity: 0.3
            }
            // ícones (i0=print topo, i1=gravar baixo)
            Repeater {
                model: 2
                delegate: Text {
                    required property int index
                    readonly property bool rec: CaptureService.recording
                    rotation: -petal.rotation
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: index * (parent.height / 2) + (parent.height / 2 - height) / 2
                    font.family: Config.iconFont
                    font.pixelSize: Config.audioIconSize
                    color: (index === 1 && rec) ? Config.captureRecColor : Config.petalIcon
                    text: index === 0 ? Config.iconScreenshot
                                      : (rec ? Config.iconRecording : Config.iconRecord)
                }
            }
        }
    }

    // ── Pétala normal: ícone único ──
    Text {
        visible: !(petal.modelData.audio ?? false) && !(petal.modelData.capture ?? false)
        anchors.centerIn: parent
        rotation: -petal.rotation
        text: petal.index === 0 ? petal.ctx.currentLayoutSymbol : (petal.modelData.icon ?? "")
        font.pixelSize: Config.petalIconSize
        font.bold: petal.index === 0
        color: Config.petalIcon
    }

}
