pragma Singleton
import Quickshell
import Quickshell.Io
import "root:/themes"   // Theme (paleta efetiva = paleta escolhida + overrides pal_*)

// Regenera os arquivos de tema dos apps EXTERNOS a partir da paleta efetiva do
// shell (Theme.*, que já reflete a paleta escolhida e os overrides de cor crua).
// Disparado pelo Settings ao trocar de tema ou cor de paleta (e pelo botão da
// janela de configurações).
//
// Alvos (escreve nos MESMOS arquivos que os apps já incluem -> sem mexer noutras
// linhas de config):
//   kitty   -> ~/.config/kitty/themes/crimson-devil.conf   (include no kitty.conf)
//   niri    -> ~/.config/niri/devil-shell/theme.kdl          (include no config.kdl;
//              as linhas de cor do focus-ring/border do config.kdl devem ficar
//              comentadas p/ não competirem com o tema)
//   vesktop -> ~/.config/vesktop/themes/devil-shell.css      (habilitar 1x no Vesktop)
//   swaylock-> ~/.config/swaylock/config                     (tela de bloqueio)
//   gtk3    -> ~/.config/gtk-3.0/devil-shell.css             (habilitar 1x: @import
//              url("devil-shell.css"); no topo do gtk-3.0/gtk.css do usuário)
//   gtk4    -> ~/.config/gtk-4.0/devil-shell.css             (idem, no gtk-4.0/gtk.css;
//              nomes de cor libadwaita — só apps GTK4/libadwaita respeitam todos)
//
// Além dos alvos acima, MESCLA (não sobrescreve — settings.ini não é arquivo dedicado
// nosso, pode ter outras chaves do usuário) `gtk-application-prefer-dark-theme=1` em
// gtk-3.0/settings.ini e gtk-4.0/settings.ini, senão a variante clara da Adwaita
// continua ativa mesmo com as cores do devil-shell.css sobrepostas.
//
// Também seta via `gsettings` (org.gnome.desktop.interface, systemwide): `color-scheme
// =prefer-dark` e `accent-color=<red|pink, conforme a paleta>` — usado por libadwaita
// (GTK4) em geral.
//
// ⚠️ TEMA NOMEADO (gtk-3.0) — por que existe além do override em ~/.config/gtk-3.0:
// diagnosticado ao vivo (GTK Inspector + gresource extract) que o Adwaita/Adwaita-dark
// "de fábrica" do GTK3 HARDCODA a cor de várias seletoras centrais — ex.:
// `.view:backdrop, iconview:backdrop, textview text:backdrop { background-color: #303030; }`
// em gtk-contained-dark.css — sem usar `@theme_base_color`/`@view_bg_color`. Isso é
// invisível pra apps comuns que também herdam nosso `~/.config/gtk-3.0/devil-shell.css`
// (o `@define-color` ali recolore o que É nomeado — testado com `zenity`, funciona), MAS
// o `xdg-desktop-portal-gtk` (backend que desenha o diálogo nativo de arquivo pra apps
// via portal — Vesktop, VSCode, qualquer Electron no Wayland) usa exatamente essas
// seletoras hardcoded pro fundo da lista de arquivos, então nenhum @define-color as
// alcança. A correção real é trocar a BASE por uma que use as variáveis de verdade: o
// tema `adw-gtk3-dark` (projeto github.com/lassekongo83/adw-gtk3, mesmo pacote que
// resolve isso no Arch como "adw-gtk-theme") reimplementa o Adwaita usando
// `@view_bg_color`/`@sidebar_bg_color`/etc. em vez de hex fixo. Por isso `exportAll()`:
//   1. procura a extensão Flatpak `org.gtk.Gtk3theme.adw-gtk3-dark` já instalada
//      (`flatpak install --user flathub org.gtk.Gtk3theme.adw-gtk3-dark` — PRÉ-REQUISITO
//      de instalação única, não algo que dá pra vendorizar/gerar aqui: são ~8000 linhas
//      de CSS + assets binários);
//   2. copia o `gtk-3.0` dela pra `~/.local/share/themes/devil-shell/gtk-3.0/`;
//   3. anexa (`>>`, cascata CSS = última definição vence) nosso override — mesmo
//      conteúdo de gtk4Content() [os nomes libadwaita são os MESMOS que adw-gtk3 usa]
//      + gtk3SidebarOverrides() — no final de `gtk.css` E `gtk-dark.css`;
//   4. seta `gtk-theme-name=devil-shell` (só se a cópia acima deu certo — sem a
//      extensão instalada, isso é pulado silenciosamente e o override "burro" de
//      ~/.config/gtk-3.0 continua sendo o único mecanismo, como antes).
// O `~/.config/gtk-3.0/devil-shell.css` (gtk3Content()) continua existindo em paralelo —
// ainda é o que apps SEM portal leem (ex.: zenity).
//
// Antes de escrever, apaga backups antigos (<arquivo>.bak-*) e faz um novo BACKUP do
// que existir (<arquivo>.bak-<timestamp>) — só o mais recente fica. Depois recarrega
// ao vivo: niri (load-config-file), kitty (SIGUSR1 relê o config) e reinicia o
// xdg-desktop-portal-gtk.service (ele é um daemon de vida longa que só lê o gtk.css/
// settings.ini na própria inicialização — sem restart, o diálogo nativo de arquivos
// de apps Electron como o Discord continua com o tema antigo). Os apps GTK comuns leem
// o tema no próximo lançamento; o Vesktop recarrega o CSS sozinho quando habilitado.
//
// Export manual pela CLI (além do botão da SettingsWindow): `qs ipc call theme exportAll`.
Singleton {
    id: root

    // cor -> "#rrggbb"
    function hx(c) { return ("" + c).toLowerCase() }
    // cor -> "rrggbb"
    function rgb(c) { return hx(c).replace("#", "") }
    // cor -> "RRGGBBAA" (swaylock); aa = alfa em hex (ex.: "ff", "cc")
    function sl(c, aa) { return rgb(c) + (aa ? aa : "ff") }

    // ── kitty (themes/crimson-devil.conf) ──
    function kittyContent() {
        const t = Theme
        return "## name: Devil Shell (generated)\n"
            + "## Auto-generated by quickshell. Do not edit by hand.\n\n"
            + "foreground            " + hx(t.text) + "\n"
            + "background            " + hx(t.crust) + "\n"
            + "selection_foreground  " + hx(t.crust) + "\n"
            + "selection_background  " + hx(t.mauve) + "\n\n"
            + "cursor                " + hx(t.red) + "\n"
            + "cursor_text_color     " + hx(t.crust) + "\n\n"
            + "url_color             " + hx(t.peach) + "\n\n"
            + "color0  " + hx(t.base) + "\ncolor8  " + hx(t.surface1) + "\n"
            + "color1  " + hx(t.mauve) + "\ncolor9  " + hx(t.red) + "\n"
            + "color2  " + hx(t.green) + "\ncolor10 " + hx(t.teal) + "\n"
            + "color3  " + hx(t.yellow) + "\ncolor11 " + hx(t.peach) + "\n"
            + "color4  " + hx(t.blue) + "\ncolor12 " + hx(t.sky) + "\n"
            + "color5  " + hx(t.maroon) + "\ncolor13 " + hx(t.pink) + "\n"
            + "color6  " + hx(t.teal) + "\ncolor14 " + hx(t.sky) + "\n"
            + "color7  " + hx(t.text) + "\ncolor15 " + hx(t.rosewater) + "\n\n"
            + "active_tab_foreground    " + hx(t.crust) + "\n"
            + "active_tab_background     " + hx(t.mauve) + "\n"
            + "active_tab_font_style     bold\n"
            + "inactive_tab_foreground  " + hx(t.subtext0) + "\n"
            + "inactive_tab_background   " + hx(t.base) + "\n"
            + "inactive_tab_font_style   normal\n"
            + "tab_bar_background        " + hx(t.crust) + "\n\n"
            + "active_border_color    " + hx(t.red) + "\n"
            + "inactive_border_color  " + hx(t.surface1) + "\n"
            + "bell_border_color      " + hx(t.peach) + "\n\n"
            + "mark1_foreground " + hx(t.crust) + "\nmark1_background " + hx(t.red) + "\n"
            + "mark2_foreground " + hx(t.crust) + "\nmark2_background " + hx(t.peach) + "\n"
            + "mark3_foreground " + hx(t.crust) + "\nmark3_background " + hx(t.pink) + "\n"
    }

    // ── niri (devil-shell/theme.kdl) — cores do focus-ring/border do compositor ──
    // O niri faz merge de blocos `layout` duplicados entre o config.kdl e os includes.
    function niriContent() {
        const t = Theme
        return "// Auto-generated by quickshell. Do not edit by hand.\n"
            + "// Included by config.kdl. Apply: niri msg action load-config-file\n\n"
            + "layout {\n"
            + "    focus-ring {\n"
            + "        active-color \"" + hx(t.red) + "\"\n"
            + "        inactive-color \"" + hx(t.surface1) + "\"\n"
            + "        urgent-color \"" + hx(t.peach) + "\"\n"
            + "    }\n"
            + "    border {\n"
            + "        active-color \"" + hx(t.red) + "\"\n"
            + "        inactive-color \"" + hx(t.surface1) + "\"\n"
            + "        urgent-color \"" + hx(t.peach) + "\"\n"
            + "    }\n"
            + "}\n"
    }

    // ── vesktop (themes/devil-shell.css) — tema Vencord; habilitar 1x no Vesktop ──
    function vesktopContent() {
        const t = Theme
        return "/**\n * @name Devil Shell\n * @description Auto-generated by quickshell. Matches the shell palette.\n * @author quickshell\n */\n"
            + ":root {\n"
            + "  --background-primary: " + hx(t.base) + ";\n"
            + "  --background-secondary: " + hx(t.mantle) + ";\n"
            + "  --background-secondary-alt: " + hx(t.surface0) + ";\n"
            + "  --background-tertiary: " + hx(t.crust) + ";\n"
            + "  --background-floating: " + hx(t.crust) + ";\n"
            + "  --background-accent: " + hx(t.mauve) + ";\n"
            + "  --background-modifier-selected: " + hx(t.surface0) + ";\n"
            + "  --channeltextarea-background: " + hx(t.surface0) + ";\n"
            + "  --text-normal: " + hx(t.text) + ";\n"
            + "  --text-muted: " + hx(t.subtext0) + ";\n"
            + "  --header-primary: " + hx(t.text) + ";\n"
            + "  --header-secondary: " + hx(t.subtext1) + ";\n"
            + "  --interactive-normal: " + hx(t.subtext0) + ";\n"
            + "  --interactive-hover: " + hx(t.text) + ";\n"
            + "  --interactive-active: " + hx(t.red) + ";\n"
            + "  --brand-experiment: " + hx(t.mauve) + ";\n"
            + "  --brand-500: " + hx(t.mauve) + ";\n"
            + "  --button-positive-background: " + hx(t.mauve) + ";\n"
            + "}\n"
    }

    // ── GTK3 (gtk-3.0/devil-shell.css) — nomes clássicos do Adwaita ──
    // Habilitar 1x: adicionar `@import url("devil-shell.css");` no topo do
    // ~/.config/gtk-3.0/gtk.css do usuário (não escrevemos nesse arquivo pra não
    // apagar customizações existentes).
    function gtk3Content() {
        const t = Theme
        return "/* Auto-generated by quickshell. Do not edit by hand. */\n"
            + "@define-color theme_bg_color             " + hx(t.base) + ";\n"
            + "@define-color theme_fg_color              " + hx(t.text) + ";\n"
            + "@define-color theme_base_color             " + hx(t.mantle) + ";\n"
            + "@define-color theme_text_color              " + hx(t.text) + ";\n"
            + "@define-color theme_selected_bg_color         " + hx(t.mauve) + ";\n"
            + "@define-color theme_selected_fg_color          " + hx(t.rosewater) + ";\n"
            + "@define-color theme_selected_borders_color      " + hx(t.maroon) + ";\n"
            + "@define-color theme_unfocused_bg_color            " + hx(t.base) + ";\n"
            + "@define-color theme_unfocused_fg_color             " + hx(t.subtext0) + ";\n"
            + "@define-color theme_unfocused_base_color            " + hx(t.mantle) + ";\n"
            + "@define-color theme_unfocused_selected_bg_color      " + hx(t.surface1) + ";\n"
            + "@define-color theme_unfocused_selected_fg_color       " + hx(t.text) + ";\n"
            + "@define-color borders                                  " + hx(t.surface1) + ";\n"
            + "@define-color unfocused_borders                         " + hx(t.surface0) + ";\n"
            + "@define-color insensitive_bg_color                       " + hx(t.surface0) + ";\n"
            + "@define-color insensitive_fg_color                        " + hx(t.overlay0) + ";\n"
            + "@define-color insensitive_base_color                       " + hx(t.mantle) + ";\n"
            + "@define-color warning_color                                 " + hx(t.yellow) + ";\n"
            + "@define-color error_color                                    " + hx(t.red) + ";\n"
            + "@define-color success_color                                   " + hx(t.green) + ";\n"
    }

    // ── GTK4 (gtk-4.0/devil-shell.css) — nomes libadwaita ──
    // Habilitar 1x: adicionar `@import url("devil-shell.css");` no topo do
    // ~/.config/gtk-4.0/gtk.css do usuário. Só apps que usam libadwaita seguem TODOS
    // esses nomes; GTK4 puro (sem libadwaita) ignora os que não reconhece.
    function gtk4Content() {
        const t = Theme
        return "/* Auto-generated by quickshell. Do not edit by hand. */\n"
            + "@define-color accent_bg_color         " + hx(t.mauve) + ";\n"
            + "@define-color accent_fg_color          " + hx(t.rosewater) + ";\n"
            + "@define-color accent_color              " + hx(t.mauve) + ";\n"
            + "@define-color destructive_bg_color       " + hx(t.red) + ";\n"
            + "@define-color destructive_fg_color        " + hx(t.crust) + ";\n"
            + "@define-color destructive_color            " + hx(t.red) + ";\n"
            + "@define-color success_bg_color              " + hx(t.green) + ";\n"
            + "@define-color success_fg_color               " + hx(t.crust) + ";\n"
            + "@define-color success_color                   " + hx(t.green) + ";\n"
            + "@define-color warning_bg_color                 " + hx(t.yellow) + ";\n"
            + "@define-color warning_fg_color                  " + hx(t.crust) + ";\n"
            + "@define-color warning_color                      " + hx(t.yellow) + ";\n"
            + "@define-color error_bg_color                      " + hx(t.red) + ";\n"
            + "@define-color error_fg_color                       " + hx(t.crust) + ";\n"
            + "@define-color error_color                           " + hx(t.red) + ";\n"
            + "@define-color window_bg_color                        " + hx(t.base) + ";\n"
            + "@define-color window_fg_color                         " + hx(t.text) + ";\n"
            + "@define-color view_bg_color                            " + hx(t.mantle) + ";\n"
            + "@define-color view_fg_color                             " + hx(t.text) + ";\n"
            + "@define-color headerbar_bg_color                         " + hx(t.mantle) + ";\n"
            + "@define-color headerbar_fg_color                          " + hx(t.text) + ";\n"
            + "@define-color headerbar_border_color                       " + hx(t.surface1) + ";\n"
            + "@define-color headerbar_backdrop_color                      " + hx(t.mantle) + ";\n"
            + "@define-color headerbar_shade_color                          rgba(0, 0, 0, 0.12);\n"
            + "@define-color card_bg_color                                   " + hx(t.surface0) + ";\n"
            + "@define-color card_fg_color                                    " + hx(t.text) + ";\n"
            + "@define-color card_shade_color                                  rgba(0, 0, 0, 0.12);\n"
            + "@define-color dialog_bg_color                                    " + hx(t.mantle) + ";\n"
            + "@define-color dialog_fg_color                                     " + hx(t.text) + ";\n"
            + "@define-color popover_bg_color                                     " + hx(t.surface0) + ";\n"
            + "@define-color popover_fg_color                                      " + hx(t.text) + ";\n"
            + "@define-color shade_color                                            rgba(0, 0, 0, 0.36);\n"
            + "@define-color scrollbar_outline_color                                 rgba(0, 0, 0, 0.5);\n"
    }

    // ── GTK3 nomeado (~/.local/share/themes/devil-shell/gtk-3.0/) — cores extras que só
    // existem nesse contexto (sidebar de atalhos do seletor de arquivos: @sidebar_*, não
    // faz parte do conjunto de gtk3Content()/gtk4Content()). Ver exportAll() pra entender
    // POR QUE esse tema nomeado existe (não basta @define-color contra o Adwaita de fábrica).
    // sidebar_bg_color/backdrop_color usam a MESMA cor (mantle — o mesmo vermelho escuro do
    // fundo/view_bg_color, não o maroon vívido) pra não trocar de tom ao perder o foco.
    // O botão "Selecionar" (suggested-action) tem uma regra :backdrop no adw-gtk3 que
    // ESMAECE a cor via mix()/alpha() quando a janela perde foco (por design do tema) — o
    // !important força ele a ficar sólido sempre, senão lê como cinza mesmo sendo vermelho.
    function gtk3SidebarOverrides() {
        const t = Theme
        return "@define-color sidebar_bg_color " + hx(t.mantle) + ";\n"
            + "@define-color sidebar_fg_color " + hx(t.text) + ";\n"
            + "@define-color sidebar_backdrop_color " + hx(t.mantle) + ";\n"
            + "button.suggested-action, button.suggested-action:backdrop,\n"
            + "headerbar button.suggested-action, headerbar button.suggested-action:backdrop,\n"
            + ".titlebar button.suggested-action, .titlebar button.suggested-action:backdrop {\n"
            + "  background-color: " + hx(t.mauve) + " !important;\n"
            + "  color: " + hx(t.rosewater) + " !important;\n"
            + "}\n"
    }

    // ── swaylock (config) — tela de bloqueio com a paleta do shell ──
    // ATENCAO: o swaylock NAO aceita comentario no fim de linha de opcao (vira valor).
    function swaylockContent() {
        const t = Theme
        return "# Auto-generated by quickshell. Do not edit by hand. Format: RRGGBBAA.\n"
            + "screenshots\n"
            + "effect-blur=7x5\n"
            + "effect-vignette=0.5:0.5\n"
            + "fade-in=0.3\n"
            + "grace=2\n"
            + "grace-no-mouse\n"
            + "indicator-idle-visible\n"
            + "ignore-empty-password\n"
            + "clock\n"
            + "timestr=%H:%M\n"
            + "datestr=%a %d %b\n"
            + "indicator\n"
            + "indicator-radius=110\n"
            + "indicator-thickness=8\n"
            + "font=JetBrainsMono Nerd Font\n"
            + "font-size=26\n"
            + "color=" + sl(t.crust) + "\n"
            + "inside-color=" + sl(t.base, "cc") + "\n"
            + "inside-clear-color=" + sl(t.surface0, "cc") + "\n"
            + "inside-ver-color=" + sl(t.maroon, "cc") + "\n"
            + "inside-wrong-color=" + sl(t.red, "cc") + "\n"
            + "inside-caps-lock-color=" + sl(t.surface0, "cc") + "\n"
            + "ring-color=" + sl(t.mauve) + "\n"
            + "ring-clear-color=" + sl(t.maroon) + "\n"
            + "ring-ver-color=" + sl(t.peach) + "\n"
            + "ring-wrong-color=" + sl(t.red) + "\n"
            + "ring-caps-lock-color=" + sl(t.yellow) + "\n"
            + "line-uses-inside\n"
            + "key-hl-color=" + sl(t.peach) + "\n"
            + "bs-hl-color=" + sl(t.red) + "\n"
            + "caps-lock-key-hl-color=" + sl(t.peach) + "\n"
            + "caps-lock-bs-hl-color=" + sl(t.red) + "\n"
            + "separator-color=00000000\n"
            + "text-color=" + sl(t.text) + "\n"
            + "text-clear-color=" + sl(t.text) + "\n"
            + "text-ver-color=" + sl(t.text) + "\n"
            + "text-wrong-color=" + sl(t.text) + "\n"
            + "text-caps-lock-color=" + sl(t.text) + "\n"
    }

    // accent-color do libadwaita é um ENUM fixo (9 cores), não hex livre — mapeia pra
    // o mais próximo do ACENTO real de cada paleta (mauve): CrimsonDevil é vermelho puro,
    // InfernalRose é rosa/magenta.
    function accentEnum() {
        const map = { "CrimsonDevil": "red", "InfernalRose": "pink" }
        return map[Theme.shellName] ?? "red"
    }

    // Regenera TODOS os arquivos externos (backup + escrita + reload ao vivo).
    function exportAll() {
        const HOME = Quickshell.env("HOME")
        const targets = [
            { path: HOME + "/.config/kitty/themes/crimson-devil.conf", content: kittyContent() },
            { path: HOME + "/.config/niri/devil-shell/theme.kdl",       content: niriContent() },
            { path: HOME + "/.config/vesktop/themes/devil-shell.css",   content: vesktopContent() },
            { path: HOME + "/.config/swaylock/config",                  content: swaylockContent() },
            { path: HOME + "/.config/gtk-3.0/devil-shell.css",          content: gtk3Content() },
            { path: HOME + "/.config/gtk-4.0/devil-shell.css",          content: gtk4Content() }
        ]
        let script = "set -e\nts=$(date +%Y%m%d-%H%M%S)\n"
        for (let i = 0; i < targets.length; i++) {
            const p = targets[i].path
            const dir = p.substring(0, p.lastIndexOf("/"))
            const b64 = Qt.btoa(targets[i].content)   // base64 = só [A-Za-z0-9+/=], seguro entre aspas
            script += "mkdir -p '" + dir + "'\n"
            script += "rm -f '" + p + "'.bak-* 2>/dev/null || true\n"
            script += "[ -f '" + p + "' ] && cp -f '" + p + "' '" + p + ".bak-'$ts || true\n"
            script += "printf %s '" + b64 + "' | base64 -d > '" + p + "'\n"
        }
        // ini_set: settings.ini NÃO é arquivo dedicado nosso (pode ter outras chaves do
        // usuário — cursor-theme, icon-theme…), então mescla/atualiza só UMA chave em
        // [Settings] por vez, em vez de sobrescrever o arquivo inteiro.
        script += "ini_set() {\n"
            + "  f=\"$1\"; key=\"$2\"; val=\"$3\"\n"
            + "  mkdir -p \"$(dirname \"$f\")\"\n"
            + "  touch \"$f\"\n"
            + "  if grep -q '^\\[Settings\\]' \"$f\"; then\n"
            + "    if grep -q \"^$key=\" \"$f\"; then\n"
            + "      sed -i \"s/^$key=.*/$key=$val/\" \"$f\"\n"
            + "    else\n"
            + "      sed -i \"/^\\\\[Settings\\\\]/a $key=$val\" \"$f\"\n"
            + "    fi\n"
            + "  else\n"
            + "    printf '\\n[Settings]\\n%s=%s\\n' \"$key\" \"$val\" >> \"$f\"\n"
            + "  fi\n"
            + "}\n"
            + "ini_set '" + HOME + "/.config/gtk-3.0/settings.ini' gtk-application-prefer-dark-theme 1\n"
            + "ini_set '" + HOME + "/.config/gtk-4.0/settings.ini' gtk-application-prefer-dark-theme 1\n"
        // tema GTK3 nomeado, com base REAL (adw-gtk3-dark) por cima da qual anexamos
        // nossa paleta — ver o comentário grande no topo do arquivo pro porquê. Só roda
        // se a extensão Flatpak já estiver instalada; senão pula, sem quebrar nada.
        const gtk3NamedDir = HOME + "/.local/share/themes/devil-shell/gtk-3.0"
        const gtk3OverrideB64 = Qt.btoa(gtk4Content() + gtk3SidebarOverrides())
        script += "ADW_BASE=$(find '" + HOME + "/.local/share/flatpak/runtime/org.gtk.Gtk3theme.adw-gtk3-dark' /var/lib/flatpak/runtime/org.gtk.Gtk3theme.adw-gtk3-dark -maxdepth 5 -type d -name files 2>/dev/null | head -1)\n"
            + "if [ -n \"$ADW_BASE\" ] && [ -f \"$ADW_BASE/gtk-dark.css\" ]; then\n"
            + "  rm -rf '" + gtk3NamedDir + "'\n"
            + "  mkdir -p '" + gtk3NamedDir + "'\n"
            + "  cp -a \"$ADW_BASE\"/. '" + gtk3NamedDir + "'/\n"
            + "  printf %s '" + gtk3OverrideB64 + "' | base64 -d >> '" + gtk3NamedDir + "/gtk-dark.css'\n"
            + "  printf %s '" + gtk3OverrideB64 + "' | base64 -d >> '" + gtk3NamedDir + "/gtk.css'\n"
            + "  ini_set '" + HOME + "/.config/gtk-3.0/settings.ini' gtk-theme-name devil-shell\n"
            + "fi\n"
        // libadwaita (GTK4) lê ISSO pra cor/tema, não o @define-color do devil-shell.css
        script += "command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true\n"
        script += "command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface accent-color '" + accentEnum() + "' || true\n"
        // recarrega ao vivo (Process herda o env -> niri msg acha o socket; kitty relê no SIGUSR1)
        script += "command -v niri >/dev/null && niri msg action load-config-file || true\n"
        script += "pkill -USR1 -x kitty 2>/dev/null || true\n"
        script += "systemctl --user try-restart xdg-desktop-portal-gtk.service 2>/dev/null || true\n"
        script += "command -v notify-send >/dev/null && notify-send -a 'Devil Shell' 'Temas regenerados' 'kitty / niri / vesktop / swaylock / gtk3 / gtk4' || true\n"
        proc.exec(["sh", "-c", script])
    }

    Process { id: proc }

    // No-op: chamado pelo shell.qml só p/ instanciar o singleton (lazy) na
    // inicialização — sem isso o IpcHandler abaixo não existe até o 1º export.
    function init() {}

    // export manual pela CLI: `qs ipc call theme exportAll`
    IpcHandler {
        target: "theme"
        function exportAll(): void { root.exportAll() }
    }
}
