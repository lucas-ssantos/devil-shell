import QtQuick

// Submenu de LAYOUTS: lista curvada de retângulos com o nome de cada layout.
// Emergem da bola quando `ctx.layoutMode` é verdadeiro.
Repeater {
    id: lm
    property var ctx
    model: ctx ? ctx.layoutItems : []

    delegate: Rectangle {
        id: lopt
        required property var modelData
        required property int index
        readonly property bool lhovered: lm.ctx.layoutMode && lm.ctx.hoverIndex === index
        property real prog: lm.ctx.layoutMode ? 1 : 0    // não-readonly: o Behavior anima
        readonly property real fx: lm.ctx.layoutPillX(index)
        readonly property real fy: lm.ctx.layoutPillY(index)
        z: 2.6
        width: lm.ctx.layoutPillW
        height: lm.ctx.layoutRowH - 3
        radius: height / 2
        transformOrigin: Item.Center
        rotation: (fx - lm.ctx.ballCX) * Config.layoutTilt   // inclinação seguindo a curvatura
        // emergem da bola até a posição final
        x: lm.ctx.ballCX + (fx - lm.ctx.ballCX) * prog - width / 2
        y: lm.ctx.ballCY + (fy - lm.ctx.ballCY) * prog - height / 2
        opacity: prog
        visible: prog > 0.01
        color: lhovered ? Config.layoutPillHover : Config.layoutPill
        Behavior on prog { NumberAnimation { duration: Config.layoutAnim; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Config.layoutColorAnim } }

        Text {
            anchors.centerIn: parent
            text: lopt.modelData.label
            color: lopt.lhovered ? Config.layoutTextHover : Config.layoutText
            font.pixelSize: Config.layoutTextSize
            font.bold: lopt.lhovered
        }
    }
}
