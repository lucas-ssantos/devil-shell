# Bola — shell Quickshell para MangoWC

Uma "barra" não-convencional para o compositor Wayland **[MangoWC](https://mangowm.github.io/)**
(base dwl/wlroots), escrita em **QML** sobre o **[Quickshell](https://quickshell.org)**.

Em vez de uma barra reta, é uma **bola** ancorada no centro-inferior de cada monitor. Em hover/clique
ela sobe e abre um **menu radial de pétalas**; os **workspaces** aparecem como pontos dentro da bola;
e há um **visualizador de áudio (CAVA)** ao fundo, no estilo do [Cavasik](https://github.com/TheWisker/Cavasik)
(espectro suave preenchido na barra inferior + um círculo pulsante ao redor da bola).

> Tudo é hot-reloaded: salvar qualquer `.qml` recarrega o shell na hora.

---

## ✨ Recursos

- **Bola central** com o número do workspace atual / sigla do layout e um **anel de pontos** dos
  workspaces (clique troca; scroll sobre a bola troca com wrap 1↔N — no monitor certo).
- **Menu radial de pétalas** (data-driven, reorganiza sozinho). Configuração atual (1ª → 7ª):
  - **1ª — Layout:** seletor de layout do Mango (lista curvada; clique aplica via `mmsg`).
  - **2ª / 3ª — livres:** pétalas de exemplo (sem ação).
  - **4ª — Lançador:** abre o `rofi -show drun`.
  - **5ª — Captura:** printscreen (área, com editor swappy) e gravação de tela (monitor inteiro).
  - **6ª — Áudio:** mudo de saída/entrada + sliders de volume (scroll ajusta);
    **clique direito** abre o **seletor de dispositivo** (saída/entrada).
  - **7ª — Bandeja (system tray):** ícones dos apps; **esquerdo** foca a janela, **direito** abre o
    menu do app (menu estilizado no tema).
- **Notificações** (toast no topo-centro do monitor focado) — o Quickshell atua como servidor
  de notificações freedesktop.
- **Tema centralizado** (Catppuccin Mocha) e **toda** a customização num só lugar.

---

## 📦 Dependências

### Núcleo (obrigatório)
| O quê | Para quê |
|------|----------|
| **Quickshell** | runtime QML do shell (com suporte a Wayland, Pipewire, DBus). Comando `qs`. |
| **MangoWC** + `mmsg` | o compositor; o shell usa o IPC `mmsg` para workspaces, layouts, foco e `spawn`. |
| **Symbols Nerd Font** | ícones das pétalas de áudio/captura/bandeja (`Config.iconFont`). |

> Este shell é **específico do MangoWC** — depende do `mmsg` e do comportamento do compositor.

### Por recurso (opcional, mas recomendado)
| Recurso | Precisa de |
|--------|-----------|
| **Áudio** (volume/mudo/dispositivos) | **PipeWire** (+ WirePlumber) |
| **Visualizador CAVA** | **cava** (lido via `cava -p cava.conf`) |
| **Lançador** | **rofi** (`rofi -show drun`) |
| **Captura — print** | **wayfreeze**, **slurp**, **grim**, **swappy** + scripts em `~/.config/mango/scripts/` |
| **Captura — gravação** | **wf-recorder** e **procps** (`pgrep`, para detectar gravação ativa) |
| **Bandeja** | apps que exponham **StatusNotifierItem** (Discord/Vesktop, Steam…) |
| **Notificações** | Quickshell como **único** servidor de notificações (ver aviso abaixo) |

Instalação no Debian (exemplo; nomes podem variar):

```sh
sudo apt install cava rofi grim slurp swappy wf-recorder pipewire wireplumber procps
cargo install wayfreeze          # wayfreeze costuma vir do cargo (~/.cargo/bin)
# Quickshell e MangoWC normalmente são compilados / vêm de repositório próprio (não do apt).
# Symbols Nerd Font: baixe de https://www.nerdfonts.com/ e instale em ~/.local/share/fonts
```

### ⚠️ Avisos importantes
- **Só pode haver UM servidor de notificações.** Se `dunst`/`mako`/`swaync` estiver rodando, o
  Quickshell não registra o servidor e os toasts não aparecem (warn `already registered`). Desative
  o outro daemon. O `dunstify`/`notify-send` continuam **enviando** normalmente.
- **PATH do mango é mínimo** (`/usr/local/bin:/usr/bin:/bin:/opt/zig…`). Ferramentas em
  `~/.cargo/bin` / `~/.local/bin` (ex.: `wayfreeze`) não são achadas por processos que o mango
  lança — por isso a captura estende o PATH antes de rodar.
- O autostart roda como shell **não-login** (não lê `~/.bashrc`/`~/.profile`); para o `qs` e afins
  serem encontrados, o `~/.config/mango/autostart.sh` define o PATH explicitamente.

---

## ▶️ Rodar

```sh
qs                       # inicia o Quickshell carregando ./shell.qml
pkill quickshell; qs     # reinicia
```

Em uso normal o `qs` é lançado pelo `~/.config/mango/autostart.sh` (junto com o resto da sessão).
Os `console.log` só aparecem se o `qs` for iniciado por um terminal.

> Inicie o `qs` **de dentro da sessão do mango** — ele precisa herdar `WAYLAND_DISPLAY` e
> `MANGO_INSTANCE_SIGNATURE`; um terminal "pelado" fora da sessão quebra o `mmsg`.

---

## 🎨 Configuração

Não há build nem testes — é QML interpretado. Quase tudo é ajustável sem mexer na lógica:

- **`Config.qml`** — singleton com **todos** os valores: geometria (bola, pétalas, ângulos),
  fontes, tempos de animação, áudio, captura, notificações, e os **nomes semânticos** de cor
  (`ball`, `petal`, `accent`…).
- **`Theme.qml`** — a **paleta** (Catppuccin Mocha: `base`, `text`, `mauve`, `red`, `surface0`…),
  a única fonte dos hex. Trocar de tema = editar só este arquivo (ou apontar os nomes para outra
  paleta). O `Config` mapeia semântico → paleta (ex.: `accent: Theme.mauve`).

As pétalas são **data-driven** em `shell.qml` (`menuItems`): adicionar/remover itens reorganiza o
anel. Um item pode ter `command: [argv]` (exec direto) ou `spawn: "cmd"` (lançado pelo compositor,
para apps gráficos), além de flags especiais (`audio`, `capture`, `tray`).

---

## 🗂️ Estrutura

- **Entrada:** `shell.qml` (liga serviços, dados e as janelas por monitor).
- **Serviços (singletons):** `MangoLayout` (estado do mango), `AudioService` (PipeWire),
  `CaptureService` (print/gravação), `CavaService` (níveis do cava), `NotificationService`.
- **Janelas (por monitor):** `CavaWindow` (camada de baixo, atrás dos apps) e `ShellWindow`
  (camada de cima, a UI interativa). `NotificationWindow` é única (monitor focado).
- **Visual:** `MenuBall`, `Petal`, `LayoutMenu`, `AudioMenu`, `AudioDevices`, `TrayMenu`,
  `GothicCorners`, `CavaBars` (espectro de fundo) e `CavaRing` (círculo da bola).
- **Config:** `Config.qml`, `Theme.qml`, `cava.conf`.

Detalhes de arquitetura e as **peculiaridades de MangoWC + Quickshell** (IPC, `spawn`, processos,
armadilhas de QML) estão no **[CLAUDE.md](CLAUDE.md)**.
