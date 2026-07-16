# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é

Configuração [Quickshell](https://quickshell.org) (QML) para o compositor Wayland **Niri**
(tiling rolável) no Debian Sid. Não é uma "barra" tradicional: é uma **bola** ancorada no centro
inferior de cada monitor que, em hover/clique, abre um menu radial de **pétalas** (sistema,
gravação, áudio…), mostra os workspaces como pontos dentro da bola e tem um visualizador
de áudio **CAVA** ao fundo. Toda a configuração é hot-reloaded pelo Quickshell ao salvar.

Não há build, lint ou testes — é QML interpretado. Os comentários do código são em **português**;
mantenha esse padrão.

## Rodar / desenvolver

```sh
qs                 # inicia o Quickshell carregando ./shell.qml (config padrão do usuário)
pkill quickshell; qs   # reinicia
```

- **Hot reload:** salvar qualquer `.qml` recarrega automaticamente. Um erro de QML aborta o
  carregamento inteiro (a tela some); cheque a saída do terminal.
- **Glifos Nerd Font em strings:** os ícones do `Config.qml` (`iconOutput`, `iconConfig`, `iconRecord`…)
  são caracteres da Área de Uso Privado (ex.: U+F028, U+F013). Editores/ferramentas (cat -v, alguns
  diffs) os mostram como vazios `""` — eles ESTÃO lá. Ao reescrever o `Config.qml`, NÃO apague o
  conteúdo das aspas (já aconteceu de perder todos e os ícones "sumirem"). Para conferir os
  codepoints reais: `python3 -c "..."` lendo o arquivo, ou recupere do git (`git show <commit>:Config.qml`).
- **Logs (`console.log`) só aparecem se o `qs` for iniciado por um terminal.** Em uso normal ele
  é lançado pelo niri (`spawn-at-startup "qs"` no `~/.config/niri/config.kdl`), sem terminal
  visível. Para ver os logs do qs em execução: `qs log` (lê o `.qslog` da instância ativa).
- **Inicie o `qs` de dentro da sessão do niri.** Ele precisa herdar `WAYLAND_DISPLAY` e
  `NIRI_SOCKET` do ambiente do compositor; um terminal "pelado" fora da sessão quebra
  o `niri msg`.
- **Smoke-test sem mexer na instância ativa:** `qs -p ~/.config/quickshell/shell.qml` carrega uma
  2ª instância (janelas duplicadas por alguns segundos). Erros de tipo/import aparecem no log
  imediatamente. O aviso `Could not register notification server … already registered` é ESPERADO
  (a instância ativa já segura o `org.freedesktop.Notifications`), não é erro de reorganização.

## ⚠️ Peculiaridades Niri + Quickshell (leia antes de mexer em IPC/processos)

### IPC com o niri: `niri msg`
- `niri msg --json event-stream` — stream JSON (um evento por linha, chave única = tipo do
  evento: `WorkspacesChanged`, `WorkspaceActivated`, `WorkspaceUrgencyChanged`, `WindowsChanged`,
  `WindowOpenedOrChanged`, `WindowClosed`…). Base do [NiriService.qml](services/NiriService.qml),
  que deriva `monitors` (por output, com os workspaces como "tags" 1-based via `idx`).
- `niri msg --json workspaces|windows|outputs` — one-shot. Janelas têm `app_id`/`title`/`id`
  (usado pelo foco a partir da bandeja: `focus-window --id <id>`).
- `niri msg action focus-workspace <idx>` — age no monitor FOCADO; para trocar workspace de outro
  monitor, foque-o antes com `niri msg action focus-monitor <nome>` (aceita o nome direto, ex.: `DP-2`).
- `niri msg action spawn-sh -- '<linha de shell>'` — pede ao compositor para **lançar** um
  processo (a linha é interpretada pela shell — sem escaping manual de argv).
- Ações úteis já usadas: `screenshot` (UI nativa de print), `power-off-monitors` /
  `power-on-monitors` (dpms no swayidle), `quit --skip-confirmation` (sair da sessão).
- Workspaces do niri são **dinâmicos por monitor** (sempre há um vazio no fim); o anel de pontos
  reflete isso (o nº de pontos varia).

### Lançar ferramentas Wayland (swaybg/blueman/swayidle/gpu-screen-recorder): use `niri msg action spawn-sh`
Apps gráficos Wayland lançados como filhos do `Process` do Quickshell podem não receber um
ambiente Wayland utilizável. A solução do projeto é fazer o **próprio compositor** lançar o
comando via `niri msg action spawn-sh` (igual a um keybind) — aí o ambiente está correto. O
`niri msg` em si funciona pelo `Process` porque usa o **socket do niri** (`NIRI_SOCKET`), não o
Wayland. Ver [CaptureService.qml](services/CaptureService.qml) (gravação) e
[StartupService.qml](services/StartupService.qml) (daemons da sessão).

### O PATH dos processos do compositor pode ser mínimo
Pode **não** incluir `~/.cargo/bin` nem `~/.local/bin`. Binários instalados ali "somem" e scripts
que dependem deles travam silenciosamente. Por isso o `spawn()` do `CaptureService` e o
[session.sh](services/session.sh) prefixam `export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$PATH"`.

### `Process` (Quickshell.Io)
- **One-shot:** use `proc.exec([argv])`. Re-rodar via `proc.running = true` num Process já
  finalizado é frágil — prefira `exec()`.
- **Long-running:** `command:` declarativo + `running: true` (ver NiriService/CavaService).
- `Process.exec` **herda o ambiente** do Quickshell (logo o `niri msg` acha o socket).
  `Quickshell.execDetached` **não** herda — não o use para comandos que dependem de env.
- `Process` precisa de `import Quickshell.Io`; `Timer`/`Canvas` precisam de `import QtQuick`.

## Estrutura de pastas e o import `root:/` (leia antes de mover arquivos)

Os `.qml` ficam organizados em subpastas por papel:

```
shell.qml             ponto de entrada (raiz)
Config.qml            config central, singleton (raiz) — lê overrides do Settings
settings.json         overrides do usuário (gerado/atualizado em runtime pela SettingsWindow)
settings.default.json "padrão de fábrica" lido pelo botão Restaurar padrão
themes/               Theme (seletor) + paletas (CrimsonDevil, InfernalRose)
services/             singletons/escopos não-visuais (niri, áudio, captura, mídia, clima,
                      notificações, StartupService, IdleService, LauncherService,
                      WallpaperService (swaybg, modo /bg), Settings, ThemeExport) + session.sh
cava/                 tudo do visualizador CAVA (serviço, janela, barras, anel) + cava.conf
windows/              janelas interativas: ShellWindow, NotificationWindow, SettingsWindow,
                      LauncherWindow (lançador próprio)
ui/                   componentes visuais "burros": MenuBall, Petal, GothicCorners, AudioMenu,
                      AudioDevices, TrayMenu, SettingsField, Capsule, TopCapsules
```

⚠️ **A auto-descoberta do Quickshell por nome só vale para a PASTA RAIZ.** Um arquivo na raiz
(`Config.qml`) é visível por toda parte sem import; um arquivo numa **subpasta NÃO** é — nem
componentes, nem singletons. Para usar um tipo de outra pasta, **importe a pasta** com o esquema
`root:/` (a raiz da config):

- `import "root:/services"` → expõe `NiriService`, `AudioService`, `CaptureService`, `StartupService`, …
- `import "root:/ui"`, `import "root:/cava"`, `import "root:/windows"`, `import "root:/themes"`
- `import "root:/"` → expõe os tipos da **raiz** (na prática, `Config`).
- Arquivos na **mesma pasta** se enxergam sem import (regra normal do QML).

Sintaxe verificada no Quickshell 0.3.0: tanto componentes quanto `pragma Singleton` resolvem por
`import "root:/<pasta>"`. **Sem o import, um singleton de subpasta dá `ReferenceError: X is not defined`.**
Ao **mover** um arquivo entre pastas, reveja os imports dele E de quem o usa.

## Arquitetura

`qs` carrega **[shell.qml](shell.qml)** (ponto de entrada), que só conecta as peças:
1. **Serviços** (singletons/scopes globais em `services/` e `cava/`):
   [NiriService.qml](services/NiriService.qml) (estado do niri), [AudioService.qml](services/AudioService.qml)
   (Pipewire), [CaptureService.qml](services/CaptureService.qml) (gravação de tela),
   [CavaService.qml](cava/CavaService.qml) (níveis do cava), [MediaService.qml](services/MediaService.qml) (MPRIS),
   [WeatherService.qml](services/WeatherService.qml) (wttr.in),
   [NotificationService.qml](services/NotificationService.qml) (servidor freedesktop),
   [StartupService.qml](services/StartupService.qml) (sobe os daemons da sessão),
   [IdleService.qml](services/IdleService.qml) (inibe/reativa lock/idle),
   [LauncherService.qml](services/LauncherService.qml) (lançador: apps/uso/arquivos/processos/calc),
   [Settings.qml](services/Settings.qml) (overrides do usuário, persistidos), [ThemeExport.qml](services/ThemeExport.qml)
   (regenera os temas dos apps externos).
2. **Dados data-driven:** `menuItems` (pétalas; flags `audio`/`tray`/`settings`/`launcher`
   marcam pétalas especiais). Adicionar/remover itens reorganiza o anel automaticamente. (A pétala
   de Sistema (`settings`) tem 3 seções: configurações em cima, gravar/parar tela no meio,
   toggle de lock embaixo.)
3. **Uma instância por monitor** via `Variants { model: Quickshell.screens }`: uma
   [CavaWindow.qml](cava/CavaWindow.qml) (camada **Bottom**, atrás dos apps, click-through), uma
   [ShellWindow.qml](windows/ShellWindow.qml) (camada **Top**, a UI interativa) e uma
   [TopCapsules.qml](ui/TopCapsules.qml) (cápsulas de mídia/temperatura no topo). As janelas únicas
   (monitor focado) são a [NotificationWindow.qml](windows/NotificationWindow.qml), a
   [SettingsWindow.qml](windows/SettingsWindow.qml) (overlay modal de configurações) e a
   [LauncherWindow.qml](windows/LauncherWindow.qml) (lançador próprio).

### Inicialização da sessão centralizada no Quickshell
Os daemons da sessão (wallpaper, applet do bluetooth, idle/lock/dpms) rodam de **dentro do quickshell**:
- [StartupService.qml](services/StartupService.qml) (singleton) é chamado uma vez por `shell.qml`
  (`Component.onCompleted: StartupService.start()`). Ele pede ao compositor (via `niri msg action
  spawn-sh`) para rodar [session.sh](services/session.sh), que sobe `blueman-applet` e
  `swayidle` (com guardas `pgrep` para não duplicar a cada reload, e `setsid` para sobreviverem).
- O **swaybg** sobe pelo [WallpaperService.qml](services/WallpaperService.qml)
  (`WallpaperService.init()` no `shell.qml`, no boot e a cada reload): compara o argv do swaybg em
  execução (`pgrep -xa`) com a seleção persistida do modo `/bg` do lançador e (re)aplica só se
  divergir (todos os monitores ou um wallpaper por monitor; carrossel opcional).
  Trocar wallpaper relança o swaybg (sobe o novo, depois mata o velho — sem frame preto).
- O próprio `qs` é lançado pelo niri: `spawn-at-startup "qs"` no `~/.config/niri/config.kdl`.
  Certifique-se de que nenhum outro daemon de notificação (swaync/mako/dunst) suba antes do qs,
  senão o qs não registra o servidor de notificações.
- **Acoplamento aceito:** se o qs não carregar, o `StartupService` não roda → sem wallpaper/idle nessa
  sessão. (Trade-off escolhido em prol da centralização.) Um futuro caminho 100% QML seria
  `IdleMonitor` + `WlSessionLock` no lugar do swayidle/swaylock.

### ShellWindow é o "controlador"
Concentra **geometria, estado e TODA a lógica de interação**; os componentes visuais são burros e
recebem o controlador na propriedade `ctx`. Pontos-chave:
- **Um único `MouseArea` + um `WheelHandler`** no topo fazem **hit-testing geométrico** em vez de
  MouseAreas por elemento (isso resolveu instabilidades de hover): `petalAt` (angular), `dotAt`
  (distância), `overBallAt`, `petalSectionAt` (radial, para pétalas multi-botão), `audioSliderAt`.
- **Hover com debounce** (`hoverOpen` + `hoverCloseTimer`) para evitar o loop de feedback
  máscara↔abertura que colapsava o menu.
- **Máscara de input** (`mask: Region`) muda com `open`: fechado só a bola é clicável; aberto a
  região central inteira; o resto é click-through.
- **Scroll por região:** sobre a bola troca workspace (com wrap 1↔N); na região das pétalas gira o
  anel; sobre um slider de áudio ajusta o volume.
- Estado central: `pinned`/`dismissed`/`hoverOpen` (→ `open`), `hoverIndex`, `selectedIndex`,
  `audioMode`, `petalSection`, `petalRotation`.
- `monData`/`tags`/`activeTag` derivam de `niri.monitorByName(modelData.name)` — `modelData.name`
  (a screen) **bate com o nome do output no niri** (ex.: `DP-2`, `HDMI-A-1`), o que também é usado
  para gravar um monitor específico (`gpu-screen-recorder -w <name>`).

### Componentes visuais (recebem `ctx`)
[MenuBall.qml](ui/MenuBall.qml) (bola: nº do workspace / anel de pontos),
[Petal.qml](ui/Petal.qml) (uma pétala; renderiza ícone único, ou painel multi-seção conforme as flags
do item: áudio 3 seções, sistema 3 seções, bandeja N seções),
[AudioMenu.qml](ui/AudioMenu.qml) (sliders), [AudioDevices.qml](ui/AudioDevices.qml)
(seletor de dispositivo), [TrayMenu.qml](ui/TrayMenu.qml) (menu do item da bandeja),
[SettingsField.qml](ui/SettingsField.qml) (uma linha editável da janela de configurações: cor/número/texto/seletor/toggle),
[GothicCorners.qml](ui/GothicCorners.qml) (filetes côncavos `Canvas` que fundem a bola na barra fina),
[Capsule.qml](ui/Capsule.qml)/[TopCapsules.qml](ui/TopCapsules.qml) (cápsulas retráteis do topo),
[CavaRing.qml](cava/CavaRing.qml)/[CavaBars.qml](cava/CavaBars.qml) (visualizador radial/linear).

### Config centralizada + Tema + overrides em runtime
**[Config.qml](Config.qml)** é um singleton (na raiz) com TODOS os valores ajustáveis (geometria,
fontes, tempos, ângulos das pétalas, áudio, gravação, clima) e os nomes **semânticos** de cor
(`ball`, `petal`, `accent`…). Cada property segue o padrão `Settings.get("nome", <padrão>)`: o literal
é o PADRÃO, e o usuário pode sobrescrever em runtime pela janela de configurações (ver abaixo).
**[Theme.qml](themes/Theme.qml)** é o **seletor de tema**: escolhe qual paleta crua vai para o shell e
qual para o CAVA — agora pelo nome guardado no Settings (`themeShell`/`themeCava`), e cada cor crua aceita
override `pal_<nome>`. As paletas (a única fonte dos hex) são [CrimsonDevil.qml](themes/CrimsonDevil.qml)
e [InfernalRose.qml](themes/InfernalRose.qml) (mesmos nomes: `base`, `text`, `mauve`, `red`, `surface0`,
`cavaInner`…). Regra do projeto: **nada de valores hardcoded na lógica** — cor nova vem de uma paleta,
exposta por `Theme`, nomeada em `Config`, e os componentes usam `Config.<algo>` (nunca hex direto).
`Config` importa `root:/themes` e `root:/services`; `Theme` importa `root:/services` (mútuo, sem ciclo de
init — `Settings` não toca `Theme`/`ThemeExport` na construção, só em timers/funções).

### Lançador próprio (pétala "Lançador" / Mod+D)
Substitui o rofi. [LauncherService.qml](services/LauncherService.qml) tem a lógica (não-visual);
[LauncherWindow.qml](windows/LauncherWindow.qml) é a view (overlay no monitor focado, mesmo padrão
da SettingsWindow). O **modo** deriva do texto digitado: apps (padrão; vazio = "mais usados" pela
contagem em `launcher-usage.json`, que está no .gitignore), `=expr` calculadora, `/dir` navegador
de mídia → VLC, `/proc` processos (ordena nome/PID/RAM/CPU; Enter TERM, Shift+Enter KILL),
`/bg` escolhedor de wallpaper ([WallpaperService.qml](services/WallpaperService.qml); chips de alvo
"Ambos"/por monitor — Tab alterna, Shift+Enter aplica sem fechar — + chip do carrossel; pasta e
opções no grupo "Papel de parede" das configurações), `/reload` (`Quickshell.reload(false)`),
`/config` (`Settings.open`). Pontos de atenção:
- Apps vêm de `DesktopEntries.applications.values` (API do Quickshell); o lançamento usa
  `entry.command` (argv sem field codes) via **`niri msg action spawn-sh`** — NÃO usar
  `entry.execute()` (execDetached não herda o env Wayland). `Terminal=true` → `launcherTerminal -e`.
- A calculadora é um **parser recursivo próprio** — não trocar por `eval` (o eval do QML enxerga o
  escopo global: `Settings`, singletons…). Testes de referência: ver histórico do PR/commit.
- **Não nomear função de IpcHandler de `show`**: `qs ipc call launcher show` colide com o
  subcomando `qs ipc show` do CLI e só imprime o help. Usar `toggle`/`open`/`close`.
- Keybind: `Mod+D { spawn "qs" "ipc" "call" "launcher" "toggle"; }` no config.kdl do niri.

### Configurações em runtime + export de temas (pétala "Sistema")
A pétala de Sistema tem 2 seções: **engrenagem** (cima) abre a [SettingsWindow.qml](windows/SettingsWindow.qml)
(overlay modal central com TODAS as opções por grupo, via schema → [SettingsField.qml](ui/SettingsField.qml));
**lâmpada** (baixo) inibe/reativa o lock/idle ([IdleService.qml](services/IdleService.qml)).
- **[Settings.qml](services/Settings.qml)** (singleton) guarda só os overrides num JSON
  (`~/.config/quickshell/settings.json`, via `FileView`). `get/set/unset/reset`; reatribui o mapa inteiro a
  cada `set` para os bindings de `Config`/`Theme` (que leem `get()`) reavaliarem. `reset()` recarrega
  `settings.default.json` (o "padrão de fábrica"; edite-o para mudar o que "Restaurar padrão" faz).
- **[ThemeExport.qml](services/ThemeExport.qml)** regenera os temas dos apps **externos** a partir da
  paleta efetiva (`Theme.*`), com **backup** (`<arquivo>.bak-<ts>`) e **reload ao vivo**. Disparado
  automaticamente quando muda `pal_*`/`theme*` (debounce no Settings) e pelo botão "Exportar temas".
  Alvos (escreve nos MESMOS arquivos que os apps já incluem → não mexe noutras linhas): **kitty**
  (`themes/crimson-devil.conf`, `include` no kitty.conf), **rofi** (`themes/crimson-devil.rasi`, `@theme`),
  **niri** (`devil-shell/theme.kdl`, `include` no config.kdl — o niri faz merge de blocos `layout`
  duplicados; as cores de fábrica do focus-ring/border ficam COMENTADAS no config.kdl p/ não competirem
  → reload via `niri msg action load-config-file`), **vesktop** (`themes/devil-shell.css`, habilitar 1x)
  e **swaylock** (`config`).
  kitty recarrega com `pkill -USR1 kitty`; rofi/vesktop/swaylock pegam no próximo uso. A escrita usa
  `Qt.btoa` (base64) num único `sh -c` p/ evitar escaping → mantenha os comentários gerados em ASCII.
  Export manual pela CLI: `qs ipc call theme exportAll` (IpcHandler no ThemeExport; o singleton é
  instanciado no boot por `ThemeExport.init()` no `shell.qml`, senão o alvo IPC não existe).

## Convenções e armadilhas de QML/Quickshell

- **Auto-descoberta só na RAIZ; subpastas pedem `import "root:/<pasta>"`** (ver "Estrutura de pastas"
  acima). Na raiz, um arquivo vira componente pelo nome (`Petal { }`) e `pragma Singleton` + `Singleton { }`
  o torna global pelo nome do arquivo (`Config.x`). Em subpasta, isso só vale APÓS importar a pasta.
- **Colisão `id` × `property`:** uma `property var x` com o mesmo nome de um `id: x` faz o lado
  direito resolver para a property (→ `undefined`). Por isso os componentes usam `property var ctx`
  (e o id do serviço em shell.qml é `niriSvc`, não `niri`). Em `Canvas.onPaint`, o contexto 2D é
  nomeado `g` (não `ctx`) para não colidir.
- **`Behavior on X`** exige que `X` **não** seja `readonly`.
- **`required property var modelData`** nos delegates de `Repeater` evita o shadow do `modelData`
  da screen (`PanelWindow`) em Qt6.
- **Singletons são lazy:** só instanciam quando referenciados. Por isso o `StartupService` é
  acionado explicitamente (`StartupService.start()` no `Component.onCompleted` do `shell.qml`).
- Use bindings/guards defensivos para o estado do niri durante a inicialização
  (`if (!niri || !modelData) return null`), pois os primeiros frames chegam antes do primeiro
  evento do `event-stream`.

## Verificar contra o sistema ao vivo

Antes de assumir uma API do niri/Pipewire, confirme no compositor rodando:

```sh
niri msg --json workspaces    # ids/idx/outputs/foco reais
niri msg --json outputs       # nomes e posições dos monitores
niri msg version
niri msg action spawn-sh -- 'echo $PATH > /tmp/p'   # inspecionar o ambiente do spawn
```

Scripts: daemons da sessão em [services/session.sh](services/session.sh) (swaybg/blueman/swayidle,
disparado pelo StartupService). Gravação de tela usa `gpu-screen-recorder` (pétala de Sistema;
setup único: `sudo setcap cap_sys_admin+ep /usr/bin/gsr-kms-server` — sem isso, e sem pkexec,
a captura KMS falha; e `pgrep`/`pkill -x` usam o comm truncado `gpu-screen-reco`). Bootstrap da sessão: `spawn-at-startup` no `~/.config/niri/config.kdl`
(lança o qs; garanta que nenhum swaync/mako suba junto).
