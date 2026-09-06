import QtQuick
import "root:/"   // Config (raiz)

// Visualizador CAVA da barra Draco: FORMA DE ONDA estilo editor de áudio — barras finas
// de cantos redondos, ESPELHADAS no eixo horizontal (crescem p/ cima e p/ baixo do centro),
// com a COR variando pela AMPLITUDE (grave/baixo = frio; pico = quente). Diferente do rodapé
// (cava/CavaBars.qml, que é uma área suave preenchida de uma cor só).
//
// `levels` = níveis 0..1 do CavaService (64 barras). O espectro é espelhado (src + reverse)
// → simétrico esquerda/direita, com o grave nas PONTAS e o agudo no CENTRO (igual ao rodapé).
// `segment` fatia esse espectro p/ caber APENAS num vão da barra (não passa por trás dos
// widgets): "left" = 1ª metade (grave na ponta externa, agudo voltado ao centro), "right" =
// 2ª metade (espelho), "full" = tudo. Puramente visual — sem MouseArea, p/ o scroll seguir
// p/ o fundo da barra (troca de ws).
Item {
    id: viz
    property var levels: []
    property string segment: "full"   // "left" | "right" | "full"

    // não repinta invisível (modo devil); ao reaparecer, pinta 1x
    onLevelsChanged: if (visible) cv.requestPaint()
    onVisibleChanged: if (visible) cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        antialiasing: true

        // paradas do gradiente de amplitude (frio → quente), vindas do tema
        readonly property var stops: [
            { p: 0.00, c: Config.dracoCavaC0 },
            { p: 0.30, c: Config.dracoCavaC1 },
            { p: 0.55, c: Config.dracoCavaC2 },
            { p: 0.78, c: Config.dracoCavaC3 },
            { p: 1.00, c: Config.dracoCavaC4 }
        ]
        function mix(a, b, t) {
            return Qt.rgba(a.r + (b.r - a.r) * t,
                           a.g + (b.g - a.g) * t,
                           a.b + (b.b - a.b) * t, 1)
        }
        function colorFor(v) {
            const s = stops
            const x = Math.max(0, Math.min(1, v))
            for (let i = 1; i < s.length; i++) {
                if (x <= s[i].p) {
                    const t = (x - s[i - 1].p) / (s[i].p - s[i - 1].p)
                    return mix(s[i - 1].c, s[i].c, t)
                }
            }
            return s[s.length - 1].c
        }

        function roundedBar(g, x, y, w, h, r) {
            const rr = Math.max(0, Math.min(r, w / 2, h / 2))
            g.beginPath()
            g.moveTo(x + rr, y)
            g.arcTo(x + w, y, x + w, y + rr, rr)
            g.lineTo(x + w, y + h - rr)
            g.arcTo(x + w, y + h, x + w - rr, y + h, rr)
            g.lineTo(x + rr, y + h)
            g.arcTo(x, y + h, x, y + h - rr, rr)
            g.lineTo(x, y + rr)
            g.arcTo(x, y, x + rr, y, rr)
            g.closePath()
        }

        onPaint: {
            const g = getContext("2d")
            g.reset()
            const W = width, H = height
            const src = viz.levels
            const m = src ? src.length : 0
            if (W <= 0 || H <= 0 || m < 2) return

            // espelha: grave nas pontas, agudo no centro (igual ao rodapé); depois fatia
            // p/ o vão pedido (metade esquerda / direita), pondo o centro do espectro
            // encostado no chip central
            const full = src.concat(src.slice().reverse())
            const half = Math.floor(full.length / 2)
            const lv = viz.segment === "left"  ? full.slice(0, half)
                     : viz.segment === "right" ? full.slice(half)
                     : full
            const n = lv.length
            if (n < 2) return
            const slot = W / n
            const bw = Math.max(1, slot * Config.dracoCavaBarFrac)
            const cy = H / 2
            const maxH = H / 2 - 1
            const floor = Math.max(0.75, Config.dracoCavaFloor * maxH)
            const rad = bw / 2

            g.globalAlpha = Config.dracoCavaOpacity
            for (let i = 0; i < n; i++) {
                const v = Math.max(0, lv[i] ?? 0)
                const half = Math.max(floor, Math.min(maxH, v * maxH))
                const x = i * slot + (slot - bw) / 2
                g.fillStyle = colorFor(v)
                roundedBar(g, x, cy - half, bw, half * 2, rad)
                g.fill()
            }
        }
    }
}
