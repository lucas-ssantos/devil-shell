#!/bin/sh
# Daemons da SESSÃO, centralizados no quickshell e disparados pelo StartupService.qml
# (via `niri msg action spawn-sh` -> lançados pelo COMPOSITOR, com ambiente Wayland
# correto). As guardas `pgrep` evitam duplicar a cada (re)carga do quickshell;
# `setsid` destaca os processos p/ sobreviverem ao fim da ação de spawn / a um reload.

# Garante ferramentas instaladas em ~/.local/bin / ~/.cargo/bin no PATH.
#export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$PATH"

# Wallpaper (awww-daemon): agora sobe pelo WallpaperService.qml (init() no shell.qml),
# que aplica a última escolha do modo /bg do lançador. Nada a fazer aqui.

# Applet do Bluetooth (aparece na bandeja do shell).
#pgrep -x blueman-applet >/dev/null || setsid blueman-applet &

# Idle / lock / dpms. swayidle dispara o gtklock (ext-session-lock-v1, protocolo
# suportado pelo niri). Fundo/tema do lock ficam em ~/.config/gtklock/config.ini,
# gerado por ThemeExport (ver CLAUDE.md). 'pidof gtklock ||' evita duas instâncias.
# dpms: o niri tem ações nativas (power-off-monitors / power-on-monitors); quando
# IDLE_DPMS_TIMEOUT > 0 um 2º timeout desliga os monitores por ociosidade e o 'resume'
# religa no primeiro input (garantia extra além do religamento automático do niri).
#
# Os 3 valores abaixo vêm do menu de configurações (Config.idleLockTimeout/
# idleDpmsTimeout/idleLockOnSleep), passados como env vars por IdleService.sessionArgv()
# (StartupService no boot, IdleService.enableLock()/applyLiveConfig() depois). O fallback
# ("${VAR:-padrão}") é só para quando o script roda à mão, fora do quickshell.
IDLE_LOCK_TIMEOUT="${IDLE_LOCK_TIMEOUT:-300}"
IDLE_DPMS_TIMEOUT="${IDLE_DPMS_TIMEOUT:-0}"
IDLE_LOCK_ON_SLEEP="${IDLE_LOCK_ON_SLEEP:-1}"

pgrep -x swayidle >/dev/null || {
    set -- timeout "$IDLE_LOCK_TIMEOUT" 'pidof gtklock || gtklock'
    if [ "$IDLE_DPMS_TIMEOUT" -gt 0 ] 2>/dev/null; then
        set -- "$@" timeout "$IDLE_DPMS_TIMEOUT" 'niri msg action power-off-monitors' resume 'niri msg action power-on-monitors'
    fi
    if [ "$IDLE_LOCK_ON_SLEEP" = "1" ]; then
        set -- "$@" before-sleep 'pidof gtklock || gtklock'
    fi
    setsid swayidle -w "$@" &
}
