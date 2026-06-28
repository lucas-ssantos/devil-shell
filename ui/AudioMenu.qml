import QtQuick
import "root:/services"   // AudioService
import "root:/"           // Config (raiz)

// Submenu de áudio (config): 2 sliders — i=0 headphone (sink), i=1 microfone (source).
// Emergem da bola; o scroll sobre cada um (ajuste de volume) é tratado pela ShellWindow.
Repeater {
    id: am
    property var ctx
    model: ctx ? 2 : 0

    delegate: Rectangle {
        id: sld
        required property int index
        readonly property bool isSink: index === 0
        property real prog: am.ctx.audioMode ? 1 : 0    // não-readonly: o Behavior anima
        readonly property real cyTarget: am.ctx.audioPillY(index)
        readonly property real vol: isSink ? AudioService.sinkVolume : AudioService.sourceVolume
        readonly property real volMax: isSink ? Config.sinkVolMax : Config.sourceVolMax
        readonly property bool muted: isSink ? AudioService.sinkMuted : AudioService.sourceMuted
        readonly property bool hov: am.ctx.audioSliderHover === index

        z: 2.6
        width: Config.audioSliderW
        height: Config.audioSliderH
        radius: height / 2
        // emerge da bola até a posição final
        x: am.ctx.ballCX - width / 2
        y: am.ctx.ballCY + (cyTarget - am.ctx.ballCY) * prog - height / 2
        opacity: prog
        visible: prog > 0.01
        color: Config.audioSliderBg
        Behavior on prog { NumberAnimation { duration: Config.layoutAnim; easing.type: Easing.OutCubic } }

        // nível (preenchimento)
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: Math.max(parent.height, parent.width * Math.min(1, sld.vol / sld.volMax))
            radius: parent.radius
            color: sld.muted ? Config.audioMutedColor : Config.audioSliderFill
            opacity: sld.muted ? 0.5 : (sld.hov ? 1.0 : 0.85)
        }
        // ícone
        Text {
            anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
            text: sld.isSink ? (sld.muted ? Config.iconOutputMuted : Config.iconOutput)
                             : (sld.muted ? Config.iconInputMuted : Config.iconInput)
            color: Config.audioSliderText
            font.family: Config.iconFont
            font.pixelSize: Config.audioIconSize
            opacity: sld.muted ? 0.4 : 1.0
        }
        // porcentagem
        Text {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            text: Math.round(sld.vol * 100) + "%"
            color: Config.audioSliderText
            font.pixelSize: Config.layoutTextSize
            font.bold: true
        }
    }
}
