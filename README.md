# Devil Shell — shell Quickshell para Niri

Uma "barra" não-convencional para o compositor Wayland **[Niri](https://github.com/YaLTeR/niri)**
(tiling rolável), escrita em **QML** sobre o **[Quickshell](https://quickshell.org)**.

Em vez de uma barra reta, é uma **bola** ancorada no centro-inferior de cada monitor. Em hover/clique
ela sobe e abre um **menu radial de cristais**; os **workspaces** aparecem como pontos dentro da bola;
e há um **visualizador de áudio (CAVA)** ao fundo, no estilo do [Cavasik](https://github.com/TheWisker/Cavasik)
(espectro suave preenchido na barra inferior + um círculo pulsante ao redor da bola).

> Tudo é hot-reloaded: salvar qualquer `.qml` recarrega o shell na hora.

---

## ✨ Recursos

- **Bola central** com o número do workspace atual e um **anel de pontos** dos workspaces
  (clique troca; scroll sobre a bola troca com wrap 1↔N — no monitor certo).
- **Menu radial de cristais** (data-driven, reorganiza sozinho). Configuração atual (1º → 4º):
  - **1ª — Sistema:** configurações gerais do shell (janela modal), gravação de tela
    (monitor inteiro) e toggle de inibição do lock/idle.
  - **2ª — Lançador:** lançador **próprio**, também acessível por `Mod+D`
    (`qs ipc call launcher toggle`). Além de buscar apps, tem modos por prefixo (ver abaixo).
  - **3ª — Áudio:** mudo de saída/entrada + sliders de volume (scroll ajusta);
    **clique direito** abre o **seletor de dispositivo** (saída/entrada).
  - **4ª — Bandeja (system tray):** ícones dos apps; **esquerdo** foca a janela, **direito** abre o
    menu do app (menu estilizado no tema).
- **Notificações** (toast no topo-centro do monitor focado) — o Quickshell atua como servidor
  de notificações freedesktop.
- **Tema centralizado** (Catppuccin Mocha) e **toda** a customização num só lugar, com janela de
  configurações em runtime e export de temas para apps externos.

### 🚀 Lançador próprio

Overlay central no monitor focado (`Mod+D`, cristal do menu, ou `qs ipc call launcher toggle`).
O **modo** é derivado do que se digita:

| Digitar | Modo |
|---------|------|
| *(nada / texto)* | busca nos **apps instalados** (.desktop); vazio lista os **mais usados** primeiro (contagem persistida) |
| `=5+5` | **calculadora** (mostra `10` na hora; `sqrt`, `sin`, `pi`, `^`, `2pi`…; Enter encadeia a conta) |
| `/dir` | **navegador de arquivos** (pastas + imagens/vídeos, com miniaturas) — Enter abre no **VLC**, Backspace sobe |
| `/proc` | **processos** com PID/CPU/RAM — ordena por nome, PID, RAM ou CPU (chips ou Tab); Enter finaliza (TERM), Shift+Enter mata (KILL) |
| `/config` | abre a janela de configurações do shell |
| `/reload` | recarrega o Quickshell |
| `/` | paleta com os comandos acima |

Teclado: `↑↓` navega, `Enter` ativa, `Esc` fecha, `Tab` muda a ordenação no `/proc`.

---

## 📦 Dependências

Lista **exaustiva** — todo binário/pacote que algum `.qml`/`.sh`/`.py` do repo invoca, direta ou
indiretamente (achada varrendo `exec(`/`command:`/`spawn-sh` em todo o projeto), separada em
obrigatório vs. por recurso. Se um recurso não te interessa, pode ignorar a linha dele sem quebrar
o resto do shell (cada `Process` falha isolado, só aquele recurso fica inerte).

### Núcleo (obrigatório)
| O quê | Para quê |
|------|----------|
| **[Quickshell](https://quickshell.org)** | runtime QML do shell (Wayland/`wlroots`, Pipewire, DBus, SystemTray, Polkit, Mpris). Comando `qs`. Normalmente compilado da fonte / repositório próprio (não está no `apt`). |
| **[Niri](https://github.com/YaLTeR/niri)** | o compositor; o shell inteiro gira em torno do IPC `niri msg` (`event-stream`, `workspaces`/`windows`/`outputs`, `action spawn-sh`, `focus-*`, `screenshot`, `power-*-monitors`, `load-config-file`). |
| **coreutils / sh / grep / sed / gawk / findutils / procps** | usados o tempo todo em scripts inline (`sh -c`, `find`, `awk`, `sed`, `cat`, `ps`, `pgrep`/`pkill`, `kill`) por praticamente todo serviço — já vêm em qualquer instalação base do Debian. |
| **python3** | interpretador dos dois helpers Python do projeto: o patch do `layout` do niri em `ThemeExport.qml` ([`niriLayoutPatchPy()`](services/ThemeExport.qml)) e o seletor de arquivos/pastas ([`services/portal-pick.py`](services/portal-pick.py), usado pela janela de configurações). Sem `python3` no PATH, os dois recursos pulam silenciosamente. |
| **python3-gi** (PyGObject, módulos `GLib`/`Gio`) | só para o `portal-pick.py` — fala com o `xdg-desktop-portal` via DBus (`Gio.bus_get_sync`). |
| **Uma Nerd Font** | ícones dos cristais/cápsulas/notificações/lançador (`Config.iconFont`). O padrão de fábrica é **JetBrainsMono Nerd Font**, mas qualquer Nerd Font serve — é só trocar `Config.iconFont`/`iconFont` no `settings.json`. |

> Este shell é **específico do Niri** — depende do `niri msg` (event-stream/actions) e do
> comportamento do compositor.

### Por recurso (opcional, mas recomendado)
| Recurso | Precisa de |
|--------|-----------|
| **Áudio** (volume/mudo/dispositivos, `AudioMenu`/`AudioDevices`) | **PipeWire** + **WirePlumber** — via a API nativa `Quickshell.Services.Pipewire`, sem CLI nenhuma (nada de `pactl`/`wpctl`). |
| **Visualizador CAVA** (`cava/`) | **cava** (lido via `cava -p cava.conf`). |
| **Notificações** (toasts) | Quickshell como **único** servidor freedesktop (ver aviso abaixo); **libnotify-bin** (`notify-send`) é usado internamente pelo próprio shell para avisos de lock/idle/tema, além de ser o comando que apps terceiros usam pra notificar. |
| **Foco de janela pela bandeja/notificação** | nenhuma dependência extra — só `niri msg --json windows` + `action focus-window` (já cobertos pelo núcleo). |
| **Bandeja (system tray)** | apps que exponham **StatusNotifierItem** (Discord/Vesktop, Steam…); para tray icons **XEmbed puro** (ex.: launchers de jogos via Proton/Wine) é preciso o proxy **xembedsniproxy** rodando (subido pelo `session.sh`). |
| **Sensores** (`SensorsService` → popups de RAM/temperatura/CPU/VRAM) | nada além de coreutils/awk — lê direto `/sys/class/hwmon` (drivers de kernel `k10temp`/`amdgpu`; ajuste o `case` se a CPU/GPU for outra), `/proc/stat`, `/proc/meminfo` e `/sys/class/drm/card0/device/mem_info_vram_*` (exclusivo do driver `amdgpu`). |
| **Clima** (`WeatherService`, cápsula do topo) | **curl** + rede até `wttr.in`. |
| **Gravação de tela** | **gpu-screen-recorder** (setup único de capability, ver abaixo) + **procps** (`pgrep`/`pkill`, para detectar/parar gravação ativa). |
| **Papel de parede** (`WallpaperService`) | **awww** + **awww-daemon** ([codeberg.org/LGFae/awww](https://codeberg.org/LGFae/awww); não está no `apt`, compile com `cargo`). |
| **Fundo do lock** (blur do wallpaper atual) | **ffmpeg** (filtro `gblur`, além de `scale`/`crop`/`pad` pro enquadramento). |
| **Lançador — modo `/dir`** | **VLC** (abre imagens/vídeos/áudio) e, para PDF, **Zen Browser via Flatpak** (`flatpak run --file-forwarding app.zen_browser.zen`, `flatpak` precisa estar instalado e com o app.zen_browser.zen instalado). |
| **Lançador — modo `/color-picker`** | **grim** (screenshot Wayland) + **slurp** (seleção de ponto na tela) + **ImageMagick** (`magick`/`convert`, lê o pixel) + **wl-clipboard** (`wl-copy`, para copiar o hex/rgb salvo). |
| **Lançador — `Terminal=true`** nos `.desktop` | um terminal (padrão `Config.launcherTerminal` = **kitty**, chamado como `kitty -e <argv>`; trocável no `settings.json`). |
| **Janela de configurações — campos de pasta/imagem** (seletor de arquivo) | **xdg-desktop-portal** + backend **xdg-desktop-portal-gtk** registrado para `org.freedesktop.portal.FileChooser` (o backend `gnome` falha sob Niri, ver `~/.config/xdg-desktop-portal/portals.conf`) — além de python3-gi acima. |
| **Sessão** (`session.sh`, subido pelo `StartupService`) | **blueman-applet** (applet Bluetooth; atualmente comentado no script), **swayidle** + **gtklock** (idle/lock/dpms, via `ext-session-lock-v1`). |
| **Export de temas** (`ThemeExport`, cristal Sistema → engrenagem) | **kitty** (relê tema com `SIGUSR1`) e **Vesktop** como alvos opcionais de tema; **glib2.0-bin**/**libglib2.0-bin** (`gsettings`, chave `org.gnome.desktop.interface` — precisa do schema `gsettings-desktop-schemas`) pra sincronizar `color-scheme`/`accent-color` com libadwaita; **flatpak** + a extensão `org.gtk.Gtk3theme.adw-gtk3-dark` (instalação manual única, ver comando abaixo) pra corrigir o fundo hardcoded do diálogo nativo GTK3 do `xdg-desktop-portal-gtk`; **systemd** (`systemctl --user restart xdg-desktop-portal-gtk.service`) pra recarregar esse backend. Tudo isso é melhor-esforço: os comandos são precedidos de `command -v` e falham silenciosamente se o binário não existir. |

Instalação no Debian (exemplo; nomes podem variar):

```sh
sudo apt install niri cava vlc gpu-screen-recorder pipewire wireplumber \
                 procps coreutils grep sed gawk findutils \
                 python3 python3-gi \
                 swayidle blueman gtklock ffmpeg \
                 libnotify-bin curl \
                 grim slurp imagemagick wl-clipboard \
                 kitty flatpak \
                 xdg-desktop-portal xdg-desktop-portal-gtk \
                 libglib2.0-bin gsettings-desktop-schemas

# gpu-screen-recorder: setup único (o gsr-kms-server precisa de CAP_SYS_ADMIN p/ capturar via KMS):
sudo setcap cap_sys_admin+ep /usr/bin/gsr-kms-server

# awww/awww-daemon (https://codeberg.org/LGFae/awww): NÃO estão no apt, compile com
# `cargo build --release` e instale os dois binários (target/release/{awww,awww-daemon}) no PATH.

# xembedsniproxy: costuma vir no pacote do plasma-workspace (ou lxqt-*/kde) — se não estiver
# no apt como pacote próprio, procure em `apt-file search xembedsniproxy`.

# Zen Browser (modo /dir do lançador, só PDFs):
flatpak install --user flathub app.zen_browser.zen

# adw-gtk3-dark (corrige o diálogo nativo do xdg-desktop-portal-gtk sob paleta escura — opcional):
flatpak install --user flathub org.gtk.Gtk3theme.adw-gtk3-dark

# Quickshell normalmente é compilado / vem de repositório próprio (não do apt).
# Nerd Font: baixe a de sua preferência em https://www.nerdfonts.com/ e instale em
# ~/.local/share/fonts (o padrão de fábrica do Config.iconFont é "JetBrainsMono Nerd Font").
```

### ⚠️ Avisos importantes
- **Só pode haver UM servidor de notificações.** Se `swaync`/`mako`/`dunst` estiver rodando, o
  Quickshell não registra o servidor e os toasts não aparecem (warn `already registered`). Garanta
  que nenhum outro daemon de notificação seja iniciado pelo niri. O `notify-send` (pacote
  `libnotify-bin`) continua **enviando** normalmente.
- **PATH dos processos do compositor pode ser mínimo.** Ferramentas em `~/.cargo/bin` /
  `~/.local/bin` podem não ser achadas por processos lançados pelo niri — por isso a captura e o
  `services/session.sh` estendem o PATH antes de rodar.

---

## ▶️ Rodar

```sh
qs                       # inicia o Quickshell carregando ./shell.qml
pkill quickshell; qs     # reinicia
```

Em uso normal o `qs` é lançado pelo niri (`spawn-at-startup "qs"` no `~/.config/niri/config.kdl`);
ao subir, o próprio `qs` sobe os daemons da sessão (wallpaper, bluetooth, idle-lock) via
`services/session.sh`. Os `console.log` só aparecem se o `qs` for iniciado por um terminal
(ou via `qs log`).

> Inicie o `qs` **de dentro da sessão do niri** — ele precisa herdar `WAYLAND_DISPLAY` e
> `NIRI_SOCKET`; um terminal "pelado" fora da sessão quebra o `niri msg`.

---

## 🎨 Configuração

Não há build nem testes — é QML interpretado. Quase tudo é ajustável sem mexer na lógica:

- **`Config.qml`** — singleton com **todos** os valores: geometria (bola, cristais, ângulos),
  fontes, tempos de animação, áudio, captura, notificações, e os **nomes semânticos** de cor
  (`ball`, `crystal`, `accent`…).
- **`themes/`** — o seletor `Theme.qml` + as paletas (`CrimsonDevil`, `InfernalRose`), a única
  fonte dos hex. O `Config` mapeia semântico → paleta (ex.: `accent: Theme.mauve`).
- **Janela de configurações** (cristal de Sistema) — sobrescreve qualquer valor em runtime
  (persistido em `settings.json`) e regenera os temas dos apps externos.

Os cristais são **data-driven** em `shell.qml` (`menuItems`): adicionar/remover itens reorganiza o
anel. Um item pode ter `command: [argv]` (exec direto) ou `spawn: "cmd"` (lançado pelo compositor
via `niri msg action spawn-sh`, para apps gráficos), além de flags especiais (`audio`, `tray`,
`settings`, `launcher`).

---

## 🗂️ Estrutura

Os `.qml` são organizados em subpastas por papel. **Atenção:** a auto-descoberta do Quickshell por
nome só vale na **raiz**; arquivos em subpastas precisam de `import "root:/<pasta>"` (até os
singletons). Detalhes no [CLAUDE.md](CLAUDE.md).

```
shell.qml        ponto de entrada (liga serviços, dados e janelas por monitor)
Config.qml       config central (singleton) — todos os valores ajustáveis
themes/          Theme (seletor) + paletas CrimsonDevil e InfernalRose (os hex)
services/        NiriService, AudioService, CaptureService, MediaService, WeatherService,
                 NotificationService, StartupService, IdleService, LauncherService,
                 Settings, ThemeExport + session.sh
cava/            CavaService, CavaWindow, CavaBars, CavaRing + cava.conf
windows/         ShellWindow (UI interativa), NotificationWindow (toasts), SettingsWindow,
                 LauncherWindow (lançador)
ui/              MenuBall, Crystal, GothicCorners, AudioMenu, AudioDevices, TrayMenu,
                 SettingsField, Capsule, TopCapsules
```

- **Por monitor** (`Variants`): `CavaWindow` (camada de baixo) + `ShellWindow` (camada de cima) +
  `TopCapsules` (cápsulas do topo). `NotificationWindow`, `SettingsWindow` e `LauncherWindow` são
  únicas (monitor focado).
- **Inicialização da sessão centralizada no qs:** `StartupService` (chamado pelo `shell.qml`) sobe
  wallpaper / bluetooth / idle-lock via `services/session.sh` (pedido ao compositor por
  `niri msg action spawn-sh`).

Detalhes de arquitetura e as **peculiaridades de Niri + Quickshell** (IPC, `spawn-sh`, processos,
armadilhas de QML, imports `root:/`) estão no **[CLAUDE.md](CLAUDE.md)**.
