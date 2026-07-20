import QtQuick
import Quickshell
import "root:/services"   // SensorsService
import "root:/"           // Config (raiz)

// Cápsula direita: [ícone + data/hora] (botão do calendário) e [ícone + CPU] (botão de
// temperatura — mostra o indicador de CPU, abre o popup com CPU/GPU/local). Mesma
// largura e retração da Capsule de mídia (só `capsulePeek` aparece; desce no hover).
Item {
    id: cap
    property bool calendarOpen: false   // refletem *Popup.visible (não containsMouse: abrir um
    property bool tempOpen: false       // popup é uma nova surface Wayland e "trava" o hover do MouseArea)
    property real calendarProgress: 0   // 0..1 animado, espelha CalendarPopup.progress: encolhe os
                                         // cantos de baixo da cápsula EM SINCRONIA com o popup abrindo
    signal calendarClicked(real px, real py)   // px/py: centro-X/base da CÁPSULA (coord. do pai) —
                                                // o calendário emerge centralizado com a cápsula
    signal tempClicked(real px, real py)       // px/py: canto inferior-DIREITO do tempBtn — emerge
                                                // encostado ali (à direita, igual antes)
    signal capsuleClicked()   // clique no corpo da cápsula (fora dos botões) -> fecha os popups

    width: Config.capsuleW   // mesma largura da cápsula de mídia
    height: Config.capsuleH
    // continua estendida (não retrai) enquanto o mouse está em cima OU algum popup está aberto
    readonly property bool shown: hoverMA.containsMouse || calendarOpen || tempOpen

    SystemClock { id: sysClock; precision: SystemClock.Seconds }
    readonly property string dateTimeText: Qt.formatDateTime(sysClock.date, Config.clockCapsuleFormat)

    Rectangle {
        id: pill
        width: parent.width
        height: parent.height
        y: cap.shown ? 0 : -(height - Config.capsulePeek)
        Behavior on y { NumberAnimation { duration: Config.capsuleAnim; easing.type: Easing.OutCubic } }
        // some conforme o calendário abre (progress já vem animado do popup — sem
        // Behavior própria aqui, senão anima em cima de animação)
        bottomLeftRadius: Config.capsuleRadius * (1 - cap.calendarProgress)
        bottomRightRadius: Config.capsuleRadius * (1 - cap.calendarProgress)
        color: Config.capsuleBg

        // fundo da cápsula: clicar fora dos botões fecha os popups. Fica ATRÁS deles
        // (declarado primeiro) para não roubar o clique.
        MouseArea {
            id: bgMA
            anchors.fill: parent
            onClicked: cap.capsuleClicked()
        }

        // botão do calendário: ícone + data/hora juntos
        Rectangle {
            id: calBtn
            anchors.left: parent.left; anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
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
                onClicked: {
                    // centro-X/base da CÁPSULA inteira (não do botão) -> popup centralizado com ela
                    const p = pill.mapToItem(cap, pill.width / 2, pill.height)
                    cap.calendarClicked(cap.x + p.x, cap.y + p.y)
                }
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
                    text: Config.iconCpu
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
                onClicked: {
                    const p = tempBtn.mapToItem(cap, tempBtn.width, tempBtn.height)   // canto inferior-direito
                    cap.tempClicked(cap.x + p.x, cap.y + p.y)
                }
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
