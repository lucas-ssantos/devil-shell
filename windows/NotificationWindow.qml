import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import "root:/services"   // NotificationService, NiriService (via property)
import "root:/"           // Config (raiz)

// Painel de notificações (toasts) no TOPO-CENTRO da tela focada. Lê as notificações
// ativas de NotificationService e mostra um card por notificação, com auto-dismiss.
// Clicar num card fecha (dismiss) e foca a janela do app de origem (ex.: notificação
// do Discord -> foca o vesktop), casando appName/desktopEntry com app_id/título via
// `niri msg --json windows` (mesmo padrão do clique na bandeja em ShellWindow.qml).
// A janela só existe quando há notificações.
PanelWindow {
    id: win
    property var niri   // serviço NiriService, p/ achar o monitor focado

    // mostra no monitor focado (fallback: o primeiro)
    screen: {
        const list = niri ? (niri.monitors ?? []) : []
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

    // ── Foco da janela do app ao clicar na notificação (ex.: Discord -> vesktop) ──
    // Mesmo padrão do foco pela bandeja em ShellWindow.qml: casa appName/desktopEntry
    // da notificação com app_id/título via `niri msg --json windows`, e foca com
    // `focus-window --id` (foca qualquer janela incondicionalmente, mesmo noutro monitor).
    property var pendingFocusNotif: null
    function focusNotifApp(n) {
        pendingFocusNotif = n
        notifClientsProc.exec(["niri", "msg", "--json", "windows"])
    }
    function matchNotifClient(clients, n) {
        function norm(s) { return (s || "").toString().toLowerCase().replace(/\.desktop$/, "") }
        const fields = [norm(n.desktopEntry), norm(n.appName)].filter(s => s.length > 0)
        for (let i = 0; i < clients.length; i++) {           // 1) por app_id
            const a = norm(clients[i].app_id)
            if (!a) continue
            for (let j = 0; j < fields.length; j++)
                if (a.indexOf(fields[j]) >= 0 || fields[j].indexOf(a) >= 0) return clients[i]
        }
        for (let i = 0; i < clients.length; i++) {           // 2) fallback por título
            const t = norm(clients[i].title)
            for (let j = 0; j < fields.length; j++)
                if (fields[j].length >= 4 && t.indexOf(fields[j]) >= 0) return clients[i]
        }
        return null
    }
    Process { id: notifFocusProc }
    Process {
        id: notifClientsProc
        stdout: SplitParser {
            onRead: line => {
                const n = win.pendingFocusNotif
                win.pendingFocusNotif = null
                if (!n) return
                let clients
                try { clients = JSON.parse(line) } catch (e) { return }
                const c = win.matchNotifClient(clients ?? [], n)
                if (c) notifFocusProc.exec(["niri", "msg", "action", "focus-window", "--id", "" + c.id])
            }
        }
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

                property bool appeared: false
                property bool hovering: false
                property bool closing: false
                property bool closeByUser: false   // true = clique do usuário (dismiss); false = timeout (expire)

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: card.hovering = true
                    onExited: card.hovering = false
                    onClicked: { win.focusNotifApp(card.modelData); card.closeByUser = true; card.closing = true }
                }

                // auto-dismiss (pausado com o mouse em cima; crítica só fecha por clique)
                Timer {
                    running: !card.hovering && !card.closing && card.modelData.urgency !== NotificationUrgency.Critical
                    interval: Config.notifTimeout
                    onTriggered: { card.closeByUser = false; card.closing = true }
                }

                // dispara a remoção de verdade só depois da animação de saída terminar
                Timer {
                    id: closeAnimTimer
                    interval: Config.notifAnim
                    onTriggered: card.closeByUser ? card.modelData.dismiss() : card.modelData.expire()
                }
                // animação de entrada/saída: desliza de fora da tela (por cima) + fade
                readonly property real hiddenOffset: -(height + Config.notifTopMargin + 24)
                property real slideY: hiddenOffset
                opacity: appeared && !closing ? 1 : 0
                transform: Translate { y: card.slideY }
                Component.onCompleted: { appeared = true; slideY = 0 }
                onClosingChanged: if (closing) { closeAnimTimer.restart(); slideY = hiddenOffset }
                Behavior on opacity { NumberAnimation { duration: Config.notifAnim; easing.type: Easing.OutCubic } }
                Behavior on slideY { NumberAnimation { duration: Config.notifAnim; easing.type: Easing.OutCubic } }
            }
        }
    }
}
