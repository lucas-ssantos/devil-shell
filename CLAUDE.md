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
  é lançado pelo `~/.config/mango/scripts/autostart.sh` (`pkill qs; qs &`), sem terminal visível.
- **Inicie o `qs` de dentro da sessão do mango.** Ele precisa herdar `WAYLAND_DISPLAY` e
  `MANGO_INSTANCE_SIGNATURE` do ambiente do compositor; um terminal "pelado" fora da sessão quebra
  o `mmsg` (erro `connect: No such file or directory`).

## ⚠️ Peculiaridades MangoWC + Quickshell (leia antes de mexer em IPC/processos)

Estas são as armadilhas que mais custaram tempo. Respeite-as.

### IPC com o mango: `mmsg`
Interface **nova**: `get` (one-shot), `watch` (stream), `dispatch` (ações). NÃO existem comandos
antigos tipo `mmsg -l`. Exemplos usados no projeto:
- `mmsg watch all-monitors` — stream JSON (um por linha) com `layout_symbol` e `tags`
  (`is_active`/`is_urgent`/`layout`/`client_count`). Base do [MangoLayout.qml](MangoLayout.qml).
- `mmsg dispatch view,<n>,0` — troca de workspace.
- `mmsg dispatch setlayout,<name>` — aplica layout (nomes em [shell.qml](shell.qml) `layoutItems`).
- `mmsg dispatch "spawn,<linha de comando>"` — pede ao compositor para **lançar** um processo.

### Lançar ferramentas Wayland (slurp/wayfreeze/grim/wf-recorder): use `mmsg dispatch spawn`
**Processos filhos do `Process` do Quickshell NÃO recebem um `WAYLAND_DISPLAY` utilizável** —
ferramentas gráficas Wayland (slurp, wayfreeze, etc.) simplesmente não abrem. O `mmsg` em si
funciona pelo `Process` porque usa o **socket do mango**, não o Wayland. A solução é fazer o
**próprio compositor** lançar o comando via `mmsg dispatch "spawn,sh -c '<script>'"` (igual a um
keybind) — aí o ambiente Wayland está correto. Ver [CaptureService.qml](CaptureService.qml).

- O argumento do spawn é **uma string única** `spawn,<linha>` (não args separados por vírgula).
  Use `sh -c '...'` com aspas simples externas e aspas duplas internas para `"$var"`/`$(...)`.

### O PATH do mango é mínimo
Processos spawnados pelo mango têm PATH ≈ `/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/opt/zig`
— **não** inclui `~/.cargo/bin` nem `~/.local/bin`. Binários instalados ali (ex.: `wayfreeze` via
cargo) "somem" e scripts que dependem deles travam silenciosamente. Por isso o `spawn()` do
`CaptureService` prefixa `export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"`.

### `Process` (Quickshell.Io)
- **One-shot:** use `proc.exec([argv])`. Re-rodar via `proc.running = true` num Process já
  finalizado é frágil — prefira `exec()`.
- **Long-running:** `command:` declarativo + `running: true` (ver MangoLayout/CavaService).
- `Process.exec` **herda o ambiente** do Quickshell (logo o `mmsg` acha o socket).
  `Quickshell.execDetached` **não** herda — não o use para comandos que dependem de env.
- `Process` precisa de `import Quickshell.Io`; `Timer`/`Canvas` precisam de `import QtQuick`.

## Arquitetura

`qs` carrega **[shell.qml](shell.qml)** (ponto de entrada), que só conecta as peças:
1. **Serviços** (singletons/scopes globais): [MangoLayout.qml](MangoLayout.qml) (estado do mango),
   [AudioService.qml](AudioService.qml) (Pipewire), [CaptureService.qml](CaptureService.qml)
   (print/gravação), [CavaService.qml](CavaService.qml) (níveis do cava).
2. **Dados data-driven:** `menuItems` (pétalas; flags `audio`/`capture` marcam pétalas especiais) e
   `layoutItems` (layouts do mango). Adicionar/remover itens reorganiza o anel automaticamente.
3. **Uma instância por monitor** via `Variants { model: Quickshell.screens }`: uma
   [CavaWindow.qml](CavaWindow.qml) (camada **Bottom**, atrás dos apps, click-through) e uma
   [ShellWindow.qml](ShellWindow.qml) (camada **Top**, a UI interativa).

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
[MenuBall.qml](MenuBall.qml) (bola: nº do workspace / nome do layout / anel de pontos),
[Petal.qml](Petal.qml) (uma pétala; renderiza ícone único, ou painel de áudio de 3 seções, ou
painel de captura de 2 seções, conforme as flags do item), [LayoutMenu.qml](LayoutMenu.qml)
(lista curvada de layouts), [AudioMenu.qml](AudioMenu.qml) (sliders), [GothicCorners.qml](GothicCorners.qml)
(filetes côncavos `Canvas` que fundem a bola na barra fina), [CavaRing.qml](CavaRing.qml)/
[CavaBars.qml](CavaBars.qml) (visualizador radial/linear).

### Config centralizada
**[Config.qml](Config.qml)** é um singleton com TODOS os valores ajustáveis (geometria, cores,
fontes, tempos, ângulos das pétalas, áudio, captura). Regra do projeto: **nada de valores
hardcoded na lógica** — adicione em `Config.qml` e referencie como `Config.<algo>`.

## Convenções e armadilhas de QML/Quickshell

- **Sem `qmldir`:** o Quickshell descobre os `.qml` da pasta de config automaticamente; um arquivo
  vira componente pelo nome (`Petal { }`), e `pragma Singleton` + `Singleton { }` o torna acessível
  globalmente pelo nome do arquivo (`Config.x`, `AudioService.y`).
- **Colisão `id` × `property`:** uma `property var x` com o mesmo nome de um `id: x` faz o lado
  direito resolver para a property (→ `undefined`). Por isso os componentes usam `property var ctx`
  (e o id do serviço em shell.qml é `mangoSvc`, não `mango`). Em `Canvas.onPaint`, o contexto 2D é
  nomeado `g` (não `ctx`) para não colidir.
- **`Behavior on X`** exige que `X` **não** seja `readonly`.
- **`required property var modelData`** nos delegates de `Repeater` evita o shadow do `modelData`
  da screen (`PanelWindow`) em Qt6.
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

Scripts externos usados pela captura: `~/.config/mango/scripts/printscreen_edit.sh` (wayfreeze + slurp -d +
grim + swappy) e `printscreen.sh` (sem editor). Lançamento do shell: `~/.config/mango/scripts/autostart.sh`.
