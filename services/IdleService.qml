pragma Singleton
import Quickshell
import Quickshell.Io

// Serviço de INIBIÇÃO de idle/lock (singleton). Liga/desliga o swayidle — que dispara o
// swaylock (bloqueio) e o dpms (desligar as telas por ociosidade). Serve ao toggle da
// 3ª pétala ("lâmpada").
//
// Estado inicial: `inhibited=false` → swayidle RODANDO → lockscreen/hibernação ATIVOS
// (o toggle começa "desligado", habilitando o bloqueio).
//
// COMO: para INIBIR, basta matar o swayidle (`pkill` roda bem pelo Process do quickshell).
// Para REATIVAR, pedimos ao COMPOSITOR p/ subir o swayidle de novo via session.sh (guardas
// pgrep → não duplica): o swayidle é app Wayland e precisa do ambiente do compositor, não
// dá p/ relançá-lo pelo Process do quickshell (mesma armadilha do StartupService).
Singleton {
    id: svc

    property bool inhibited: false   // false = lock/idle ATIVO (padrão); true = inibido (swayidle morto)

    // inibe: mata o swayidle (sem swayidle não há timeout de lock nem de dpms)
    function disableLock() {
        proc.exec(["sh", "-c",
            "pkill -x swayidle; notify-send -a Quickshell -r 9110 'Bloqueio desativado' 'A tela não vai bloquear nem hibernar por ociosidade.'"])
        inhibited = true
    }
    // reativa: relança o swayidle pelo compositor (via session.sh, com guardas pgrep)
    function enableLock() {
        proc.exec(["mmsg", "dispatch",
            "spawn,sh -c '$HOME/.config/quickshell/services/session.sh'"])
        notifyProc.exec(["notify-send", "-a", "Quickshell", "-r", "9110",
            "Bloqueio ativado", "A tela volta a bloquear/hibernar por ociosidade."])
        inhibited = false
    }
    function toggle() { if (inhibited) enableLock(); else disableLock() }

    Process { id: proc }
    Process { id: notifyProc }
}
