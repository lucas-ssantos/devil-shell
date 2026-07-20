import Quickshell
import QtQuick
import "root:/"   // Config (raiz)

// Popup do botão de calendário (ClockCapsule): mês atual em grade (semanas × dias),
// com navegação ‹ › entre meses. Emerge ENCOSTADO e CENTRALIZADO com a cápsula (mesma
// cor, sem borda, cantos GÓTICOS no topo — filete curvo, mesmo espírito visual do
// GothicCorners que funde a bola na barra) e "desenrola" de cima pra baixo (altura, não
// escala) — para parecer uma extensão da cápsula, não uma janela solta.
PopupWindow {
    id: root
    property var ctx        // janela-âncora (TopCapsules -> bar)
    property real px: 0     // centro-X/base da cápsula (coord. de `ctx`)
    property real py: 0
    property var viewDate: new Date()   // dia 1 do mês mostrado
    property bool revealed: false   // controla a animação de abrir/fechar (ver `card` abaixo)
    // 0..1 animado (mesma duração/curva do resto), PÚBLICO: a ClockCapsule lê isso para
    // encolher os cantos arredondados dela EM SINCRONIA, como se as duas formas fossem
    // uma coisa só se conectando/desconectando junto com o popup.
    property real progress: revealed ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Config.capsuleAnim; easing.type: Easing.OutCubic } }

    function openAt(x, y) {
        hideTimer.stop()   // reabrir cancela um fechamento pendente (senão o timer some com o popup)
        px = x; py = y
        const n = new Date()
        viewDate = new Date(n.getFullYear(), n.getMonth(), 1)
        visible = true
        revealed = true
    }
    // fecha ANIMADO: encolhe primeiro, e só esconde a janela de verdade quando a
    // animação termina (senão o popup some no frame seguinte sem tocar a animação —
    // mesmo truque do Tooltip.qml de referência do Quickshell: Timer segura o `visible`)
    function close() { revealed = false; hideTimer.restart() }
    function toggle(x, y) { if (visible) close(); else openAt(x, y) }
    function prevMonth() { viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1) }
    function nextMonth() { viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1) }

    Timer { id: hideTimer; interval: Config.capsuleAnim; onTriggered: root.visible = false }

    // se o popup foi escondido por FORA do nosso close() (grabFocus: clique fora do
    // popup), intercepta: reabre a superfície na hora (imperceptível, mesmo frame) e
    // deixa o close() de verdade tocar a animação de saída antes de esconder.
    onVisibleChanged: if (!visible && revealed) { visible = true; close() }

    // centralizado com a cápsula, encostado embaixo dela sem vão (parece brotar dali)
    anchor.window: ctx
    anchor.rect.x: px - root.implicitWidth / 2
    anchor.rect.y: py
    anchor.rect.width: 1
    anchor.rect.height: 1

    readonly property real gridW: 7 * Config.calendarCellSize
    implicitWidth: gridW + 2 * Config.trayMenuPad
    implicitHeight: Config.trayMenuRowH + Config.calendarCellSize * 0.7 + 6 * Config.calendarCellSize
                    + 2 * Config.trayMenuPad + 8   // 8 = 2 espaçamentos da Column
    color: "transparent"
    visible: false
    grabFocus: true   // clique fora do popup fecha sozinho (dispara onVisibleChanged acima)

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

    // "desenrola" a partir do topo: a altura visível cresce (0 -> cheia), revelando o
    // conteúdo (que fica em posição fixa) por baixo de um clip — mesma linguagem visual
    // da própria cápsula "descendo" no hover, não um fade/scale de janela solta.
    Item {
        id: revealClip
        width: root.implicitWidth
        // segue `progress` direto (já animado por ele mesmo) -- sem Behavior própria,
        // senão a altura ficaria animando DUAS vezes (lag sobre lag)
        height: root.progress * root.implicitHeight
        clip: true

        // corpo do popup: cantos GÓTICOS no topo (filete curvo) ligando a largura da
        // cápsula (estreita) à largura do popup (mais larga) — em vez de um degrau reto,
        // "derrete" uma na outra, como a bola funde na barra em GothicCorners.qml.
        // Canvas de tamanho FIXO (a animação é só o clip do `revealClip` acima).
        Canvas {
            id: card
            width: root.implicitWidth
            height: root.implicitHeight
            antialiasing: true
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                const g = getContext("2d")
                g.reset()
                const w = width, h = height
                // canto gótico = curva OGEE (S: primeiro arco convexo, depois côncavo — a
                // mesma dupla curvatura de um arco/ogiva gótico), não um arredondamento
                // simples. Profundidade D = metade da diferença de largura popup↔cápsula,
                // dividida em dois arcos de raio D/2 cada (encaixam sem sobra: a curva
                // SEMPRE cabe certinha, não importa o quanto o popup seja mais largo).
                const D = Math.max(0, Math.min((w - Config.capsuleW) / 2, h / 2))
                const r = D / 2
                const rBot = Math.max(0, Math.min(Config.capsuleRadius, w / 2, h / 2))
                const leftC = w / 2 - Config.capsuleW / 2
                const rightC = w / 2 + Config.capsuleW / 2

                g.fillStyle = Config.capsuleBg
                g.beginPath()
                g.moveTo(leftC, 0)
                g.lineTo(rightC, 0)
                // ogee à direita: "derrete" da largura da cápsula p/ a largura do popup
                g.arcTo(rightC, D / 2, w, D / 2, r)
                g.arcTo(w, D / 2, w, D, r)
                g.lineTo(w, h - rBot)
                g.arcTo(w, h, w - rBot, h, rBot)
                g.lineTo(rBot, h)
                g.arcTo(0, h, 0, h - rBot, rBot)
                g.lineTo(0, D)
                // ogee à esquerda (espelhado)
                g.arcTo(0, D / 2, leftC, D / 2, r)
                g.arcTo(leftC, D / 2, leftC, 0, r)
                g.closePath()
                g.fill()
            }
        }

        Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
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
                        color: Config.capsuleText
                        font.pixelSize: Config.trayMenuTextSize + 4
                        font.bold: true
                    }
                    MouseArea { id: prevMA; anchors.fill: parent; hoverEnabled: true; onClicked: root.prevMonth() }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.monthNames[root.viewDate.getMonth()] + " " + root.viewDate.getFullYear()
                    color: Config.capsuleText
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
                        color: Config.capsuleText
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
                                color: modelData.isToday ? Config.capsuleBg
                                       : (modelData.inMonth ? Config.capsuleText : Config.trayMenuTextDisabled)
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
