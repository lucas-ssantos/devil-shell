import QtQuick

// Cantos góticos: filetes côncavos ligando a bola à barra de fundo (mesma cor).
// `ctx` = controlador (ShellWindow); `g` = contexto 2D do Canvas.
Canvas {
    id: gothic
    property var ctx
    z: 2
    anchors.fill: parent
    antialiasing: true

    property real cy: ctx ? ctx.ballCY : 0     // repinta enquanto a bola sobe/desce
    onCyChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    // arco menor (determinístico) de P1 a P2 em torno de C
    function arcMinor(g, C, P1, P2) {
        const r = Math.hypot(P1.x - C.x, P1.y - C.y)
        const a1 = Math.atan2(P1.y - C.y, P1.x - C.x)
        const a2 = Math.atan2(P2.y - C.y, P2.x - C.x)
        let d = a2 - a1
        while (d <= -Math.PI) d += 2 * Math.PI
        while (d >   Math.PI) d -= 2 * Math.PI
        g.arc(C.x, C.y, r, a1, a2, d < 0)
    }
    // adiciona o subpath de um filete (s = +1 direito, -1 esquerdo)
    function addLobe(g, s) {
        const cx = gothic.ctx.ballCX, cyc = gothic.ctx.ballCY, R = gothic.ctx.ballRadius
        const baseY = height, f = gothic.ctx.gothicR
        const dyc = baseY - cyc
        if (Math.abs(dyc) > R) return            // círculo não cruza a borda
        const xc = Math.sqrt(R * R - dyc * dyc)  // cruzamento círculo × borda
        const vy = (baseY - f) - cyc
        if ((R + f) <= Math.abs(vy)) return
        const xf = Math.sqrt((R + f) * (R + f) - vy * vy)
        const k = R / (R + f)
        const P  = { x: cx + s * xc,     y: baseY }       // cruzamento
        const BR = { x: cx + s * xf,     y: baseY }       // base do filete
        const F  = { x: cx + s * xf,     y: baseY - f }   // centro do filete
        const T  = { x: cx + s * k * xf, y: cyc + k * vy } // tangente no círculo
        const C  = { x: cx, y: cyc }
        g.moveTo(P.x, P.y)
        g.lineTo(BR.x, BR.y)
        arcMinor(g, F, BR, T)   // filete côncavo (borda → círculo)
        arcMinor(g, C, T, P)    // de volta pelo círculo até o cruzamento
        g.closePath()
    }
    onPaint: {
        const g = getContext("2d")
        g.reset()
        g.fillStyle = "#11111b"
        g.beginPath()
        addLobe(g, 1)
        addLobe(g, -1)
        g.fill()
    }
}
