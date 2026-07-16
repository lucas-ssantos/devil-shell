import QtQuick
import "root:/"   // Config (raiz)

// Espectro do CAVA estilo Cavasik: ÁREA SUAVE preenchida (curva, não barras),
// subindo da base, com gradiente da cor das ondas (topo) ao transparente (base).
// Cor vem do tema "Infernal Rose" (Config.cavaWave), separado do acento do shell.
Item {
    id: bars
    anchors.fill: parent

    property var levels: []
    property real ballCX: width / 2
    property real ballRadius: 46
    property real maxH: 180

    onLevelsChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const g = getContext("2d")
            g.reset()
            const src = bars.levels
            const m = src ? src.length : 0
            if (m < 2) return
            // Espelha o espectro: graves nas BORDAS do monitor, agudos no CENTRO
            // (esquerda->centro sobe em frequência; centro->direita desce de volta).
            const lv = src.concat(src.slice().reverse())
            const n = lv.length
            const W = width, H = height
            const step = W / (n - 1)
            function px(i) { return i * step }
            function py(i) { return H - Math.max(0, lv[i] ?? 0) * bars.maxH }

            // contorno: base-esq -> primeiro ponto -> curva suave (midpoint quad) -> base-dir
            g.beginPath()
            g.moveTo(0, H)
            g.lineTo(px(0), py(0))
            for (let i = 1; i < n; i++) {
                const xc = (px(i - 1) + px(i)) / 2
                const yc = (py(i - 1) + py(i)) / 2
                g.quadraticCurveTo(px(i - 1), py(i - 1), xc, yc)
            }
            g.lineTo(px(n - 1), py(n - 1))
            g.lineTo(W, H)
            g.closePath()

            const a = Config.cavaWave
            const grad = g.createLinearGradient(0, H - bars.maxH, 0, H)
            grad.addColorStop(0, Qt.rgba(a.r, a.g, a.b, Config.cavaBarsOpacity))
            grad.addColorStop(1, Qt.rgba(a.r, a.g, a.b, 0))
            g.fillStyle = grad
            g.fill()
        }
    }
}
