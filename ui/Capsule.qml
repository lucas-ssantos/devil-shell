import QtQuick
import "root:/"   // Config (raiz)

// Cápsula retrátil no topo da tela: fica escondida (só a fatia `capsulePeek` aparece)
// e DESCE ao passar o mouse, mostrando ícone + texto. Conteúdo via propriedades.
Item {
    id: cap
    property string icon: ""
    property string label: ""
    property bool   dim: false        // conteúdo apagado (ex.: nada tocando)
    property bool   marquee: false    // true = rola o texto em vez de cortar com "..."
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
            // texto: elide simples, OU área fixa com o texto rolando (marquee) quando não cabe
            Item {
                id: labelArea
                anchors.verticalCenter: parent.verticalCenter
                visible: cap.label.length > 0
                readonly property real maxW: cap.width - 50
                width: cap.marquee ? maxW : Math.min(labelText.implicitWidth, maxW)
                height: labelText.implicitHeight
                clip: cap.marquee

                Text {
                    id: labelText
                    text: cap.label
                    color: Config.capsuleText
                    font.pixelSize: Config.capsuleTextSize
                    elide: cap.marquee ? Text.ElideNone : Text.ElideRight
                    width: cap.marquee ? undefined : parent.width
                }

                // rola só quando estendida, o texto não cabe, e o marquee está ligado
                SequentialAnimation {
                    running: cap.marquee && cap.shown && labelText.implicitWidth > labelArea.width
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) labelText.x = 0
                    PauseAnimation { duration: 900 }
                    NumberAnimation {
                        target: labelText; property: "x"
                        to: -(labelText.implicitWidth - labelArea.width + 6)
                        duration: Math.max(1400, (labelText.implicitWidth - labelArea.width) * 45)
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 900 }
                    NumberAnimation { target: labelText; property: "x"; to: 0; duration: 300; easing.type: Easing.InOutQuad }
                }
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
