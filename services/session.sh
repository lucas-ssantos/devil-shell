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
# dpms: o niri tem ações nativas (power-off-monitors / power-on-monitors); ao acordar,
# qualquer input religa as telas, mas religamos explicitamente no resume por garantia.
pgrep -x swayidle >/dev/null || \
    setsid swayidle -w \
        timeout 300 'pidof gtklock || gtklock' \
        before-sleep 'pidof gtklock || gtklock' &
