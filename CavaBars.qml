import QtQuick

// Barras lineares do CAVA: sobem da barra de fundo e somem na faixa central da bola.
Item {
    id: bars
    anchors.fill: parent

    property var levels: []
    property real ballCX: width / 2
    property real ballRadius: 46
    property real maxH: 180

    Repeater {
        model: bars.levels.length
        delegate: Rectangle {
            required property int index
            readonly property real slot: bars.width / Math.max(1, bars.levels.length)
            readonly property real bx: slot * (index + 0.5)
            readonly property real v: bars.levels[index] ?? 0
            width: Math.max(2, slot * Config.cavaBarFactor)
            x: bx - width / 2
            height: Math.max(0, v) * bars.maxH
            y: bars.height - height
            topLeftRadius: width / 2
            topRightRadius: width / 2
            color: Config.accent
            opacity: Config.cavaBarsOpacity
            visible: Math.abs(bx - bars.ballCX) > bars.ballRadius + 10
        }
    }
}
