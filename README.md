# Devil Shell — shell Quickshell para Niri

Uma "barra" não-convencional para o compositor Wayland **[Niri](https://github.com/YaLTeR/niri)**
(tiling rolável), escrita em **QML** sobre o **[Quickshell](https://quickshell.org)**.

Em vez de uma barra reta, é uma **bola** ancorada no centro-inferior de cada monitor. Em hover/clique
ela sobe e abre um **menu radial de pétalas**; os **workspaces** aparecem como pontos dentro da bola;
e há um **visualizador de áudio (CAVA)** ao fundo, no estilo do [Cavasik](https://github.com/TheWisker/Cavasik)
(espectro suave preenchido na barra inferior + um círculo pulsante ao redor da bola).

> Tudo é hot-reloaded: salvar qualquer `.qml` recarrega o shell na hora.

---

## ✨ Recursos

- **Bola central** com o número do workspace atual e um **anel de pontos** dos workspaces
  (clique troca; scroll sobre a bola troca com wrap 1↔N — no monitor certo).
- **Menu radial de pétalas** (data-driven, reorganiza sozinho). Configuração atual (1ª → 4ª):
  - **1ª — Sistema:** configurações gerais do shell (janela modal), gravação de tela
    (monitor inteiro) e toggle de inibição do lock/idle.
  - **2ª — Lançador:** lançador **próprio** (sem rofi), também acessível por `Mod+D`
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

Overlay central no monitor focado (`Mod+D`, pétala do menu, ou `qs ipc call launcher toggle`).
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

### Núcleo (obrigatório)
| O quê | Para quê |
|------|----------|
| **Quickshell** | runtime QML do shell (com suporte a Wayland, Pipewire, DBus). Comando `qs`. |
| **Niri** | o compositor; o shell usa o IPC `niri msg` para workspaces, foco, screenshot e `spawn-sh`. |
| **Symbols Nerd Font** | ícones das pétalas de áudio/captura/bandeja (`Config.iconFont`). |

> Este shell é **específico do Niri** — depende do `niri msg` (event-stream/actions) e do
> comportamento do compositor.

### Por recurso (opcional, mas recomendado)
| Recurso | Precisa de |
|--------|-----------|
| **Áudio** (volume/mudo/dispositivos) | **PipeWire** (+ WirePlumber) |
| **Visualizador CAVA** | **cava** (lido via `cava -p cava.conf`) |
| **Lançador — modo `/dir`** | **VLC** (abre imagens e vídeos); o lançador em si não precisa de nada externo |
| **Gravação de tela** | **gpu-screen-recorder** e **procps** (`pgrep`, para detectar gravação ativa) |
| **Bandeja** | apps que exponham **StatusNotifierItem** (Discord/Vesktop, Steam…) |
| **Notificações** | Quickshell como **único** servidor de notificações (ver aviso abaixo) |
| **Sessão** (via `session.sh`) | **swaybg**, **blueman-applet**, **swayidle**, **swaylock-effects** |

Instalação no Debian (exemplo; nomes podem variar):

```sh
sudo apt install niri cava vlc gpu-screen-recorder pipewire wireplumber procps \
                 swaybg swayidle blueman
# gpu-screen-recorder: setup único (o gsr-kms-server precisa de CAP_SYS_ADMIN p/ capturar via KMS):
sudo setcap cap_sys_admin+ep /usr/bin/gsr-kms-server
# Quickshell normalmente é compilado / vem de repositório próprio (não do apt).
# Symbols Nerd Font: baixe de https://www.nerdfonts.com/ e instale em ~/.local/share/fonts
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

- **`Config.qml`** — singleton com **todos** os valores: geometria (bola, pétalas, ângulos),
  fontes, tempos de animação, áudio, captura, notificações, e os **nomes semânticos** de cor
  (`ball`, `petal`, `accent`…).
- **`themes/`** — o seletor `Theme.qml` + as paletas (`CrimsonDevil`, `InfernalRose`), a única
  fonte dos hex. O `Config` mapeia semântico → paleta (ex.: `accent: Theme.mauve`).
- **Janela de configurações** (pétala de Sistema) — sobrescreve qualquer valor em runtime
  (persistido em `settings.json`) e regenera os temas dos apps externos.

As pétalas são **data-driven** em `shell.qml` (`menuItems`): adicionar/remover itens reorganiza o
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
ui/              MenuBall, Petal, GothicCorners, AudioMenu, AudioDevices, TrayMenu,
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
