import QtQuick
import Quickshell
import "root:/"   // Config (raiz)

// Cápsula direita: hora + 2 botões (calendário, temperatura) que abrem popups em
// apêndice. Mesma retração da Capsule (só `capsulePeek` aparece; desce no hover), mas
// com conteúdo próprio — não dá pra reusar Capsule.qml por causa dos botões clicáveis.
Item {
    id: cap
    property bool calendarOpen: false   // reflete o popup correspondente (não containsMouse: abrir o
    property bool tempOpen: false       // popup é uma nova surface Wayland e "trava" o hover do MouseArea)
    signal calendarClicked(real px, real py)   // px/py: ponto de ancoragem do popup (coord. do pai)
    signal tempClicked(real px, real py)

    width: Config.capsuleW
    height: Config.capsuleH
    readonly property bool shown: hoverMA.containsMouse

    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    readonly property string timeText: Qt.formatDateTime(sysClock.date, Config.timeFormat)

    Rectangle {
        id: pill
        width: parent.width
        height: parent.height
        y: cap.shown ? 0 : -(height - Config.capsulePeek)
        Behavior on y { NumberAnimation { duration: Config.capsuleAnim; easing.type: Easing.OutCubic } }
        bottomLeftRadius: Config.capsuleRadius
        bottomRightRadius: Config.capsuleRadius
        color: Config.capsuleBg

        Row {
            anchors.centerIn: parent
            spacing: 9

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: cap.timeText
                color: Config.capsuleText
                font.pixelSize: Config.capsuleTextSize
                font.bold: true
            }

            Rectangle {
                id: calBtn
                anchors.verticalCenter: parent.verticalCenter
                width: Config.capsuleBtnSize; height: Config.capsuleBtnSize
                radius: width / 2
                color: cap.calendarOpen ? Config.trayMenuHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: Config.iconCalendar
                    font.family: Config.iconFont
                    font.pixelSize: Config.capsuleIconSize
                    color: Config.capsuleText
                }
                MouseArea {
                    id: calMA
                    anchors.fill: parent
                    onClicked: {
                        const p = calBtn.mapToItem(cap, calBtn.width / 2, calBtn.height)
                        cap.calendarClicked(cap.x + p.x, cap.y + p.y)
                    }
                }
            }

            Rectangle {
                id: tempBtn
                anchors.verticalCenter: parent.verticalCenter
                width: Config.capsuleBtnSize; height: Config.capsuleBtnSize
                radius: width / 2
                color: cap.tempOpen ? Config.trayMenuHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: Config.iconWeather
                    font.family: Config.iconFont
                    font.pixelSize: Config.capsuleIconSize
                    color: Config.capsuleText
                }
                MouseArea {
                    id: tempMA
                    anchors.fill: parent
                    onClicked: {
                        const p = tempBtn.mapToItem(cap, tempBtn.width / 2, tempBtn.height)
                        cap.tempClicked(cap.x + p.x, cap.y + p.y)
                    }
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
