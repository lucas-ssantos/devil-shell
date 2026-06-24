import QtQuick

// Anel radial do CAVA: espetos irradiando da borda da bola (atrás dela).
Repeater {
    id: ring
    property var ctx
    model: ctx ? (ctx.levels ?? []).length : 0

    delegate: Rectangle {
        required property int index
        readonly property int n: (ring.ctx.levels ?? []).length
        readonly property real ang: index / Math.max(1, n) * 2 * Math.PI - Math.PI / 2
        readonly property real v: (ring.ctx.levels ?? [])[index] ?? 0
        z: 2.5                                            // acima da barra/filetes, atrás da bola
        width: 3
        radius: 1.5
        height: Math.max(0, v) * ring.ctx.cavaRadMax
        x: ring.ctx.ballCX + ring.ctx.ballRadius * Math.cos(ang) - width / 2
        y: ring.ctx.ballCY + ring.ctx.ballRadius * Math.sin(ang)
        transformOrigin: Item.Top
        rotation: 90 - ang * 180 / Math.PI                // aponta radialmente p/ fora
        color: Config.accent
        opacity: Config.cavaRingOpacity
    }
}
