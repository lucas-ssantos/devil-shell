import QtQuick
import "root:/"   // Config (raiz)

// A bola/menu central: sigilo (pentáculo) gravado ao fundo, número do workspace
// ativo por cima e o anel TRACEJADO de workspaces — um arco por workspace, todos
// sempre visíveis (ativo mais grosso; urgente/ocupado/vazio mudam a cor).
Rectangle {
    id: ball
    property var ctx

    readonly property real r2: ctx.ballRadius + 2   // ~2px maior que o raio dos filetes (cobre a junção)
    z: 3
    width: r2 * 2
    height: width
    radius: width / 2
    x: ctx.ballCX - r2
    y: ctx.ballCY - r2
    color: Config.ball
    antialiasing: true
    border.width: 0

    // sigilo gravado no fundo da bola (círculo + pentagrama, ponta para cima)
    Canvas {
        id: sigil
        anchors.fill: parent
        antialiasing: true
        property color col: Config.ballSigil
        property real r: ball.ctx.ballRadius * Config.ballSigilFactor
        onColChanged: requestPaint()
        onRChanged: requestPaint()
        onWidthChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const g = getContext("2d")
            g.reset()
            const cx = width / 2, cy = height / 2
            g.strokeStyle = col
            g.globalAlpha = 0.9
            // círculo do pentáculo
            g.lineWidth = 1
            g.beginPath()
            g.arc(cx, cy, r + 2.5, 0, 2 * Math.PI)
            g.stroke()
            // pentagrama: 5 pontas ligadas de 2 em 2 (0→2→4→1→3→0)
            g.lineWidth = 1.3
            g.beginPath()
            for (let k = 0; k <= 5; k++) {
                const a = (-90 + (k * 2 % 5) * 72) * Math.PI / 180
                const px = cx + r * Math.cos(a), py = cy + r * Math.sin(a)
                if (k === 0) g.moveTo(px, py); else g.lineTo(px, py)
            }
            g.stroke()
        }
    }

    // anel tracejado: um arco por workspace (o arco i é centrado em -90° + i·slot,
    // no sentido horário a partir do topo — o hit-test dotAt do controlador usa o mesmo mapa).
    // O destaque do ativo é um PONTINHO orbital (estilo spinner de loading) que viaja
    // pelo anel (animPos) acendendo cada arco por onde passa; no wrap N↔1 ele dá a
    // volta na direção do scroll, varrendo os fantasmas. Com a bola recolhida os arcos
    // encolhem (vão maior + traço mais fino); aberta, crescem e o ativo cresce mais (openK).
    Canvas {
        id: wsRing
        anchors.fill: parent
        antialiasing: true
        property var tags: ball.ctx.allTags
        property real ringR: ball.ctx.dotRingR
        property real arcW: Config.dotArcW
        property real arcWActive: Config.dotArcActiveW
        property color cActive: Config.dotActive
        property color cUrgent: Config.dotUrgent
        property color cOccupied: Config.dotOccupied
        property color cEmpty: Config.dotEmpty

        // 0 = bola recolhida, 1 = aberta (anima junto com a bola)
        property real openK: ball.ctx.open ? 1 : 0
        Behavior on openK { NumberAnimation { duration: Config.ballAnim; easing.type: Easing.OutCubic } }
        readonly property real gapDeg: Config.dotArcGapClosedDeg + (Config.dotArcGapDeg - Config.dotArcGapClosedDeg) * openK
        readonly property real wScale: Config.dotClosedScale + (Config.dotOpenScale - Config.dotClosedScale) * openK

        // posição contínua do pontinho (em slots, desenrolada p/ acumular voltas). No
        // scroll a viagem segue a DIREÇÃO do gesto (ctx.wsTravelDir): no wrap N→1 o
        // pontinho dá a volta varrendo os fantasmas, como um spinner de loading.
        readonly property int targetIdx: Math.max(0, ball.ctx.activeTag - 1)
        property real animPos: 0
        property int travelDur: Config.dotTravelMs
        Behavior on animPos { NumberAnimation { duration: wsRing.travelDur; easing.type: Easing.InOutQuad } }
        function retarget() {
            const n = (tags ?? []).length
            if (n === 0) return
            const cur = ((animPos % n) + n) % n
            const dir = ball.ctx.wsTravelDir
            ball.ctx.wsTravelDir = 0                      // consome a dica de direção
            let d = (targetIdx - cur) % n
            if (dir > 0)      d = ((d % n) + n) % n       // sempre horário (p/ frente)
            else if (dir < 0) d = ((d % n) - n) % n       // sempre anti-horário
            else if (d > n / 2) d -= n                    // sem dica: caminho mais curto
            else if (d < -n / 2) d += n
            if (d === 0) return
            travelDur = Math.round(Config.dotTravelMs * Math.abs(d))  // velocidade constante por slot
            animPos = animPos + d
        }
        onTargetIdxChanged: retarget()
        onTagsChanged: { retarget(); requestPaint() }
        onAnimPosChanged: requestPaint()
        onOpenKChanged: requestPaint()
        onRingRChanged: requestPaint()
        onArcWChanged: requestPaint()
        onArcWActiveChanged: requestPaint()
        onCActiveChanged: requestPaint()
        onCUrgentChanged: requestPaint()
        onCOccupiedChanged: requestPaint()
        onCEmptyChanged: requestPaint()
        onWidthChanged: requestPaint()
        Component.onCompleted: { retarget(); requestPaint() }
        onPaint: {
            const g = getContext("2d")
            g.reset()
            const n = (tags ?? []).length
            if (n === 0) return
            const cx = width / 2, cy = height / 2
            const slot = 360 / n
            const gap = Math.min(gapDeg, slot * 0.5)   // vão nunca engole o arco
            const pos = ((animPos % n) + n) % n
            g.lineCap = "round"
            for (let i = 0; i < n; i++) {
                const t = tags[i]
                // intensidade do destaque neste arco: 1 sob ele, decai linearmente ao
                // passar p/ o vizinho (distância circular) — é o fade da "viagem"
                let dd = Math.abs(i - pos)
                dd = Math.min(dd, n - dd)
                const k = Math.max(0, 1 - dd)
                const base = t.is_urgent ? cUrgent
                           : t.client_count > 0 ? cOccupied : cEmpty
                const a0 = (-90 - slot / 2 + i * slot + gap / 2) * Math.PI / 180
                const a1 = (-90 - slot / 2 + (i + 1) * slot - gap / 2) * Math.PI / 180
                g.beginPath()
                g.arc(cx, cy, ringR, a0, a1, false)
                g.lineWidth = (arcW + (arcWActive - arcW) * k) * wScale
                g.strokeStyle = Qt.rgba(base.r + (cActive.r - base.r) * k,
                                        base.g + (cActive.g - base.g) * k,
                                        base.b + (cActive.b - base.b) * k, 1)
                const baseAlpha = (t.is_urgent || t.client_count > 0) ? 1.0 : 0.65
                g.globalAlpha = baseAlpha + (1 - baseAlpha) * k
                g.stroke()
            }
            // o pontinho orbital (estilo spinner): bolinha cheia sobre o anel, na posição
            // contínua da viagem — parado, senta no centro do arco do workspace ativo
            const oa = (-90 + pos * slot) * Math.PI / 180
            const or_ = Config.dotOrbR * wScale
            g.globalAlpha = 1
            g.fillStyle = cActive
            g.shadowColor = cActive
            g.shadowBlur = or_ * 2.5
            g.beginPath()
            g.arc(cx + ringR * Math.cos(oa), cy + ringR * Math.sin(oa), or_, 0, 2 * Math.PI)
            g.fill()
            g.shadowBlur = 0
        }
    }

    // número do workspace ativo (por cima do sigilo)
    Text {
        anchors.centerIn: parent
        text: ball.ctx.activeTag > 0 ? ball.ctx.activeTag : ""
        color: Config.ballText
        font.pixelSize: Config.ballNumberSize
        font.bold: true
    }
}
