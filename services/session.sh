#!/bin/sh
# Daemons da SESSÃO, centralizados no quickshell e disparados pelo StartupService.qml
# (via `niri msg action spawn-sh` -> lançados pelo COMPOSITOR, com ambiente Wayland
# correto). As guardas `pgrep` evitam duplicar a cada (re)carga do quickshell;
# `setsid` destaca os processos p/ sobreviverem ao fim da ação de spawn / a um reload.

# Garante ferramentas instaladas em ~/.local/bin / ~/.cargo/bin no PATH.
#export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$PATH"

# Wallpaper (swaybg desenha um layer-shell de fundo).
pgrep -x swaybg >/dev/null || setsid swaybg -i "$HOME/Pictures/Wallpapers/vigna/vigna.jpg" -m fill &

# Applet do Bluetooth (aparece na bandeja do shell).
#pgrep -x blueman-applet >/dev/null || setsid blueman-applet &

# Idle / lock / dpms. swayidle dispara o swaylock-effects (v1.7+, ext-session-lock-v1,
# protocolo suportado pelo niri). Efeitos/cores do lock (tema Crimson Devil) ficam em
# ~/.config/swaylock/config. 'pidof swaylock ||' evita duas instâncias.
# dpms: o niri tem ações nativas (power-off-monitors / power-on-monitors); ao acordar,
# qualquer input religa as telas, mas religamos explicitamente no resume por garantia.
pgrep -x swayidle >/dev/null || \
    setsid swayidle -w \
        timeout 300 'pidof swaylock || swaylock' \ 
        before-sleep 'pidof swaylock || swaylock' &
