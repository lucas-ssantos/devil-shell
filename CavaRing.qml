import QtQuick

// CAVA estilo Cavasik (modo CÍRCULO): curva fechada suave ao redor da bola, raio
// modulado pelo espectro, preenchida (blob pulsante atrás da bola) + contorno fino.
Item {
    id: ring
    property var ctx

    readonly property var levels: ctx ? (ctx.levels ?? []) : []
    readonly property real cx: ctx ? ctx.ballCX : 0
    readonly property real cy: ctx ? ctx.ballCY : 0
    readonly property real r0: ctx ? ctx.ballRadius : 46
    readonly property real rMax: ctx ? ctx.cavaRadMax : 55
    readonly property real side: 2 * (r0 + rMax) + 8

    z: 2.5                                   // atrás da bola, à frente da barra/filetes
    x: cx - side / 2
    y: cy - side / 2
    width: side
    height: side

    onLevelsChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const g = getContext("2d")
            g.reset()
            const lv = ring.levels
            const n = lv ? lv.length : 0
            if (n < 3) return
            const ccx = width / 2, ccy = height / 2

            // pontos ao redor: raio = r0 + nível*rMax
            const pxs = [], pys = []
            for (let i = 0; i < n; i++) {
                const ang = i / n * 2 * Math.PI - Math.PI / 2
                const rr = ring.r0 + Math.max(0, lv[i] ?? 0) * ring.rMax
                pxs.push(ccx + rr * Math.cos(ang))
                pys.push(ccy + rr * Math.sin(ang))
            }

            // curva FECHADA suave (midpoint quad ao longo do laço)
            g.beginPath()
            g.moveTo((pxs[n - 1] + pxs[0]) / 2, (pys[n - 1] + pys[0]) / 2)
            for (let i = 0; i < n; i++) {
                const nxt = (i + 1) % n
                g.quadraticCurveTo(pxs[i], pys[i], (pxs[i] + pxs[nxt]) / 2, (pys[i] + pys[nxt]) / 2)
            }
            g.closePath()

            const a = Config.accent
            g.fillStyle = Qt.rgba(a.r, a.g, a.b, Config.cavaRingOpacity)
            g.fill()
            g.lineWidth = 1.5
            g.strokeStyle = Qt.rgba(a.r, a.g, a.b, Math.min(1, Config.cavaRingOpacity + 0.25))
            g.stroke()
        }
    }
}
