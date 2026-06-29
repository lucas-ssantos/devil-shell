# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é

Configuração [Quickshell](https://quickshell.org) (QML) para o compositor Wayland **MangoWC**
(base dwl/wlroots) no Debian Sid. Não é uma "barra" tradicional: é uma **bola** ancorada no centro
inferior de cada monitor que, em hover/clique, abre um menu radial de **pétalas** (seletor de
layout, captura, áudio…), mostra os workspaces como pontos dentro da bola e tem um visualizador
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
- **Logs (`console.log`) só aparecem se o `qs` for iniciado por um terminal.** Em uso normal ele
  é lançado pelo `~/.config/mango/scripts/autostart.sh` (`pgrep -x qs || setsid qs &`), sem
  terminal visível. Para ver os logs do qs em execução: `qs log` (lê o `.qslog` da instância ativa).
- **Inicie o `qs` de dentro da sessão do mango.** Ele precisa herdar `WAYLAND_DISPLAY` e
  `MANGO_INSTANCE_SIGNATURE` do ambiente do compositor; um terminal "pelado" fora da sessão quebra
  o `mmsg` (erro `connect: No such file or directory`).
- **Smoke-test sem mexer na instância ativa:** `qs -p ~/.config/quickshell/shell.qml` carrega uma
  2ª instância (janelas duplicadas por alguns segundos). Erros de tipo/import aparecem no log
  imediatamente. O aviso `Could not register notification server … already registered` é ESPERADO
  (a instância ativa já segura o `org.freedesktop.Notifications`), não é erro de reorganização.

## ⚠️ Peculiaridades MangoWC + Quickshell (leia antes de mexer em IPC/processos)

Estas são as armadilhas que mais custaram tempo. Respeite-as.

### IPC com o mango: `mmsg`
Interface **nova**: `get` (one-shot), `watch` (stream), `dispatch` (ações). NÃO existem comandos
antigos tipo `mmsg -l`. Exemplos usados no projeto:
- `mmsg watch all-monitors` — stream JSON (um por linha) com `layout_symbol` e `tags`
  (`is_active`/`is_urgent`/`layout`/`client_count`). Base do [MangoLayout.qml](services/MangoLayout.qml).
- `mmsg dispatch view,<n>,0` — troca de workspace.
- `mmsg dispatch setlayout,<name>` — aplica layout (nomes em [shell.qml](shell.qml) `layoutItems`).
- `mmsg dispatch "spawn,<linha de comando>"` — pede ao compositor para **lançar** um processo.

### Lançar ferramentas Wayland (slurp/wayfreeze/grim/swaybg/blueman/swayidle): use `mmsg dispatch spawn`
**Processos filhos do `Process` do Quickshell NÃO recebem um `WAYLAND_DISPLAY` utilizável** —
ferramentas gráficas Wayland (slurp, wayfreeze, swaybg, blueman-applet, swayidle…) simplesmente não
abrem. O `mmsg` em si funciona pelo `Process` porque usa o **socket do mango**, não o Wayland. A
solução é fazer o **próprio compositor** lançar o comando via `mmsg dispatch "spawn,sh -c '<script>'"`
(igual a um keybind) — aí o ambiente Wayland está correto. Ver [CaptureService.qml](services/CaptureService.qml)
(captura) e [StartupService.qml](services/StartupService.qml) (daemons da sessão).

- O argumento do spawn é **uma string única** `spawn,<linha>` (não args separados por vírgula).
  Use `sh -c '...'` com aspas simples externas e aspas duplas internas para `"$var"`/`$(...)`.

### O PATH do mango é mínimo
Processos spawnados pelo mango têm PATH ≈ `/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/opt/zig`
— **não** inclui `~/.cargo/bin` nem `~/.local/bin`. Binários instalados ali (ex.: `wayfreeze` via
cargo) "somem" e scripts que dependem deles travam silenciosamente. Por isso o `spawn()` do
`CaptureService` e o [session.sh](services/session.sh) prefixam `export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$PATH"`.

### `Process` (Quickshell.Io)
- **One-shot:** use `proc.exec([argv])`. Re-rodar via `proc.running = true` num Process já
  finalizado é frágil — prefira `exec()`.
- **Long-running:** `command:` declarativo + `running: true` (ver MangoLayout/CavaService).
- `Process.exec` **herda o ambiente** do Quickshell (logo o `mmsg` acha o socket).
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
services/             singletons/escopos não-visuais (mango, áudio, captura, mídia, clima,
                      updates, notificações, StartupService, Settings, ThemeExport) + session.sh
cava/                 tudo do visualizador CAVA (serviço, janela, barras, anel) + cava.conf
layouts/              LayoutMenu (seletor de layout do mango)
windows/              janelas interativas: ShellWindow, NotificationWindow, SettingsWindow
ui/                   componentes visuais "burros": MenuBall, Petal, GothicCorners, AudioMenu,
                      AudioDevices, TrayMenu, PowerMenu, SettingsField, Capsule, TopCapsules
```

⚠️ **A auto-descoberta do Quickshell por nome só vale para a PASTA RAIZ.** Um arquivo na raiz
(`Config.qml`) é visível por toda parte sem import; um arquivo numa **subpasta NÃO** é — nem
componentes, nem singletons. Para usar um tipo de outra pasta, **importe a pasta** com o esquema
`root:/` (a raiz da config):

- `import "root:/services"` → expõe `AudioService`, `CaptureService`, `StartupService`, …
- `import "root:/ui"`, `import "root:/cava"`, `import "root:/layouts"`, `import "root:/windows"`, `import "root:/themes"`
- `import "root:/"` → expõe os tipos da **raiz** (na prática, `Config`).
- Arquivos na **mesma pasta** se enxergam sem import (regra normal do QML).

Sintaxe verificada no Quickshell 0.3.0: tanto componentes quanto `pragma Singleton` resolvem por
`import "root:/<pasta>"`. **Sem o import, um singleton de subpasta dá `ReferenceError: X is not defined`.**
Ao **mover** um arquivo entre pastas, reveja os imports dele E de quem o usa.

## Arquitetura

`qs` carrega **[shell.qml](shell.qml)** (ponto de entrada), que só conecta as peças:
1. **Serviços** (singletons/scopes globais em `services/` e `cava/`):
   [MangoLayout.qml](services/MangoLayout.qml) (estado do mango), [AudioService.qml](services/AudioService.qml)
   (Pipewire), [CaptureService.qml](services/CaptureService.qml) (print/gravação),
   [CavaService.qml](cava/CavaService.qml) (níveis do cava), [MediaService.qml](services/MediaService.qml) (MPRIS),
   [WeatherService.qml](services/WeatherService.qml) (wttr.in), [UpdateService.qml](services/UpdateService.qml)
   (pacotes/MangoWC), [NotificationService.qml](services/NotificationService.qml) (servidor freedesktop),
   [StartupService.qml](services/StartupService.qml) (sobe os daemons da sessão),
   [Settings.qml](services/Settings.qml) (overrides do usuário, persistidos), [ThemeExport.qml](services/ThemeExport.qml)
   (regenera os temas dos apps externos).
2. **Dados data-driven:** `menuItems` (pétalas; flags `audio`/`capture`/`tray`/`update`/`settings`/`power`
   marcam pétalas especiais) e `layoutItems` (layouts do mango). Adicionar/remover itens reorganiza o anel
   automaticamente. (A 3ª pétala combina `settings`+`power`: 2 seções — configurações em cima, energia embaixo.)
3. **Uma instância por monitor** via `Variants { model: Quickshell.screens }`: uma
   [CavaWindow.qml](cava/CavaWindow.qml) (camada **Bottom**, atrás dos apps, click-through), uma
   [ShellWindow.qml](windows/ShellWindow.qml) (camada **Top**, a UI interativa) e uma
   [TopCapsules.qml](ui/TopCapsules.qml) (cápsulas de mídia/temperatura no topo). As janelas únicas
   (monitor focado) são a [NotificationWindow.qml](windows/NotificationWindow.qml) e a
   [SettingsWindow.qml](windows/SettingsWindow.qml) (overlay modal de configurações).

### Inicialização da sessão centralizada no Quickshell
Os daemons da sessão (wallpaper, applet do bluetooth, idle/lock/dpms) foram trazidos do
`autostart.sh` do mango para **dentro do quickshell**:
- [StartupService.qml](services/StartupService.qml) (singleton) é chamado uma vez por `shell.qml`
  (`Component.onCompleted: StartupService.start()`). Ele pede ao compositor (via `mmsg dispatch spawn`)
  para rodar [session.sh](services/session.sh), que sobe `swaybg`, `blueman-applet` e `swayidle`
  (com guardas `pgrep` para não duplicar a cada reload, e `setsid` para sobreviverem).
- **O que NÃO dá para mover** (e fica no [autostart.sh](../mango/scripts/autostart.sh), por
  ordem/bootstrap): `PATH`+`dbus-update-activation-environment`; `pkill swaync` **antes** do qs
  (senão o qs não registra o servidor de notificações); lançar o próprio `qs`; e a notificação de
  "Mango reload" (semântica de reload do mango).
- **Acoplamento aceito:** se o qs não carregar, o `StartupService` não roda → sem wallpaper/idle nessa
  sessão. (Trade-off escolhido em prol da centralização.) Um futuro caminho 100% QML seria
  `IdleMonitor` + `WlSessionLock` no lugar do swayidle/hyprlock.

### ShellWindow é o "controlador"
Concentra **geometria, estado e TODA a lógica de interação**; os componentes visuais são burros e
recebem o controlador na propriedade `ctx`. Pontos-chave:
- **Um único `MouseArea` + um `WheelHandler`** no topo fazem **hit-testing geométrico** em vez de
  MouseAreas por elemento (isso resolveu instabilidades de hover): `petalAt` (angular), `dotAt`
  (distância), `overBallAt`, `petalSectionAt` (radial, para pétalas multi-botão), `layoutAt`,
  `audioSliderAt`.
- **Hover com debounce** (`hoverOpen` + `hoverCloseTimer`) para evitar o loop de feedback
  máscara↔abertura que colapsava o menu.
- **Máscara de input** (`mask: Region`) muda com `open`: fechado só a bola é clicável; aberto a
  região central inteira; o resto é click-through.
- **Scroll por região:** sobre a bola troca workspace (com wrap 1↔N); na região das pétalas gira o
  anel; sobre um slider de áudio ajusta o volume.
- Estado central: `pinned`/`dismissed`/`hoverOpen` (→ `open`), `hoverIndex`, `selectedIndex`,
  `layoutMode`, `audioMode`, `petalSection`, `petalRotation`.
- `monData`/`tags`/`activeTag`/`currentLayoutSymbol` derivam de `mango.monitorByName(modelData.name)`
  — `modelData.name` (a screen) **bate com o nome do monitor no mango** (ex.: `DP-2`, `HDMI-A-1`),
  o que também é usado para gravar um monitor específico (`wf-recorder -o <name>`).

### Componentes visuais (recebem `ctx`)
[MenuBall.qml](ui/MenuBall.qml) (bola: nº do workspace / nome do layout / anel de pontos),
[Petal.qml](ui/Petal.qml) (uma pétala; renderiza ícone único, ou painel multi-seção conforme as flags
do item: áudio 3 seções, captura/updates/sistema 2 seções, bandeja N seções), [LayoutMenu.qml](layouts/LayoutMenu.qml)
(lista curvada de layouts), [PowerMenu.qml](ui/PowerMenu.qml) (popup de ações de energia — bloquear/sair/
suspender/hibernar/reiniciar/desligar), [AudioMenu.qml](ui/AudioMenu.qml) (sliders), [AudioDevices.qml](ui/AudioDevices.qml)
(seletor de dispositivo), [TrayMenu.qml](ui/TrayMenu.qml) (menu do item da bandeja),
[SettingsField.qml](ui/SettingsField.qml) (uma linha editável da janela de configurações: cor/número/texto/seletor/toggle),
[GothicCorners.qml](ui/GothicCorners.qml) (filetes côncavos `Canvas` que fundem a bola na barra fina),
[Capsule.qml](ui/Capsule.qml)/[TopCapsules.qml](ui/TopCapsules.qml) (cápsulas retráteis do topo),
[CavaRing.qml](cava/CavaRing.qml)/[CavaBars.qml](cava/CavaBars.qml) (visualizador radial/linear).

### Config centralizada + Tema + overrides em runtime
**[Config.qml](Config.qml)** é um singleton (na raiz) com TODOS os valores ajustáveis (geometria,
fontes, tempos, ângulos das pétalas, áudio, captura, clima, updates) e os nomes **semânticos** de cor
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

### Configurações em runtime + export de temas (3ª pétala = "Sistema")
A 3ª pétala tem 2 seções: **engrenagem** (cima) abre a [SettingsWindow.qml](windows/SettingsWindow.qml)
(overlay modal central com TODAS as opções por grupo, via schema → [SettingsField.qml](ui/SettingsField.qml));
**energia** (baixo) abre o [PowerMenu.qml](ui/PowerMenu.qml) no clique esquerdo e lança o **wlogout** no
clique direito.
- **[Settings.qml](services/Settings.qml)** (singleton) guarda só os overrides num JSON
  (`~/.config/quickshell/settings.json`, via `FileView`). `get/set/unset/reset`; reatribui o mapa inteiro a
  cada `set` para os bindings de `Config`/`Theme` (que leem `get()`) reavaliarem. `reset()` recarrega
  `settings.default.json` (o "padrão de fábrica"; edite-o para mudar o que "Restaurar padrão" faz).
- **[ThemeExport.qml](services/ThemeExport.qml)** regenera os temas dos apps **externos** a partir da
  paleta efetiva (`Theme.*`), com **backup** (`<arquivo>.bak-<ts>`) e **reload ao vivo**. Disparado
  automaticamente quando muda `pal_*`/`theme*` (debounce no Settings) e pelo botão "Exportar temas".
  Alvos (escreve nos MESMOS arquivos que os apps já incluem → não mexe noutras linhas): **kitty**
  (`themes/crimson-devil.conf`, `include` no kitty.conf), **rofi** (`themes/crimson-devil.rasi`, `@theme`),
  **mango** (`devil-shell/theme.conf`, `source=` → reload via `mmsg dispatch reload_config`), **vesktop**
  (`themes/devil-shell.css`, habilitar 1x), **wlogout** (`style.css`+`layout`) e **swaylock** (`config`).
  kitty recarrega com `pkill -USR1 kitty`; rofi/vesktop/swaylock pegam no próximo uso. A escrita usa
  `Qt.btoa` (base64) num único `sh -c` p/ evitar escaping → mantenha os comentários gerados em ASCII.

## Convenções e armadilhas de QML/Quickshell

- **Auto-descoberta só na RAIZ; subpastas pedem `import "root:/<pasta>"`** (ver "Estrutura de pastas"
  acima). Na raiz, um arquivo vira componente pelo nome (`Petal { }`) e `pragma Singleton` + `Singleton { }`
  o torna global pelo nome do arquivo (`Config.x`). Em subpasta, isso só vale APÓS importar a pasta.
- **Colisão `id` × `property`:** uma `property var x` com o mesmo nome de um `id: x` faz o lado
  direito resolver para a property (→ `undefined`). Por isso os componentes usam `property var ctx`
  (e o id do serviço em shell.qml é `mangoSvc`, não `mango`). Em `Canvas.onPaint`, o contexto 2D é
  nomeado `g` (não `ctx`) para não colidir.
- **`Behavior on X`** exige que `X` **não** seja `readonly`.
- **`required property var modelData`** nos delegates de `Repeater` evita o shadow do `modelData`
  da screen (`PanelWindow`) em Qt6.
- **Singletons são lazy:** só instanciam quando referenciados. Por isso o `StartupService` é
  acionado explicitamente (`StartupService.start()` no `Component.onCompleted` do `shell.qml`).
- Use bindings/guards defensivos para o estado do mango durante a inicialização
  (`if (!mango || !modelData) return null`), pois os primeiros frames chegam antes do primeiro
  evento do `mmsg watch`.

## Verificar contra o sistema ao vivo

Antes de assumir uma API do mango/Pipewire, confirme no compositor rodando:

```sh
export MANGO_INSTANCE_SIGNATURE=$XDG_RUNTIME_DIR/mango-<pid>.sock   # ver $XDG_RUNTIME_DIR
mmsg get all-monitors        # nomes/tags/layout_symbol reais
mmsg get version
mmsg dispatch "spawn,sh -c 'echo $PATH > /tmp/p'"   # inspecionar o ambiente do spawn
```

Scripts: daemons da sessão em [services/session.sh](services/session.sh) (swaybg/blueman/swayidle,
disparado pelo StartupService). Captura usa `~/.config/mango/scripts/printscreen_edit.sh`
(wayfreeze + slurp -d + grim + swappy) e `printscreen.sh` (sem editor). Bootstrap da sessão:
`~/.config/mango/scripts/autostart.sh` (PATH/dbus/kill swaync/lançar qs/notificação de reload).
