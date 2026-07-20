import Quickshell
import QtQuick
import "root:/"   // Config (raiz)

// Popup-apêndice do botão de calendário (ClockCapsule): mês atual em grade (semanas ×
// dias), com navegação ‹ › entre meses. Abre ABAIXO do botão (a cápsula fica no topo
// da tela). Mesmo estilo visual do TrayMenu/AudioDevices (cores/raio reaproveitados).
PopupWindow {
    id: root
    property var ctx        // janela-âncora (TopCapsules -> bar)
    property real px: 0
    property real py: 0
    property var viewDate: new Date()   // dia 1 do mês mostrado

    function openAt(x, y) {
        px = x; py = y
        const n = new Date()
        viewDate = new Date(n.getFullYear(), n.getMonth(), 1)
        visible = true
    }
    function close() { visible = false }
    function toggle(x, y) { if (visible) close(); else openAt(x, y) }
    function prevMonth() { viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1) }
    function nextMonth() { viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1) }

    // abre ABAIXO do clique, centrado (a cápsula fica no topo da tela)
    anchor.window: ctx
    anchor.rect.x: px - root.implicitWidth / 2
    anchor.rect.y: py + Config.trayMenuGap
    anchor.rect.width: 1
    anchor.rect.height: 1

    readonly property real gridW: 7 * Config.calendarCellSize
    implicitWidth: gridW + 2 * Config.trayMenuPad
    implicitHeight: Config.trayMenuRowH + Config.calendarCellSize * 0.7 + 6 * Config.calendarCellSize
                    + 2 * Config.trayMenuPad + 8   // 8 = 2 espaçamentos da Column
    color: "transparent"
    visible: false

    readonly property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
                                        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    readonly property var weekDays: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
    readonly property var today: new Date()

    // 42 células (6 semanas): dias do mês anterior/seguinte entram apagados p/ a grade ficar cheia
    readonly property var cells: {
        const year = root.viewDate.getFullYear(), month = root.viewDate.getMonth()
        const startOffset = new Date(year, month, 1).getDay()          // 0 = domingo
        const lastDay = new Date(year, month + 1, 0).getDate()
        const prevLastDay = new Date(year, month, 0).getDate()
        const out = []
        for (let i = 0; i < startOffset; i++)
            out.push({ day: prevLastDay - startOffset + 1 + i, inMonth: false, isToday: false })
        for (let d = 1; d <= lastDay; d++)
            out.push({ day: d, inMonth: true,
                       isToday: d === root.today.getDate() && month === root.today.getMonth()
                                && year === root.today.getFullYear() })
        let trail = 1
        while (out.length < 42) { out.push({ day: trail, inMonth: false, isToday: false }); trail++ }
        return out
    }

    Rectangle {
        anchors.fill: parent
        color: Config.trayMenuBg
        radius: Config.trayMenuRadius
        border.color: Config.trayMenuBorder
        border.width: 1
        // animação de entrada: cresce a partir do topo (o popup abre pra baixo)
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.9
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Config.trayMenuAnim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Config.trayMenuAnim; easing.type: Easing.OutCubic } }

        Column {
            anchors.fill: parent
            anchors.margins: Config.trayMenuPad
            spacing: 4

            // cabeçalho: ‹ Mês Ano ›
            Item {
                width: parent.width
                height: Config.trayMenuRowH

                Rectangle {
                    id: prevBtn
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: Config.trayMenuRowH; height: Config.trayMenuRowH
                    radius: Config.trayMenuRowRadius
                    color: prevMA.containsMouse ? Config.trayMenuHover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize + 4
                        font.bold: true
                    }
                    MouseArea { id: prevMA; anchors.fill: parent; hoverEnabled: true; onClicked: root.prevMonth() }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.monthNames[root.viewDate.getMonth()] + " " + root.viewDate.getFullYear()
                    color: Config.trayMenuText
                    font.pixelSize: Config.trayMenuTextSize
                    font.bold: true
                }
                Rectangle {
                    id: nextBtn
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: Config.trayMenuRowH; height: Config.trayMenuRowH
                    radius: Config.trayMenuRowRadius
                    color: nextMA.containsMouse ? Config.trayMenuHover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize + 4
                        font.bold: true
                    }
                    MouseArea { id: nextMA; anchors.fill: parent; hoverEnabled: true; onClicked: root.nextMonth() }
                }
            }

            // dias da semana
            Grid {
                columns: 7
                Repeater {
                    model: root.weekDays
                    delegate: Text {
                        required property string modelData
                        width: Config.calendarCellSize
                        height: Config.calendarCellSize * 0.7
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: Config.trayMenuTextDisabled
                        font.pixelSize: Config.trayMenuTextSize - 2
                        font.bold: true
                    }
                }
            }

            // grade de dias (6 semanas × 7 dias)
            Grid {
                columns: 7
                Repeater {
                    model: root.cells
                    delegate: Item {
                        required property var modelData
                        width: Config.calendarCellSize
                        height: Config.calendarCellSize
                        Rectangle {
                            anchors.centerIn: parent
                            width: Config.calendarCellSize - 6
                            height: Config.calendarCellSize - 6
                            radius: width / 2
                            color: modelData.isToday ? Config.accent : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.isToday ? Config.trayMenuBg
                                       : (modelData.inMonth ? Config.trayMenuText : Config.trayMenuTextDisabled)
                                font.pixelSize: Config.trayMenuTextSize
                                font.bold: modelData.isToday
                            }
                        }
                    }
                }
            }
        }
    }
}
