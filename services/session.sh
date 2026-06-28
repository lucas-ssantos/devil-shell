#!/bin/sh
# Daemons da SESSÃO, centralizados no quickshell e disparados pelo StartupService.qml
# (via `mmsg dispatch spawn` -> lançados pelo COMPOSITOR, com ambiente Wayland correto;
# o Process do quickshell NÃO serve p/ apps gráficos Wayland — mesma armadilha do
# CaptureService). As guardas `pgrep` evitam duplicar a cada (re)carga do quickshell;
# `setsid` destaca os processos p/ sobreviverem ao fim da ação de spawn / a um reload.

# O PATH do mango é mínimo e não inclui ~/.local/bin / ~/.cargo/bin (wayfreeze, etc.).
export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$PATH"

# Wallpaper (swaybg desenha um layer-shell de fundo).
pgrep -x swaybg >/dev/null || setsid swaybg -i "$HOME/Pictures/Wallpapers/vigna/vigna.jpg" -m fill &

# Applet do Bluetooth (aparece na bandeja do shell).
pgrep -x blueman-applet >/dev/null || setsid blueman-applet &

# Idle / lock / dpms. swayidle dispara o swaylock-effects (v1.7+, ext-session-lock-v1,
# o protocolo moderno suportado pelo mango — a ressalva antiga do wlr_input_inhibit
# deprecated não vale mais nesta versão). Efeitos/cores do lock (tema Crimson Devil)
# ficam em ~/.config/swaylock/config. 'pidof swaylock ||' evita duas instâncias.
# dpms: mango é wlroots (não sway) -> sem 'swaymsg'; usa-se wlr-randr por output (sem '*'):
# lista os nomes (linhas não indentadas) e liga/desliga cada um.
pgrep -x swayidle >/dev/null || \
    setsid swayidle -w \
        timeout 300 'pidof swaylock || swaylock' \
        timeout 600 'wlr-randr | grep -E "^[^[:space:]]" | cut -d" " -f1 | while read -r o; do wlr-randr --output "$o" --off; done' \
        resume       'wlr-randr | grep -E "^[^[:space:]]" | cut -d" " -f1 | while read -r o; do wlr-randr --output "$o" --on;  done' \
        before-sleep 'pidof swaylock || swaylock' &
