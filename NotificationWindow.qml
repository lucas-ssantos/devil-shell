import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

// Painel de notificações (toasts) no TOPO-CENTRO da tela focada. Lê as notificações
// ativas de NotificationService e mostra um card por notificação, com auto-dismiss.
// Clicar num card fecha (dismiss). A janela só existe quando há notificações.
PanelWindow {
    id: win
    property var mango   // serviço MangoLayout, p/ achar o monitor focado

    // mostra no monitor focado (fallback: o primeiro)
    screen: {
        const list = mango ? (mango.monitors ?? []) : []
        const a = list.find(m => m.active)
        if (a) {
            const s = Quickshell.screens.find(sc => sc.name === a.name)
            if (s) return s
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    WlrLayershell.layer: WlrLayer.Top
    color: "transparent"
    anchors { top: true }                 // ancorado só no topo -> centralizado na horizontal
    exclusiveZone: 0
    implicitWidth: Config.notifWidth
    implicitHeight: col.implicitHeight + Config.notifTopMargin
    visible: NotificationService.list.values.length > 0

    // só os cards recebem clique; a folga do topo é click-through
    mask: Region {
        x: 0; y: Config.notifTopMargin
        width: win.width; height: Math.max(0, win.height - Config.notifTopMargin)
    }

    Column {
        id: col
        anchors { top: parent.top; topMargin: Config.notifTopMargin; horizontalCenter: parent.horizontalCenter }
        spacing: Config.notifSpacing

        Repeater {
            model: NotificationService.list
            delegate: Rectangle {
                id: card
                required property var modelData
                width: Config.notifWidth
                implicitHeight: Math.max(iconImg.height, txt.implicitHeight) + 2 * Config.notifPad
                height: implicitHeight
                color: Config.notifBg
                radius: Config.notifRadius
                border.color: Config.notifBorder
                border.width: 1

                readonly property string iconSource: modelData.image !== "" ? modelData.image
                    : (modelData.appIcon !== "" ? Quickshell.iconPath(modelData.appIcon, true) : "")
                readonly property color accent: modelData.urgency === NotificationUrgency.Critical ? Config.notifCritical
                    : modelData.urgency === NotificationUrgency.Low ? Config.notifLow
                    : Config.notifNormal

                // faixa de urgência (esquerda)
                Rectangle {
                    width: 4; radius: 2
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 6 }
                    color: card.accent
                }

                Image {
                    id: iconImg
                    visible: card.iconSource !== ""
                    source: card.iconSource
                    width: visible ? Config.notifIconSize : 0
                    height: Config.notifIconSize
                    sourceSize.width: Config.notifIconSize
                    sourceSize.height: Config.notifIconSize
                    fillMode: Image.PreserveAspectFit
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                }

                Column {
                    id: txt
                    anchors {
                        left: iconImg.right; leftMargin: card.iconSource !== "" ? 10 : 16
                        right: parent.right; rightMargin: Config.notifPad
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: card.modelData.appName
                        color: Config.notifAppText
                        font.pixelSize: Config.notifAppSize
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: card.modelData.summary
                        color: Config.notifSummary
                        font.pixelSize: Config.notifSummarySize
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: card.modelData.body
                        color: Config.notifBody
                        font.pixelSize: Config.notifBodySize
                        wrapMode: Text.WordWrap
                        maximumLineCount: Config.notifBodyMaxLines
                        elide: Text.ElideRight
                    }
                }

                MouseArea { anchors.fill: parent; onClicked: card.modelData.dismiss() }

                // auto-dismiss (crítica permanece até o usuário fechar)
                Timer {
                    running: card.modelData.urgency !== NotificationUrgency.Critical
                    interval: Config.notifTimeout
                    onTriggered: card.modelData.expire()
                }

                // animação de entrada
                opacity: 0
                scale: 0.96
                transformOrigin: Item.Top
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: Config.notifAnim; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Config.notifAnim; easing.type: Easing.OutCubic } }
            }
        }
    }
}
