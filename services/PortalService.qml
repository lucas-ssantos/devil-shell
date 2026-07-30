pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Abre o seletor de arquivos/pastas do xdg-desktop-portal (org.freedesktop.portal.FileChooser)
// para os campos "dir"/"image" da SettingsWindow (ver SettingsField.qml). Delega a chamada
// D-Bus pro helper services/portal-pick.py (roda via Process; imprime o caminho escolhido no
// stdout, ou nada se cancelado) — no sistema, o backend que atende FileChooser precisa ser o
// gtk (o gnome falha sob niri, ver ~/.config/xdg-desktop-portal/portals.conf); o diálogo do
// gtk abre FLUTUANDO por uma window-rule no config.kdl do niri (app-id xdg-desktop-portal-gtk).
//
// A SettingsWindow é uma layer-shell Overlay (acima de QUALQUER janela normal, flutuante ou
// não — ordem fixa do protocolo: bottom < janelas normais < top < overlay), então o diálogo
// nunca apareceria por cima dela nem receberia clique. Por isso escondemos a SettingsWindow
// (`Settings.open = false`) enquanto o picker está aberto e a trazemos de volta ao terminar
// (`reopenSettings`), já com o campo atualizado.
Singleton {
    id: svc

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/services/portal-pick.py"
    property string pendingKey: ""
    property bool busy: false            // evita 2 diálogos concorrentes disputando o mesmo Process
    property bool reopenSettings: false  // Settings estava aberta quando o picker começou

    function pickFolder(key, startDir) { run("folder", "Escolher pasta", key, startDir) }
    function pickImage(key, startDir)  { run("image", "Escolher imagem", key, startDir) }

    function run(mode, title, key, startDir) {
        if (svc.busy) return
        svc.busy = true
        svc.pendingKey = key
        svc.reopenSettings = Settings.open
        if (Settings.open) Settings.open = false
        proc.exec(["python3", svc.scriptPath, mode, title, startDir ?? ""])
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path !== "") Settings.set(svc.pendingKey, path)
                if (svc.reopenSettings) Settings.open = true
                svc.busy = false
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.log("PortalService: portal-pick.py stderr:\n" + text)
        }
    }
}
