pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"   // Config (raiz)

// Serviço de atualizações (singleton):
//  - a cada Config.updateInterval, conta os pacotes atualizáveis -> `packages`
//    (tenta `sudo -n apt update` p/ refrescar; sem NOPASSWD ele só conta as listas atuais)
//  - runUpgrade(): abre um TERMINAL pra atualizar o sistema (o sudo pede a senha lá)
//  - updateMango(): roda ~/.config/mango/scripts/update-mango.sh num terminal (build do MangoWC)
//
// O `check` roda pelo Process do quickshell (CLI, não precisa de Wayland). Já o upgrade e o
// update-mango abrem um terminal via `mmsg spawn` (ambiente correto, igual a um keybind).
Singleton {
    id: svc
    property int  packages: 0       // nº de pacotes atualizáveis
    property bool checking: false

    function check() {
        checking = true
        checkProc.exec(["sh", "-c", Config.updateCheckCmd])
    }
    function runUpgrade()  { launch.exec(["mmsg", "dispatch", "spawn," + Config.updateUpgradeSpawn]) }
    function updateMango() { launch.exec(["mmsg", "dispatch", "spawn," + Config.updateMangoSpawn]) }

    Process { id: launch }                 // dispara terminais via mango

    Process {
        id: checkProc
        stdout: SplitParser {
            onRead: l => { const n = parseInt((l || "").trim()); if (!isNaN(n)) svc.packages = n }
        }
        onExited: svc.checking = false
    }

    Timer {
        interval: Config.updateInterval
        running: true; repeat: true; triggeredOnStart: true   // checa ao iniciar e a cada intervalo
        onTriggered: svc.check()
    }
}
