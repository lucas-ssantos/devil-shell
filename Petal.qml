import QtQuick

// Uma pétala do menu radial (visual). Lê o estado do controlador `ctx`.
// A 1ª pétala (index 0) mostra a sigla do layout atual; as demais, o ícone do item.
Item {
    id: petal
    property var ctx
    required property int index
    required property var modelData

    readonly property real angleDeg: ctx.petalAngle(index)
    readonly property real angleRad: angleDeg * Math.PI / 180
    readonly property bool hovered: ctx.hoverIndex === index
    readonly property bool selected: ctx.selectedIndex === index
    readonly property bool vanished: ctx.selectedIndex !== -1 && !selected

    width: ctx.petalW
    height: ctx.petalH
    transformOrigin: Item.Center
    rotation: 90 - angleDeg
    z: 1

    property real dist: !ctx.open ? 0
        : (hovered || selected)   ? ctx.petalDist
        : (ctx.hoverIndex !== -1) ? ctx.petalTouch   // outra em hover -> recua até a bola
        : ctx.petalDist
    x: ctx.ballCX + dist * Math.cos(angleRad) - width / 2
    y: ctx.ballCY - dist * Math.sin(angleRad) - height / 2

    opacity: (ctx.open && !vanished && !ctx.layoutMode) ? 1.0 : 0.0

    Behavior on dist { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    // corpo da pétala (cresce no hover; base fica reta quando há hover ativo)
    Rectangle {
        anchors.fill: parent
        topLeftRadius: width / 2
        topRightRadius: width / 2
        bottomLeftRadius: (petal.ctx.hoverIndex !== -1) ? 0 : width / 2
        bottomRightRadius: (petal.ctx.hoverIndex !== -1) ? 0 : width / 2
        Behavior on bottomLeftRadius { NumberAnimation { duration: 150 } }
        Behavior on bottomRightRadius { NumberAnimation { duration: 150 } }
        transformOrigin: Item.Center
        scale: (petal.hovered || petal.selected) ? 1.2
             : (petal.ctx.hoverIndex !== -1)     ? petal.ctx.petalShrink
             : 1.0
        color: petal.hovered ? "#f38ba8" : "#eba0ac"
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

        // cantos góticos da base (emergem só na pétala em hover)
        Canvas {
            id: pflare
            width: parent.width + 2 * petal.ctx.petalFlare
            height: petal.ctx.petalFlare + 2
            x: -petal.ctx.petalFlare
            y: parent.height - 1
            property real amt: (petal.hovered && petal.ctx.open) ? 1 : 0
            property color col: petal.hovered ? "#f38ba8" : "#eba0ac"
            Behavior on amt { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
            onAmtChanged: requestPaint()
            onColChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (amt <= 0.01) return
                const f = petal.ctx.petalFlare * amt
                const W = parent.width
                const xL = petal.ctx.petalFlare
                const xR = petal.ctx.petalFlare + W
                ctx.fillStyle = col
                // canto direito (côncavo)
                ctx.beginPath()
                ctx.moveTo(xR, f); ctx.lineTo(xR + f, f); ctx.lineTo(xR + f, 0)
                ctx.arc(xR, 0, f, 0, Math.PI / 2, false)
                ctx.closePath(); ctx.fill()
                // canto esquerdo (espelhado)
                ctx.beginPath()
                ctx.moveTo(xL, f); ctx.lineTo(xL - f, f); ctx.lineTo(xL - f, 0)
                ctx.arc(xL, 0, f, Math.PI, Math.PI / 2, true)
                ctx.closePath(); ctx.fill()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        rotation: -petal.rotation
        text: petal.index === 0 ? petal.ctx.currentLayoutSymbol : (petal.modelData.icon ?? "")
        font.pixelSize: 13
        font.bold: petal.index === 0
        color: "#1e1e2e"
    }
}
