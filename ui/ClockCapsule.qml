import QtQuick
import Quickshell
import "root:/services"   // SensorsService
import "root:/"           // Config (raiz)

// Cápsula direita: [ícone + RAM] (botão de RAM, à esquerda — abre popup com RAM/CPU/VRAM),
// [ícone + data/hora] (botão do calendário, ao centro) e [ícone + CPU] (botão de
// temperatura, à direita — mostra o indicador de CPU, abre o popup com CPU/GPU/local). Os
// TRÊS popups ancoram no MESMO ponto (centro-X/base da cápsula inteira, via anchorPoint())
// e emergem centralizados com ela, como cantos góticos que se fundem à cápsula (fusão
// visual em GothicPopupCard.qml, usado pelos 3). Mesma largura e retração da Capsule de
// mídia (só `capsulePeek` aparece; desce no hover).
Item {
    id: cap
    property bool calendarOpen: false   // refletem *Popup.visible (não containsMouse: abrir um
    property bool tempOpen: false       // popup é uma nova surface Wayland e "trava" o hover do MouseArea)
    property bool ramOpen: false
    property real calendarProgress: 0   // 0..1 animados, espelham *Popup.progress: encolhem os
    property real tempProgress: 0       // cantos de baixo da cápsula EM SINCRONIA com QUALQUER
    property real ramProgress: 0        // popup abrindo (o que estiver aberto no momento)
    readonly property real popupProgress: Math.max(calendarProgress, tempProgress, ramProgress)
    signal calendarClicked(real px, real py)   // px/py: centro-X/base da CÁPSULA (coord. do pai) —
    signal tempClicked(real px, real py)       // TODOS os popups emergem centralizados com ela
    signal ramClicked(real px, real py)        // (mesmo ponto de ancoragem para os três)
    signal capsuleClicked()   // clique no corpo da cápsula (fora dos botões) -> fecha os popups

    width: Config.capsuleW   // mesma largura da cápsula de mídia
    height: Config.capsuleH
    // continua estendida (não retrai) enquanto o mouse está em cima OU algum popup está aberto
    readonly property bool shown: hoverMA.containsMouse || calendarOpen || tempOpen || ramOpen

    SystemClock { id: sysClock; precision: SystemClock.Seconds }
    readonly property string dateTimeText: Qt.formatDateTime(sysClock.date, Config.clockCapsuleFormat)

    // centro-X/base da cápsula (coord. de `cap`) — ponto de ancoragem comum aos 3 popups
    function anchorPoint() {
        const p = pill.mapToItem(cap, pill.width / 2, pill.height)
        return { x: cap.x + p.x, y: cap.y + p.y }
    }

    Rectangle {
        id: pill
        width: parent.width
        height: parent.height
        y: cap.shown ? 0 : -(height - Config.capsulePeek)
        Behavior on y { NumberAnimation { duration: Config.capsuleAnim; easing.type: Easing.OutCubic } }
        // some conforme QUALQUER popup abre (progress já vem animado de cada popup — sem
        // Behavior própria aqui, senão anima em cima de animação)
        bottomLeftRadius: Config.capsuleRadius * (1 - cap.popupProgress)
        bottomRightRadius: Config.capsuleRadius * (1 - cap.popupProgress)
        color: Config.capsuleBg

        // fundo da cápsula: clicar fora dos botões fecha os popups. Fica ATRÁS deles
        // (declarado primeiro) para não roubar o clique.
        MouseArea {
            id: bgMA
            anchors.fill: parent
            onClicked: cap.capsuleClicked()
        }

        // botão de RAM: ícone + uso de RAM (abre popup com RAM/Processamento/VRAM)
        Rectangle {
            id: ramBtn
            anchors.left: parent.left; anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            height: Config.capsuleH - 10
            width: ramRow.implicitWidth + 10
            radius: height / 2
            color: cap.ramOpen ? Config.trayMenuHover : "transparent"

            Row {
                id: ramRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Config.iconRam
                    font.family: Config.iconFont
                    font.pixelSize: Config.capsuleIconSize
                    color: Config.capsuleText
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SensorsService.ramUsage
                    color: Config.capsuleText
                    font.pixelSize: Config.capsuleTextSize
                    font.bold: true
                }
            }

            MouseArea {
                id: ramMA
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { const a = cap.anchorPoint(); cap.ramClicked(a.x, a.y) }
            }
        }

        // botão do calendário: ícone + data/hora juntos (centralizado na cápsula)
        Rectangle {
            id: calBtn
            anchors.centerIn: parent
            height: Config.capsuleH - 10
            width: calRow.implicitWidth + 10
            radius: height / 2
            color: cap.calendarOpen ? Config.trayMenuHover : "transparent"

            Row {
                id: calRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Config.iconCalendar
                    font.family: Config.iconFont
                    font.pixelSize: Config.capsuleIconSize
                    color: Config.capsuleText
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: cap.dateTimeText
                    color: Config.capsuleText
                    font.pixelSize: Config.capsuleTextSize
                    font.bold: true
                }
            }

            MouseArea {
                id: calMA
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { const a = cap.anchorPoint(); cap.calendarClicked(a.x, a.y) }
            }
        }

        // botão de temperatura: ícone + valor de CPU (abre popup com CPU/GPU/local)
        Rectangle {
            id: tempBtn
            anchors.right: parent.right; anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            height: Config.capsuleH - 10
            width: tempRow.implicitWidth + 10
            radius: height / 2
            color: cap.tempOpen ? Config.trayMenuHover : "transparent"

            Row {
                id: tempRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Config.iconWeather
                    font.family: Config.iconFont
                    font.pixelSize: Config.capsuleIconSize
                    color: Config.capsuleText
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SensorsService.cpuTemp
                    color: Config.capsuleText
                    font.pixelSize: Config.capsuleTextSize
                    font.bold: true
                }
            }

            MouseArea {
                id: tempMA
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { const a = cap.anchorPoint(); cap.tempClicked(a.x, a.y) }
            }
        }
    }

    // hover-only: NÃO aceita botão, então cliques passam direto p/ calBtn/tempBtn embaixo
    MouseArea {
        id: hoverMA
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
