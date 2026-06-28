import QtQuick

// CAVA estilo Cavasik (modo CÍRCULO): espectro RADIAL com espetos ao redor da bola.
// Fica no FUNDO (dentro da CavaWindow), à frente do CavaBars e atrás de tudo o mais.
// Recebe a geometria da bola (cx/cy/r0/rMax) e os níveis; a bola (em outra janela, à
// frente) tampa o centro = o "furo" do círculo.
Item {
    id: ring

    property var levels: []
    property real cx: 0       // centro X da bola (nesta janela)
    property real cy: 0       // centro Y da bola (nesta janela)
    property real r0: 46      // raio da bola (base do espectro)
    property real rMax: 70    // comprimento máx dos picos
    readonly property real side: 2 * (r0 + rMax) + 8

    z: 1                      // à frente do CavaBars (z 0)
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
            const base = ring.levels
            const bn = base ? base.length : 0
            if (bn < 2) return
            const ccx = width / 2, ccy = height / 2
            const r0 = ring.r0, rMax = ring.rMax

            // espelha p/ ficar simétrico (grave no topo): [níveis..., níveis invertidos]
            const lv = base.concat(base.slice().reverse())
            const m = lv.length

            // polígono dos picos (espetos): raio = r0 + nível*rMax, fechado
            g.beginPath()
            for (let k = 0; k < m; k++) {
                const ang = -Math.PI / 2 + k / m * 2 * Math.PI
                const rr = r0 + Math.max(0, lv[k]) * rMax
                const x = ccx + rr * Math.cos(ang)
                const y = ccy + rr * Math.sin(ang)
                if (k === 0) g.moveTo(x, y); else g.lineTo(x, y)
            }
            g.closePath()

            // gradiente radial (a parte < r0 fica sob a bola)
            const c1 = Config.cavaColor1, c2 = Config.cavaColor2, c3 = Config.cavaColor3
            const op = Config.cavaRingOpacity
            const grad = g.createRadialGradient(ccx, ccy, r0, ccx, ccy, r0 + rMax)
            grad.addColorStop(0.0, Qt.rgba(c1.r, c1.g, c1.b, op))
            grad.addColorStop(0.5, Qt.rgba(c2.r, c2.g, c2.b, op))
            grad.addColorStop(1.0, Qt.rgba(c3.r, c3.g, c3.b, op))
            g.fillStyle = grad
            g.fill()
        }
    }
}
