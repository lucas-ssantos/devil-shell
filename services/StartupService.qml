pragma Singleton
import Quickshell
import Quickshell.Io

// Serviço de INICIALIZAÇÃO da sessão (singleton). Centraliza no quickshell subir os
// daemons da sessão (wallpaper, applet do bluetooth, idle/lock/dpms).
//
// COMO: esses daemons são apps GRÁFICOS Wayland (swaybg = layer-shell; blueman = GTK;
// swayidle fala o protocolo idle e dispara o swaylock). Para garantir um ambiente
// Wayland correto, pedimos ao COMPOSITOR para lançá-los, via `niri msg action
// spawn-sh`, apontando para o script services/session.sh (guardas pgrep + setsid lá
// dentro). Chamado uma vez pelo shell.qml em Component.onCompleted.
//
// O próprio `qs` deve ser lançado pelo niri (spawn-at-startup no config.kdl); daí os
// filhos daqui herdam a sessão certa.
Singleton {
    id: svc

    // dispara o script de daemons pelo compositor (ambiente Wayland correto).
    // Em hot-reload o singleton é recriado e isto roda de novo — as guardas pgrep do
    // session.sh impedem duplicação, então é seguro.
    function start() {
        proc.exec(["niri", "msg", "action", "spawn-sh", "--",
            "\"$HOME/.config/quickshell/services/session.sh\""])
    }

    Process { id: proc }
}
