import QtQuick
import "root:/"   // Config (raiz)

// Cápsula retrátil no topo da tela: fica escondida (só a fatia `capsulePeek` aparece)
// e DESCE ao passar o mouse, mostrando ícone + texto. Conteúdo via propriedades.
Item {
    id: cap
    property string icon: ""
    property string label: ""
    property bool   dim: false        // conteúdo apagado (ex.: nada tocando)
    signal clicked()

    width: Config.capsuleW
    height: Config.capsuleH
    readonly property bool shown: ma.containsMouse

    Rectangle {
        id: pill
        width: parent.width
        height: parent.height
        // retraída: empurrada p/ cima (só `peek` aparece); no hover desce até y=0
        y: cap.shown ? 0 : -(height - Config.capsulePeek)
        Behavior on y { NumberAnimation { duration: Config.capsuleAnim; easing.type: Easing.OutCubic } }
        bottomLeftRadius: Config.capsuleRadius
        bottomRightRadius: Config.capsuleRadius
        color: Config.capsuleBg

        Row {
            anchors.centerIn: parent
            spacing: 7
            opacity: cap.dim ? 0.5 : 1.0
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cap.icon
                font.family: Config.iconFont
                font.pixelSize: Config.capsuleIconSize
                color: Config.capsuleText
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: cap.label.length > 0
                text: cap.label
                color: Config.capsuleText
                font.pixelSize: Config.capsuleTextSize
                elide: Text.ElideRight
                width: Math.min(implicitWidth, cap.width - 50)
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: cap.clicked()
    }
}
