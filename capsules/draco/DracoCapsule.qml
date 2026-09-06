import QtQuick
import "root:/"   // Config (raiz)

// Widget "chapado" da barra Draco: ícone (glifo Nerd Font e/ou imagem) + texto, com um 2º
// par ícone+texto opcional (ex.: RAM + CPU num widget só). Não tem fundo próprio — vive
// dentro de um chip da DracoBar — e só ganha um fundo discreto sob o cursor ou com o popup
// dele aberto (`active`). Sinais de clique esquerdo/direito/scroll; a DracoBar decide o
// que cada um faz.
Rectangle {
    id: cap
    property string icon: ""            // glifo (Config.iconFont)
    property string image: ""           // OU imagem (ex.: ícone do app) — antes do texto
    property string label: ""
    property string icon2: ""           // 2º par (opcional)
    property string label2: ""
    property color  iconColor: Config.dracoText
    property color  textColor: Config.dracoText
    property real   iconOpacity: 1.0
    property bool   active: false       // destaque fixo (ex.: popup aberto)
    property bool   wheelEnabled: false // consome o scroll (senão passa p/ a barra: troca de workspace)
    property real   labelMaxW: 0        // > 0 = corta o texto com "…" nessa largura
    signal clicked()
    signal rightClicked()
    signal wheel(int dir)               // +1 = scroll p/ cima, -1 = p/ baixo

    readonly property bool hovered: ma.containsMouse

    implicitWidth: row.implicitWidth + 2 * Config.dracoCapsulePad
    implicitHeight: Config.dracoCapsuleH
    radius: Math.max(0, Config.dracoChipRadius - 2)
    // fundo só no hover/ativo; o estado "transparente" mantém o RGB do hover p/ a animação
    // ser só de alfa (sem passar por um tom escuro no meio do caminho)
    color: (active || hovered) ? Config.dracoCapsuleHover
         : Qt.rgba(Config.dracoCapsuleHover.r, Config.dracoCapsuleHover.g, Config.dracoCapsuleHover.b, 0)
    Behavior on color { ColorAnimation { duration: Config.dracoAnim } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: cap.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: cap.icon
            font.family: Config.iconFont
            font.pixelSize: Config.dracoIconSize
            color: cap.iconColor
            opacity: cap.iconOpacity
            Behavior on color { ColorAnimation { duration: Config.dracoAnim } }
        }
        // imagem (ícone do app): só entra na linha quando carregou de fato
        Image {
            visible: cap.image !== "" && status === Image.Ready
            anchors.verticalCenter: parent.verticalCenter
            source: cap.image
            sourceSize.width: Config.dracoIconSize + 2
            sourceSize.height: Config.dracoIconSize + 2
            width: Config.dracoIconSize + 2
            height: Config.dracoIconSize + 2
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Text {
            visible: cap.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: cap.label
            color: cap.textColor
            font.pixelSize: Config.dracoTextSize
            font.bold: true
            elide: cap.labelMaxW > 0 ? Text.ElideRight : Text.ElideNone
            width: cap.labelMaxW > 0 ? Math.min(implicitWidth, cap.labelMaxW) : implicitWidth
        }

        // 2º par (um pouco mais afastado, p/ ler como dois indicadores)
        Item { visible: cap.icon2 !== "" || cap.label2 !== ""; width: 4; height: 1 }
        Text {
            visible: cap.icon2 !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: cap.icon2
            font.family: Config.iconFont
            font.pixelSize: Config.dracoIconSize
            color: cap.iconColor
            opacity: cap.iconOpacity
        }
        Text {
            visible: cap.label2 !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: cap.label2
            color: cap.textColor
            font.pixelSize: Config.dracoTextSize
            font.bold: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => { if (mouse.button === Qt.RightButton) cap.rightClicked(); else cap.clicked() }
        // sem wheelEnabled o evento segue p/ baixo (fundo da barra = troca de workspace)
        onWheel: (w) => {
            if (!cap.wheelEnabled) { w.accepted = false; return }
            cap.wheel(w.angleDelta.y > 0 ? 1 : -1)
        }
    }
}
