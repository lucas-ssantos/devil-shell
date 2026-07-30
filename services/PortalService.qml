pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Abre o seletor de arquivos/pastas do xdg-desktop-portal (org.freedesktop.portal.FileChooser)
// para os campos "dir"/"image" da SettingsWindow (ver SettingsField.qml). Delega a chamada
// D-Bus pro helper services/portal-pick.py (roda via Process; imprime o caminho escolhido no
// stdout, ou nada se cancelado) — no sistema, o backend que atende FileChooser precisa ser o
// gtk (o gnome falha sob niri, ver ~/.config/xdg-desktop-portal/portals.conf).
Singleton {
    id: svc

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/services/portal-pick.py"
    property string pendingKey: ""
    property bool busy: false   // evita 2 diálogos concorrentes disputando o mesmo Process

    function pickFolder(key, startDir) { run("folder", "Escolher pasta", key, startDir) }
    function pickImage(key, startDir)  { run("image", "Escolher imagem", key, startDir) }

    function run(mode, title, key, startDir) {
        if (svc.busy) return
        svc.busy = true
        svc.pendingKey = key
        proc.exec(["python3", svc.scriptPath, mode, title, startDir ?? ""])
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path !== "") Settings.set(svc.pendingKey, path)
                svc.busy = false
            }
        }
    }
}
