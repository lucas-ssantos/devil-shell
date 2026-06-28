pragma Singleton
import Quickshell
import Quickshell.Io

// Serviço de INICIALIZAÇÃO da sessão (singleton). Centraliza no quickshell o que antes
// ficava espalhado no autostart.sh do mango: subir os daemons da sessão (wallpaper,
// applet do bluetooth, idle/lock/dpms).
//
// COMO: esses daemons são apps GRÁFICOS Wayland (swaybg = layer-shell; blueman = GTK;
// swayidle fala o protocolo idle e dispara o swaylock). Lançá-los pelo Process do
// quickshell NÃO funciona — o filho não herda um WAYLAND_DISPLAY utilizável (a mesma
// armadilha do CaptureService). Por isso pedimos ao COMPOSITOR para lançá-los, via
// `mmsg dispatch spawn`, apontando para o script services/session.sh (guardas pgrep +
// setsid lá dentro). Chamado uma vez pelo shell.qml em Component.onCompleted.
//
// O QUE *NÃO* MOVE p/ cá (continua no autostart.sh, por ordem/bootstrap):
//   • PATH + dbus-update-activation-environment (ambiente da sessão);
//   • lançar o próprio `qs` (não dá p/ ele se autolançar);
//   • `pkill swaync` ANTES do qs (senão o qs não registra o servidor de notificações);
//   • a notificação "Mango reload" (semântica de reload do mango).
Singleton {
    id: svc

    // dispara o script de daemons pelo compositor (ambiente Wayland correto).
    // Em hot-reload o singleton é recriado e isto roda de novo — as guardas pgrep do
    // session.sh impedem duplicação, então é seguro.
    function start() {
        proc.exec(["mmsg", "dispatch",
            "spawn,sh -c '$HOME/.config/quickshell/services/session.sh'"])
    }

    Process { id: proc }
}
