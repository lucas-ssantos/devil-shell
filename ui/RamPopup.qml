import Quickshell
import QtQuick
import "root:/services"   // SensorsService
import "root:/"           // Config (raiz)

// Popup do botão de RAM (ClockCapsule, indicador de RAM): uso de RAM, Processamento
// (CPU) e VRAM da placa de vídeo. Emerge CENTRALIZADO com a cápsula (mesma cor, sem
// borda, cantos de cima retos) e "desenrola" de cima pra baixo (altura, não escala) —
// mesma linguagem visual do TempPopup/CalendarPopup, para parecer uma extensão da cápsula.
PopupWindow {
    id: root
    property var ctx        // janela-âncora (TopCapsules -> bar)
    property real px: 0     // centro-X/base da CÁPSULA (coord. de `ctx`)
    property real py: 0
    property bool revealed: false   // controla a animação de abrir/fechar (ver `card` abaixo)

    function openAt(x, y) {
        hideTimer.stop()   // reabrir cancela um fechamento pendente (senão o timer some com o popup)
        px = x; py = y
        SensorsService.refresh()
        visible = true
        revealed = true
    }
    // fecha ANIMADO: encolhe primeiro, e só esconde a janela de verdade quando a
    // animação termina (senão o popup some no frame seguinte sem tocar a animação —
    // mesmo truque do Tooltip.qml de referência do Quickshell: Timer segura o `visible`)
    function close() { revealed = false; hideTimer.restart() }
    function toggle(x, y) { if (visible) close(); else openAt(x, y) }

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

    readonly property var rows: [
        { label: "RAM", value: SensorsService.ramUsage },
        { label: "Processamento", value: SensorsService.cpuUsage },
        { label: "VRAM", value: SensorsService.vramUsage }
    ]

    implicitWidth: Config.tempPopupW
    implicitHeight: root.rows.length * Config.trayMenuRowH + 2 * Config.trayMenuPad
    color: "transparent"
    visible: false
    grabFocus: true   // clique fora do popup fecha sozinho (dispara onVisibleChanged acima)

    // "desenrola" a partir do topo: a altura visível cresce (0 -> cheia), revelando o
    // conteúdo (que fica em posição fixa) por baixo de um clip.
    Rectangle {
        id: card
        width: parent.width
        height: root.revealed ? root.implicitHeight : 0
        clip: true
        color: Config.capsuleBg
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Config.capsuleRadius
        bottomRightRadius: Config.capsuleRadius
        Behavior on height { NumberAnimation { duration: Config.capsuleAnim; easing.type: Easing.OutCubic } }

        Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Config.trayMenuPad
            spacing: 0

            Repeater {
                model: root.rows
                delegate: Item {
                    required property var modelData
                    width: parent.width
                    height: Config.trayMenuRowH
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Config.capsuleText
                        font.pixelSize: Config.trayMenuTextSize
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.value
                        color: Config.accent
                        font.pixelSize: Config.trayMenuTextSize
                        font.bold: true
                    }
                }
            }
        }
    }
}
