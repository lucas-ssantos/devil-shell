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
    // no sentido horário a partir do topo — o hit-test dotAt do controlador usa o mesmo mapa)
    Canvas {
        id: wsRing
        anchors.fill: parent
        antialiasing: true
        property var tags: ball.ctx.tags
        property real ringR: ball.ctx.dotRingR
        property real gapDeg: Config.dotArcGapDeg
        property real arcW: Config.dotArcW
        property real arcWActive: Config.dotArcActiveW
        property color cActive: Config.dotActive
        property color cUrgent: Config.dotUrgent
        property color cOccupied: Config.dotOccupied
        property color cEmpty: Config.dotEmpty
        onTagsChanged: requestPaint()
        onRingRChanged: requestPaint()
        onGapDegChanged: requestPaint()
        onArcWChanged: requestPaint()
        onArcWActiveChanged: requestPaint()
        onCActiveChanged: requestPaint()
        onCUrgentChanged: requestPaint()
        onCOccupiedChanged: requestPaint()
        onCEmptyChanged: requestPaint()
        onWidthChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const g = getContext("2d")
            g.reset()
            const n = (tags ?? []).length
            if (n === 0) return
            const cx = width / 2, cy = height / 2
            const slot = 360 / n
            const gap = Math.min(gapDeg, slot * 0.5)   // vão nunca engole o arco
            g.lineCap = "round"
            for (let i = 0; i < n; i++) {
                const t = tags[i]
                const a0 = (-90 - slot / 2 + i * slot + gap / 2) * Math.PI / 180
                const a1 = (-90 - slot / 2 + (i + 1) * slot - gap / 2) * Math.PI / 180
                g.beginPath()
                g.arc(cx, cy, ringR, a0, a1, false)
                g.lineWidth = t.is_active ? arcWActive : arcW
                g.strokeStyle = t.is_active ? cActive
                              : t.is_urgent ? cUrgent
                              : t.client_count > 0 ? cOccupied : cEmpty
                g.globalAlpha = (t.is_active || t.is_urgent || t.client_count > 0) ? 1.0 : 0.65
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
