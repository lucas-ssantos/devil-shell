import QtQuick
import Quickshell.Services.SystemTray
import "root:/services"   // AudioService, CaptureService
import "root:/"           // Config (raiz)

// Um cristal/runa do menu (visual): silhueta com borda
// escura, núcleo na cor do cristal e entalhes finos (nervura central + arcos que
// acompanham o formato). Nos cristais multi-seção os arcos viram as divisórias dos
// botões. Fica DE PÉ no chão, ao lado da bola, numa escadaria de alturas (rank 0 =
// colado à bola = mais alto); enterrado mostra só um peek, e "emerge do chão" quando
// erguido (hover só nele, ou a bola aberta ergue todos).
// Lê o estado do controlador `ctx` e os valores customizáveis de `Config`.
Item {
    id: crystal
    property var ctx
    required property int index
    required property var modelData

    readonly property bool hovered: ctx.hoverIndex === index
    readonly property bool selected: ctx.selectedIndex === index
    readonly property bool vanished: ctx.selectedIndex !== -1 && !selected
    readonly property bool raised: ctx.crystalRaised(index)

    // cristais multi-seção (painéis): áudio/sistema = 3 botões, bandeja = 1 por app
    readonly property bool isAudio: modelData.audio ?? false
    readonly property bool isSettings: modelData.settings ?? false
    readonly property bool isTray: modelData.tray ?? false
    readonly property bool multi: isAudio || isSettings || isTray
    readonly property int sections: (isAudio || isSettings) ? 3
        : isTray ? SystemTray.items.values.length : 0

    width: ctx.crystalW
    height: ctx.crystalHeight(index)
    x: ctx.crystalCX(index) - width / 2
    z: 1

    // emersão: `rise` é a fatia visível acima do chão (peek enterrado, altura toda
    // erguido); o resto do corpo fica abaixo da borda da janela (cortado pelo chão)
    property real rise: raised ? height : Config.crystalPeek
    y: ctx.height - rise
    Behavior on rise { NumberAnimation { duration: Config.crystalRiseAnim; easing.type: Easing.OutBack } }

    // cresce no hover a partir da BASE (continua plantado no chão)
    transformOrigin: Item.Bottom
    scale: (hovered || selected) ? Config.crystalHoverScale : 1.0
    Behavior on scale { NumberAnimation { duration: Config.crystalScaleAnim; easing.type: Easing.OutQuad } }

    opacity: (!vanished && !ctx.audioMode) ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: Config.crystalOpacityAnim } }

    // corpo do cristal
    Item {
        id: body
        anchors.fill: parent

        // o cristal inteiro: glow, borda, núcleo, destaque de seção e entalhes rúnicos.
        // O canvas é maior que o cristal (margens negativas) p/ o glow não ser cortado;
        // `pad` desloca o desenho de volta ao retângulo do cristal.
        Canvas {
            id: gem
            readonly property real pad: Config.crystalGlowBlur + 4
            anchors.fill: parent
            anchors.margins: -pad
            antialiasing: true

            property color bodyColor: Config.crystal
            property color hoverColor: Config.crystalHover
            property color engraveColor: Config.crystalEngrave
            property color glowColor: Config.crystalGlow
            property real edgeDarken: Config.crystalEdgeDarken
            property real coreFactor: Config.crystalCoreFactor
            property real engraveOp: Config.crystalEngraveOpacity
            property real engraveW: Config.crystalEngraveWidth
            property real btnDarken: Config.audioBtnDarken
            property real btnHoverDarken: Config.audioBtnHoverDarken
            property int  nSections: crystal.sections
            property int  hlSection: (crystal.hovered && crystal.sections > 0) ? crystal.ctx.crystalSection : -1
            // preenchimento do brilho de hover (0–1): sobe da base à ponta ao entrar,
            // e "escorre" de volta ao sair
            property real fillAmt: (crystal.hovered || crystal.selected) ? 1.0 : 0.0
            Behavior on fillAmt { NumberAnimation { duration: Config.crystalFillAnim; easing.type: Easing.OutCubic } }
            // pulso do glow no hover: respiração não-linear (cai devagar, volta rápido)
            property real pulse: 1.0
            SequentialAnimation on pulse {
                running: crystal.hovered || crystal.selected
                loops: Animation.Infinite
                NumberAnimation { to: Config.crystalPulseMin; duration: Config.crystalPulseTime; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: Config.crystalPulseTime * 0.6; easing.type: Easing.OutCubic }
            }

            onBodyColorChanged: requestPaint()
            onHoverColorChanged: requestPaint()
            onEngraveColorChanged: requestPaint()
            onGlowColorChanged: requestPaint()
            onFillAmtChanged: requestPaint()
            onPulseChanged: requestPaint()
            onEdgeDarkenChanged: requestPaint()
            onCoreFactorChanged: requestPaint()
            onEngraveOpChanged: requestPaint()
            onEngraveWChanged: requestPaint()
            onNSectionsChanged: requestPaint()
            onHlSectionChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            // silhueta do cristal: OBELISCO reto — base reta (fincada no chão),
            // laterais VERTICAIS e paralelas (sem taper nem vértice no meio: qualquer
            // quebra rasa na lateral lê como "bojo" sob o glow) e ponta TRUNCADA
            // (topo reto curto entre dois chanfros). Nada de curvas.
            // kw = fator da meia-largura; y0/y1 = ponta/base (coords já transladadas).
            function crystalPath(g, kw, y0, y1) {
                const cx = (width - 2 * pad) / 2
                const hw = ((width - 2 * pad) / 2 - 1) * kw
                const H = y1 - y0
                g.beginPath()
                g.moveTo(cx - hw, y1)                       // canto esquerdo da base
                g.lineTo(cx - hw, y0 + 0.14 * H)            // lateral VERTICAL
                g.lineTo(cx - 0.12 * hw, y0)                // chanfro esquerdo
                g.lineTo(cx + 0.12 * hw, y0)                // topo RETO (ponta quadrada)
                g.lineTo(cx + hw, y0 + 0.14 * H)            // chanfro direito
                g.lineTo(cx + hw, y1)                       // lateral vertical
                g.closePath()                               // base reta
            }

            // pinta o cristal completo numa cor/intensidade de glow (uma "passada")
            function drawGem(g, w, h, cx, body, glowA) {
                // borda (silhueta externa) com GLOW: a sombra do próprio path faz o halo
                crystalPath(g, 1.0, 0.5, h)
                g.shadowColor = Qt.rgba(glowColor.r, glowColor.g, glowColor.b, 0.9 * glowA)
                g.shadowBlur = Config.crystalGlowBlur * glowA
                g.fillStyle = Qt.darker(body, edgeDarken)
                g.fill()
                g.fill()   // 2ª passada reforça o halo
                g.shadowColor = "transparent"
                g.shadowBlur = 0

                // núcleo (nos painéis multi-seção fica um tom mais escuro = clicável)
                crystalPath(g, coreFactor, 0.06 * h, 0.97 * h)
                g.fillStyle = crystal.multi ? Qt.darker(body, btnDarken) : body
                g.fill()

                // daqui em diante tudo é recortado pela silhueta
                g.save()
                crystalPath(g, 1.0, 0.5, h)
                g.clip()

                // destaque da seção sob o cursor (seção 0 = junto à bola = embaixo)
                if (hlSection >= 0 && nSections > 0) {
                    const slot = h / nSections
                    g.globalAlpha = 0.6
                    g.fillStyle = Qt.darker(body, btnHoverDarken)
                    g.fillRect(0, (nSections - 1 - hlSection) * slot, w, slot)
                    g.globalAlpha = 1.0
                }

                // entalhes rúnicos: nervura central + arcos transversais (o clip
                // recorta os arcos na silhueta, então eles acompanham o formato)
                g.strokeStyle = engraveColor
                g.lineWidth = engraveW
                g.globalAlpha = engraveOp
                g.beginPath()
                g.moveTo(cx, 0.06 * h)
                g.lineTo(cx, 0.97 * h)
                g.stroke()
                // arcos nas divisas das seções (painéis) ou decorativos (cristal comum)
                let ts = []
                if (nSections > 1)
                    for (let k = 1; k < nSections; k++) ts.push(k / nSections)
                else
                    ts = [0.26, 0.45, 0.70]
                for (const t of ts) {
                    const y = t * h
                    g.beginPath()
                    g.moveTo(0, y)
                    g.lineTo(w, y)   // divisória RETA (visual facetado, sem curvas)
                    g.stroke()
                }

                // "mesa" da lapidação: linha dos chanfros sob o topo reto (o clip
                // recorta nas bordas, marcando a faceta da ponta quadrada)
                g.globalAlpha = 0.35
                g.beginPath()
                g.moveTo(0, 0.14 * h)   // na base dos chanfros (casa com o crystalPath)
                g.lineTo(w, 0.14 * h)
                g.stroke()
                g.restore()
                g.globalAlpha = 1.0
            }

            onPaint: {
                const g = getContext("2d")
                g.reset()
                g.translate(pad, pad)
                const w = width - 2 * pad, h = height - 2 * pad, cx = w / 2

                // passada de repouso: cor base + glow fraco
                drawGem(g, w, h, cx, bodyColor, Config.crystalGlowRest)

                // camada "acesa" do hover: cor de hover + glow pulsante, recortada por
                // um retângulo que sobe da base (junto à bola) até a ponta conforme
                // fillAmt cresce — o brilho "preenche" o cristal de baixo p/ cima.
                // O retângulo inclui o pad p/ o halo não ser decepado nas laterais.
                if (fillAmt > 0.003) {
                    g.save()
                    const yTop = h + pad - fillAmt * (h + 2 * pad)
                    g.beginPath()
                    g.rect(-pad, yTop, w + 2 * pad, h + 2 * pad - yTop)
                    g.clip()
                    drawGem(g, w, h, cx, hoverColor, pulse)
                    g.restore()
                }
            }
        }

        // ── Painel de áudio: 3 botões (só ícones; divisórias/destaque vêm do cristal) ──
        Item {
            visible: crystal.isAudio
            anchors.fill: parent
            anchors.margins: Config.audioBtnMargin

            // ícones (i0=headphone topo, i1=mic, i2=config baixo)
            Repeater {
                model: 3
                delegate: Text {
                    required property int index
                    readonly property bool muted: index === 0 ? AudioService.sinkMuted
                                                : index === 1 ? AudioService.sourceMuted : false
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: index * (parent.height / 3) + (parent.height / 3 - height) / 2
                    font.family: Config.iconFont
                    font.pixelSize: Config.audioIconSize
                    color: Config.crystalIcon
                    opacity: muted ? 0.4 : 1.0
                    text: index === 0 ? (muted ? Config.iconOutputMuted : Config.iconOutput)
                        : index === 1 ? (muted ? Config.iconInputMuted : Config.iconInput)
                        : Config.iconConfig
                }
            }
        }

        // ── Painel de sistema: 3 botões (configurações + gravação + toggle de lock) ──
        Item {
            visible: crystal.isSettings
            anchors.fill: parent
            anchors.margins: Config.audioBtnMargin

            // ícones (i0=engrenagem topo=config, i1=gravar meio, i2=lâmpada baixo=toggle lock)
            Repeater {
                model: 3
                delegate: Text {
                    required property int index
                    readonly property bool rec: index === 1 && CaptureService.recording
                    // lâmpada "acesa" (cor de acento) quando o lock/idle está inibido
                    readonly property bool lampOn: index === 2 && IdleService.inhibited
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: index * (parent.height / 3) + (parent.height / 3 - height) / 2
                    font.family: Config.iconFont
                    font.pixelSize: Config.audioIconSize
                    color: rec ? Config.captureRecColor
                         : lampOn ? Config.idleOnColor : Config.crystalIcon
                    opacity: (index === 2 && !IdleService.inhibited) ? 0.55 : 1.0
                    text: index === 0 ? Config.iconConfig
                        : index === 1 ? (rec ? Config.iconRecording : Config.iconRecord)
                        : Config.iconIdle
                }
            }
        }

        // ── Painel da bandeja (system tray): 1 seção por app (só no cristal da bandeja) ──
        Item {
            id: trayPanel
            visible: crystal.isTray
            anchors.fill: parent
            anchors.margins: Config.audioBtnMargin
            readonly property int count: SystemTray.items.values.length
            readonly property real slot: height / Math.max(1, count)

            // ícone genérico quando não há nenhum app na bandeja
            Text {
                visible: trayPanel.count === 0
                anchors.centerIn: parent
                text: Config.iconTray
                font.family: Config.iconFont
                font.pixelSize: Config.audioIconSize
                color: Config.crystalIcon
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
                        text: (trayCell.modelData.title || trayCell.modelData.id || "?").charAt(0).toUpperCase()
                        font.pixelSize: Config.trayIconSize - 2
                        font.bold: true
                        color: Config.crystalIcon
                    }
                }
            }
        }
    }

    // ── Cristal normal: ícone único ──
    Text {
        visible: !crystal.multi
        anchors.centerIn: parent
        text: crystal.modelData.icon ?? ""
        font.pixelSize: Config.crystalIconSize
        color: Config.crystalIcon
    }

}
