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
    // O destaque do ativo é o próprio arco COLORIDO, que age como o "ponto" da viagem
    // (animPos): a cada passo ele encolhe até sumir no workspace de origem e cresce do
    // zero no seguinte, arco a arco até o destino; no wrap N↔1 dá a volta na direção do
    // scroll, varrendo os fantasmas. Com a bola recolhida os arcos encolhem (vão maior
    // + traço mais fino); aberta, crescem e o ativo cresce mais (openK).
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

        // posição contínua do destaque (em slots, desenrolada p/ acumular voltas). No
        // scroll a viagem segue a DIREÇÃO do gesto (ctx.wsTravelDir): no wrap N→1 o
        // destaque dá a volta varrendo os fantasmas, como um spinner de loading.
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
            travelSign = d > 0 ? 1 : -1                   // ancora o encolher/crescer na borda certa
            travelDur = Math.round(Config.dotTravelMs * Math.abs(d))  // velocidade constante por slot
            animPos = animPos + d
        }
        // sentido da viagem em curso (+1 horário / -1 anti-horário), p/ o efeito
        // "carrossel": o colorido sai por uma borda e entra pela borda oposta do próximo
        property int travelSign: 1
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
            // 1ª passada: os arcos de fundo (estado do workspace, sem o destaque)
            for (let i = 0; i < n; i++) {
                const t = tags[i]
                const a0 = (-90 - slot / 2 + i * slot + gap / 2) * Math.PI / 180
                const a1 = (-90 - slot / 2 + (i + 1) * slot - gap / 2) * Math.PI / 180
                g.beginPath()
                g.arc(cx, cy, ringR, a0, a1, false)
                g.lineWidth = arcW * wScale
                g.strokeStyle = t.is_urgent ? cUrgent
                              : t.client_count > 0 ? cOccupied : cEmpty
                g.globalAlpha = (t.is_urgent || t.client_count > 0) ? 1.0 : 0.65
                g.stroke()
            }
            // 2ª passada: o colorido do ativo. `f` é a fração do arco coberta por ele.
            // O arco que o destaque DEIXA encolhe ancorado na borda horária (a esquerda
            // retrai até sobrar a bolinha na direita — lineCap redondo com comprimento
            // ~zero); o arco em que ele ENTRA nasce como bolinha na borda anti-horária
            // (esquerda) e se estica p/ a direita até preencher. A direção da viagem só
            // decide qual arco está saindo/entrando e a ordem da varredura — indo p/
            // frente (1→2) o fluxo escorre rumo ao próximo; p/ trás, o espelho disso.
            for (let i = 0; i < n; i++) {
                let delta = (pos - i) % n                  // distância assinada do destaque a este arco
                if (delta > n / 2) delta -= n
                else if (delta < -n / 2) delta += n
                const f = Math.max(0, 1 - 2 * Math.abs(delta))
                if (f <= 0) continue
                const startDeg = -90 - slot / 2 + i * slot + gap / 2      // borda anti-horária do arco
                const endDeg = startDeg + (slot - gap)                    // borda horária
                const len = Math.max(0.02, (slot - gap) * f)              // piso ínfimo garante a bolinha
                // saindo (delta no sentido da viagem) -> encolhe grudado na borda
                // horária (direita); entrando -> cresce a partir da anti-horária (esquerda)
                const leaving = travelSign > 0 ? delta >= 0 : delta <= 0
                const a0 = (leaving ? endDeg - len : startDeg) * Math.PI / 180
                const a1 = (leaving ? endDeg : startDeg + len) * Math.PI / 180
                g.beginPath()
                g.arc(cx, cy, ringR, a0, a1, false)
                g.lineWidth = arcWActive * wScale
                g.strokeStyle = cActive
                g.globalAlpha = 1
                g.stroke()
            }
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
