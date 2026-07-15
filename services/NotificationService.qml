pragma Singleton
import Quickshell
import Quickshell.Services.Notifications

// Serviço de notificações (singleton): recebe as notificações freedesktop (D-Bus)
// — Vesktop, apps do sistema, `notify-send` (ex.: um keybind do niri que chame
// notify-send), etc. — e mantém a lista das ativas em `list`.
// O auto-dismiss e o visual ficam na NotificationWindow.
Singleton {
    id: svc
    readonly property var list: server.trackedNotifications

    NotificationServer {
        id: server
        keepOnReload: false       // ao recarregar o qs, não ressuscita notificações antigas
        bodySupported: true
        imageSupported: true
        actionsSupported: false   // sem botões de ação por enquanto (toast simples)

        onNotification: (n) => {
            n.tracked = true       // sem isso a notificação é descartada na hora
        }
    }
}
