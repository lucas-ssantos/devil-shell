pragma Singleton
import Quickshell
import Quickshell.Io
import "root:/themes"   // Theme (paleta efetiva = paleta escolhida + overrides pal_*)
import "root:/"         // Config (lockBackgroundPath, fundo do gtklock)

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
//   gtklock -> ~/.config/gtklock/config.ini                  (tela de bloqueio: só o
//              `background=`, apontando pro wallpaper atual borrado — ver
//              WallpaperService.updateLockBackground(); cores vêm de graça do tema GTK3
//              "devil-shell" já registrado no sistema, ver ⚠️ TEMA GTK3 NOMEADO abaixo)
//   gtk3    -> ~/.config/gtk-3.0/devil-shell.css             (habilitar 1x: @import
//              url("devil-shell.css"); no topo do gtk-3.0/gtk.css do usuário)
//   gtk4    -> ~/.config/gtk-4.0/devil-shell.css             (idem, no gtk-4.0/gtk.css;
//              nomes de cor libadwaita, incl. sidebar_*/secondary_sidebar_* — barra de
//              atalhos do seletor de arquivos — + overrides de seletor pro GTK4 "puro",
//              ver gtk4SidebarOverrides())
//
// Além dos alvos acima, MESCLA (não sobrescreve — settings.ini não é arquivo dedicado
// nosso, pode ter outras chaves do usuário) `gtk-application-prefer-dark-theme=<0|1>` em
// gtk-3.0/settings.ini e gtk-4.0/settings.ini, conforme `Theme.isLight` da paleta ATIVA
// (0 p/ paletas claras como DragonBlanc, 1 p/ escuras como CrimsonDevil/InfernalRose) —
// senão a variante de Adwaita errada (clara/escura) continua ativa por baixo das cores do
// devil-shell.css sobrepostas.
//
// Também seta via `gsettings` (org.gnome.desktop.interface, systemwide): `color-scheme
// =<prefer-dark|prefer-light>` (idem, conforme `Theme.isLight`) e `accent-color=<red|pink,
// conforme a paleta>`.
// ⚠️ Isso não é cosmético opcional: libadwaita (AdwStyleManager) detecta claro/escuro
// consultando o portal `org.freedesktop.impl.portal.Settings` (chave `color-scheme` do
// namespace `org.gnome.desktop.interface`) mesmo fora de uma sessão GNOME — inclusive
// diálogos NATIVOS de apps libadwaita comuns, não só os sandboxed. Se o gsettings acima
// nunca rodou (ou o valor foi resetado por fora), esse portal continua respondendo
// "default" (claro) e os diálogos libadwaita não acompanham a polaridade da paleta ativa
// — foi exatamente esse o sintoma reportado (diálogo do xdg-desktop-portal com fundo
// escuro e texto ilegível mesmo com uma paleta clara ativa) com
// `~/.config/xdg-desktop-portal/portals.conf` apontando
// `org.freedesktop.impl.portal.Settings=gnome` (serve a chave DIRETO do gsettings, não
// do gtk-4.0/settings.ini). Conferir ao vivo: `gsettings get org.gnome.desktop.interface
// color-scheme` deve bater com a polaridade da paleta ativa depois de um export.
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
// ⚠️ BARRA LATERAL (GTK4) — mesma classe de bug do parágrafo acima, versão GTK4: o tema
// "Default" de FÁBRICA do GTK4 (confirmado via gresource extract em libgtk-4.so,
// theme/Default/Default-dark.css) hardcoda `.sidebar`/`.navigation-sidebar`/
// `stacksidebar` (ex.: `.sidebar { background-color: #313131; }`) em vez de usar
// @define-color. Isso só afeta apps GTK4 que NÃO usam libadwaita — libadwaita já expõe
// `sidebar_bg_color`/etc. como cores nomeadas de verdade (confirmado em libadwaita-1.so,
// styles/gtk.css), incluído acima. `gtk4SidebarOverrides()` cobre o caso hardcoded
// sobrescrevendo os seletores direto; como `~/.config/gtk-4.0/gtk.css` carrega com
// prioridade USER (> THEME do GTK), vence sem precisar de !important. Foi essa lacuna
// (só cobríamos os nomes libadwaita, não os dois casos) que deixava a barra de atalhos
// do seletor de arquivo SEM tema mesmo com o resto correto.
//
// Antes de escrever, apaga backups antigos (<arquivo>.bak-*) e faz um novo BACKUP do
// que existir (<arquivo>.bak-<timestamp>) — só o mais recente fica. Depois recarrega ao
// vivo: niri (load-config-file), kitty (SIGUSR1 relê o config) e reinicia TANTO
// xdg-desktop-portal-gtk.service QUANTO xdg-desktop-portal-gnome.service (cada um é um
// daemon de vida longa que só lê o gtk.css/settings.ini na própria inicialização; qual
// dos dois desenha o diálogo nativo — de arquivo, impressão, etc. — depende de
// ~/.config/xdg-desktop-portal/portals.conf, então reiniciamos os dois pra não depender
// de saber qual está ativo). Os apps GTK comuns leem o tema no próximo lançamento; o
// Vesktop recarrega o CSS sozinho quando habilitado.
//
// Export manual pela CLI (além do botão da SettingsWindow): `qs ipc call theme exportAll`.
Singleton {
    id: root

    // cor -> "#rrggbb"
    function hx(c) { return ("" + c).toLowerCase() }

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
            + dialogOverrides()
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
            // libadwaita define sidebar_*/secondary_sidebar_* como cores NOMEADAS de verdade
            // (confirmado via gresource extract em libadwaita-1.so, styles/gtk.css) — ao
            // contrário do bug do GTK3/Adwaita (ver mais abaixo), aqui basta @define-color.
            // Sem isso, QUALQUER app libadwaita (Nautilus, Text Editor, e o file chooser NOVO
            // do xdg-desktop-portal-gnome — GNOME 46+, reescrito em libadwaita) mostra a
            // barra lateral de atalhos com o cinza de fábrica mesmo com o resto themado.
            + "@define-color sidebar_bg_color                                        " + hx(t.mantle) + ";\n"
            + "@define-color sidebar_fg_color                                         " + hx(t.text) + ";\n"
            + "@define-color sidebar_backdrop_color                                    " + hx(t.mantle) + ";\n"
            + "@define-color sidebar_border_color                                       " + hx(t.surface1) + ";\n"
            + "@define-color sidebar_shade_color                                         rgba(0, 0, 0, 0.25);\n"
            + "@define-color secondary_sidebar_bg_color                                   " + hx(t.crust) + ";\n"
            + "@define-color secondary_sidebar_fg_color                                    " + hx(t.text) + ";\n"
            + "@define-color secondary_sidebar_backdrop_color                               " + hx(t.crust) + ";\n"
            + "@define-color secondary_sidebar_border_color                                  " + hx(t.surface1) + ";\n"
            + "@define-color secondary_sidebar_shade_color                                    rgba(0, 0, 0, 0.25);\n"
            + gtk4SidebarOverrides()
            + dialogOverrides()
    }

    // ── GTK4 "puro" (sem libadwaita) — o tema "Default" de FÁBRICA do próprio GTK4
    // (confirmado via gresource extract em libgtk-4.so, theme/Default/Default-dark.css)
    // HARDCODA a cor de `.sidebar`/`.navigation-sidebar`/`stacksidebar` (ex.: `.sidebar {
    // background-color: #313131; }`) em vez de usar @define-color — mesma classe de bug
    // do Adwaita/GTK3 documentada abaixo, só que aqui é o GTK4 puro (apps que não linkam
    // libadwaita, então não leem os sidebar_* de cima). Sobrescrevemos os seletores
    // diretamente; como o nosso CSS é carregado com prioridade USER (> THEME do GTK), o
    // valor daqui vence independente de especificidade — sem precisar de !important.
    function gtk4SidebarOverrides() {
        const t = Theme
        return ".sidebar { background-color: " + hx(t.mantle) + "; }\n"
            + ".sidebar:not(separator):dir(ltr), .sidebar:not(separator).left, .sidebar:not(separator).left:dir(rtl) { border-right-color: " + hx(t.surface1) + "; }\n"
            + ".sidebar:not(separator):dir(rtl), .sidebar:not(separator).right { border-left-color: " + hx(t.surface1) + "; }\n"
            + "separator.sidebar { background-color: " + hx(t.surface1) + "; }\n"
            + ".navigation-sidebar > row:hover { background-color: " + hx(t.surface0) + "; }\n"
            + ".navigation-sidebar > row:selected { background-color: " + hx(t.surface1) + "; color: " + hx(t.text) + "; }\n"
            + ".navigation-sidebar > row:selected:hover { background-color: " + hx(t.overlay0) + "; }\n"
            + "stacksidebar row:selected { background-color: " + hx(t.surface1) + "; color: " + hx(t.text) + "; }\n"
    }

    // ── Diálogos (GtkMessageDialog/GtkDialog — ex.: prompts do VSCode/Electron via GTK
    // nativo) — cantos arredondados e botões com acento sólido. Selecionadas por classe
    // (".dialog"/".messagedialog", não ".background" genérico) pra NÃO arredondar/colorir
    // a janela principal de apps GTK comuns (Nautilus, editores…), só popups de diálogo.
    // Sintaxe/seletores válidos tanto em GTK3 quanto GTK4 (função reaproveitada nos dois
    // + no tema GTK3 nomeado, via gtk4Content() dentro de exportAll()). Hex cru (não
    // @define-color) pra funcionar igual nos dois motores de CSS sem depender de quais
    // nomes de cor cada um already define. Botões de diálogo em cinza quase idêntico ao
    // fundo eram o motivo de sumirem no Dragon Blanc (tema claro, baixo contraste).
    function dialogOverrides() {
        const t = Theme
        return "window.dialog, window.messagedialog,\n"
            + ".dialog.background, .messagedialog.background {\n"
            + "  border-radius: 12px;\n"
            + "}\n"
            + "window.dialog button, window.messagedialog button,\n"
            + ".dialog button, .messagedialog button {\n"
            + "  background-image: none;\n"
            + "  background-color: " + hx(t.mauve) + " !important;\n"
            + "  color: " + hx(t.rosewater) + " !important;\n"
            + "}\n"
            + "window.dialog button:hover, window.messagedialog button:hover,\n"
            + ".dialog button:hover, .messagedialog button:hover {\n"
            + "  background-color: " + hx(t.red) + " !important;\n"
            + "}\n"
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

    // ── gtklock (config.ini) — tela de bloqueio ──
    // Só a imagem de fundo (wallpaper atual borrado, gerado por
    // WallpaperService.updateLockBackground() em Config.lockBackgroundPath); cores/tema
    // vêm de graça do tema GTK3 "devil-shell" já registrado no sistema por exportAll()
    // (gtklock é GTK3 puro — ldd libgtk-3.so — então lê gtk-theme-name normalmente).
    function gtklockContent() {
        return "# Auto-generated by quickshell. Do not edit by hand.\n"
            + "[main]\n"
            + "background=" + Config.lockBackgroundPath + "\n"
    }

    // accent-color do libadwaita é um ENUM fixo (9 cores), não hex livre — mapeia pra
    // o mais próximo do ACENTO real de cada paleta (mauve): CrimsonDevil é vermelho puro,
    // InfernalRose é rosa/magenta, DragonBlanc é vermelho vivo.
    function accentEnum() {
        const map = { "CrimsonDevil": "red", "InfernalRose": "pink", "DragonBlanc": "red" }
        return map[Theme.shellName] ?? "red"
    }

    // Regenera TODOS os arquivos externos (backup + escrita + reload ao vivo).
    function exportAll() {
        const HOME = Quickshell.env("HOME")
        // Polaridade do tema ATIVO (Theme.isLight) — nada de "sempre dark" fixo: uma
        // paleta clara (ex.: DragonBlanc) precisa de prefer-dark-theme=0/color-scheme
        // claro, senão os apps GTK caem na variante escura da base adw-gtk3 por baixo do
        // nosso @define-color (o que já causou painéis escuros com texto escuro por cima).
        const darkPref = Theme.isLight ? "0" : "1"
        const colorScheme = Theme.isLight ? "prefer-light" : "prefer-dark"
        const targets = [
            { path: HOME + "/.config/kitty/themes/crimson-devil.conf", content: kittyContent() },
            { path: HOME + "/.config/niri/devil-shell/theme.kdl",       content: niriContent() },
            { path: HOME + "/.config/vesktop/themes/devil-shell.css",   content: vesktopContent() },
            { path: HOME + "/.config/gtklock/config.ini",               content: gtklockContent() },
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
            + "ini_set '" + HOME + "/.config/gtk-3.0/settings.ini' gtk-application-prefer-dark-theme " + darkPref + "\n"
            + "ini_set '" + HOME + "/.config/gtk-4.0/settings.ini' gtk-application-prefer-dark-theme " + darkPref + "\n"
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
        script += "command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface color-scheme '" + colorScheme + "' || true\n"
        script += "command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface accent-color '" + accentEnum() + "' || true\n"
        // recarrega ao vivo (Process herda o env -> niri msg acha o socket; kitty relê no SIGUSR1)
        script += "command -v niri >/dev/null && niri msg action load-config-file || true\n"
        script += "pkill -USR1 -x kitty 2>/dev/null || true\n"
        // Ambos os backends de portal são daemons de vida longa que só leem gtk.css/
        // settings.ini na própria inicialização. Reinicia os DOIS porque qual deles
        // desenha o file chooser/diálogos depende do ~/.config/xdg-desktop-portal/
        // portals.conf do usuário (aqui, FileChooser/Settings/Screenshot/Clipboard
        // apontam pra "gnome" — ver comentário grande no topo do arquivo).
        script += "systemctl --user try-restart xdg-desktop-portal-gtk.service 2>/dev/null || true\n"
        script += "systemctl --user try-restart xdg-desktop-portal-gnome.service 2>/dev/null || true\n"
        script += "command -v notify-send >/dev/null && notify-send -a 'Devil Shell' 'Temas regenerados' 'kitty / niri / vesktop / gtklock / gtk3 / gtk4' || true\n"
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
