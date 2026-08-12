pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick   // Timer/Connections (debounce + reagir a mudanças no Config)
import "root:/"   // Config (timeout/dpms/before-sleep configuráveis pela janela de configurações)

// Serviço de INIBIÇÃO de idle/lock (singleton). Liga/desliga o swayidle — que dispara o
// gtklock (bloqueio) e o dpms (desligar as telas por ociosidade). Serve ao toggle da
// cristal de Sistema ("lâmpada") e ao próprio bootstrap do StartupService.
//
// Estado inicial: `inhibited=false` → swayidle RODANDO → lockscreen/hibernação ATIVOS
// (o toggle começa "desligado", habilitando o bloqueio).
//
// COMO: para INIBIR, basta matar o swayidle (`pkill` roda bem pelo Process do quickshell).
// Para REATIVAR, pedimos ao COMPOSITOR p/ subir o swayidle de novo via session.sh (guardas
// pgrep → não duplica): o swayidle é app Wayland e precisa do ambiente do compositor —
// por isso o relançamento vai por `niri msg action spawn-sh` (igual ao StartupService, que
// usa o MESMO sessionArgv() abaixo).
//
// Configurável pela janela de configurações (cristal de Sistema → engrenagem, grupo
// "Bloqueio por inatividade"): Config.idleLockTimeout/idleDpmsTimeout/idleLockOnSleep vão
// pro session.sh como env vars (ele tem fallback próprio p/ quando chamado à mão). Mudar
// qualquer um enquanto o swayidle está ATIVO o reinicia sozinho (Connections abaixo) —
// se estiver inibido, não há o que reiniciar (a próxima ativação já usa os valores atuais).
Singleton {
    id: svc

    property bool inhibited: false   // false = lock/idle ATIVO (padrão); true = inibido (swayidle morto)

    // argv do spawn-sh que sobe o session.sh com os valores ATUAIS de idle (env vars).
    // Compartilhado com o StartupService (bootstrap da sessão) p/ não duplicar a lógica.
    function sessionArgv() {
        return ["niri", "msg", "action", "spawn-sh", "--",
            "IDLE_LOCK_TIMEOUT=" + Config.idleLockTimeout +
            " IDLE_DPMS_TIMEOUT=" + Config.idleDpmsTimeout +
            " IDLE_LOCK_ON_SLEEP=" + (Config.idleLockOnSleep ? 1 : 0) +
            " \"$HOME/.config/quickshell/services/session.sh\""]
    }

    // inibe: mata o swayidle (sem swayidle não há timeout de lock nem de dpms)
    function disableLock() {
        proc.exec(["sh", "-c",
            "pkill -x swayidle; notify-send -a Quickshell -r 9110 'Bloqueio desativado' 'A tela não vai bloquear nem hibernar por ociosidade.'"])
        inhibited = true
    }
    // reativa: relança o swayidle pelo compositor (via session.sh, com guardas pgrep)
    function enableLock() {
        proc.exec(sessionArgv())
        notifyProc.exec(["notify-send", "-a", "Quickshell", "-r", "9110",
            "Bloqueio ativado", "A tela volta a bloquear/hibernar por ociosidade."])
        inhibited = false
    }
    function toggle() { if (inhibited) enableLock(); else disableLock() }

    // reinicia o swayidle JÁ RODANDO com os valores atuais (chamado ao editar timeout/
    // dpms/before-sleep nas configurações). O 'while pgrep' espera o processo morrer de
    // verdade antes de religar — senão a guarda pgrep do session.sh vê o antigo ainda
    // agonizando e desiste de subir o novo (falsa duplicata).
    function applyLiveConfig() {
        if (inhibited) return
        idleKillProc.exec(["sh", "-c",
            "pkill -x swayidle; while pgrep -x swayidle >/dev/null; do sleep 0.05; done"])
    }
    Timer { id: applyIdleTimer; interval: 500; onTriggered: svc.applyLiveConfig() }
    Connections {
        target: Config
        function onIdleLockTimeoutChanged() { applyIdleTimer.restart() }
        function onIdleDpmsTimeoutChanged() { applyIdleTimer.restart() }
        function onIdleLockOnSleepChanged() { applyIdleTimer.restart() }
    }

    Process { id: proc }
    Process { id: notifyProc }
    Process { id: idleKillProc; onExited: proc.exec(svc.sessionArgv()) }
}
