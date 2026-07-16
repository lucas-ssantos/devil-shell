import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import "root:/ui"         // MenuBall, Crystal, GothicCorners, AudioMenu, AudioDevices, TrayMenu
import "root:/cava"       // CavaRing
import "root:/services"   // AudioService, CaptureService
import "root:/"           // Config (raiz)

// Janela do shell (camada de cima): bola/menu, cristais, cava radial, barra e TODA a
// lógica de interação (hover/clique/scroll).
// Funciona como "controlador": os componentes visuais recebem `win` e leem o estado daqui.
PanelWindow {
    id: win

    // ── Entradas ──
    property var modelData          // a screen (monitor)
    property var menuItems: []      // itens dos cristais
    property var niri               // serviço NiriService
    property var levels: []         // níveis do cava

    screen: modelData
    color: "transparent"
    anchors { bottom: true; left: true; right: true }   // largura total -> barra atravessa a tela
    exclusiveZone: 0
    implicitHeight: Config.shellHeight   // espaço extra acima da bola p/ o submenu
    // pega o teclado SÓ enquanto há um menu/popup aberto (p/ o ESC fechar); fora disso não rouba
    WlrLayershell.keyboardFocus: win.anyPopup ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Geometria (valores em Config.qml) ───────────────
    readonly property real ballRadius: Config.ballRadius
    readonly property real ballCX: width / 2
    readonly property real ballPeek: Config.ballPeek
    readonly property real ballCYRest: height - ballPeek + ballRadius
    readonly property real ballCYOpen: height - ballRadius
    property real ballCY: open ? ballCYOpen : ballCYRest
    Behavior on ballCY { NumberAnimation { duration: Config.ballAnim; easing.type: Easing.OutCubic } }
    readonly property real crystalW: Config.crystalW

    // ── Fileira de cristais (escadaria ao lado da bola) ──
    // pares à DIREITA, ímpares à ESQUERDA; rank = distância da bola (0 = colado a ela).
    // A altura desce em degraus a partir de crystalMaxH (pouco menor que a bola).
    function crystalSide(i) { return i % 2 === 0 ? 1 : -1 }
    function crystalRank(i) { return Math.floor(i / 2) }
    function crystalHeight(i) {
        return Math.max(Config.crystalMinH, Config.crystalMaxH - crystalRank(i) * Config.crystalStepH)
    }
    function crystalCX(i) {
        return ballCX + crystalSide(i) * (ballRadius + Config.crystalGap + crystalW / 2
             + crystalRank(i) * (crystalW + Config.crystalSpacing))
    }
    // cristal "erguido": abrir a bola ergue todos; hover/seleção ergue só aquele
    function crystalRaised(i) { return open || hoverIndex === i || selectedIndex === i }
    readonly property int  ranksPerSide: Math.ceil(menuItems.length / 2)
    readonly property real rowHalf: ballRadius + Config.crystalGap
        + ranksPerSide * (crystalW + Config.crystalSpacing) + Config.hitMargin
    readonly property real menuHalf: rowHalf + Config.menuMargin
    // faixa de input dos cristais (máscara): só o peek em repouso; cresce enquanto
    // um cristal estiver erguido por hover, p/ o cursor poder acompanhá-lo subindo
    readonly property real rowMaskH: (hoverIndex !== -1
        ? Config.crystalMaxH * Config.crystalHoverScale : Config.crystalPeek) + Config.hitMargin
    readonly property real dotRingR: ballRadius * Config.dotRingFactor
    readonly property real gothicR: Config.gothicR

    // ── Estado de abertura ──────────────────────────────
    property bool pinned: false
    property bool dismissed: false
    property bool overBall: false
    property int  hoverIndex: -1
    property int  selectedIndex: -1
    property bool audioMode: false      // submenu de áudio (config) aberto
    property int  crystalSection: -1      // seção do cristal multi-botão sob o cursor
    property int  audioSliderHover: -1  // slider de áudio sob o cursor (0/1)
    property bool hoverOpen: false
    // a bola fica aberta tb enquanto um popup (tray/áudio/sliders) estiver visível (não
    // recolher sozinha) — os cristais agora são alcançáveis mesmo com a bola fechada,
    // então o audioMode também precisa segurar a bola aberta
    readonly property bool open: !dismissed && (pinned || hoverOpen || trayMenu.visible || audioDevices.visible || audioMode)
    // algum menu/popup aberto? (tray, dispositivos de áudio, ou sliders de áudio)
    readonly property bool anyPopup: trayMenu.visible || audioDevices.visible || audioMode
    readonly property int audioIndex: {
        for (let i = 0; i < menuItems.length; i++) if (menuItems[i].audio) return i
        return -1
    }
    readonly property int trayIndex: {
        for (let i = 0; i < menuItems.length; i++) if (menuItems[i].tray) return i
        return -1
    }
    readonly property int settingsIndex: {
        for (let i = 0; i < menuItems.length; i++) if (menuItems[i].settings) return i
        return -1
    }
    onHoverOpenChanged: if (!hoverOpen) dismissed = false
    onOpenChanged: if (!open) { selectedIndex = -1; audioMode = false }

    Timer { id: hoverCloseTimer; interval: Config.hoverCloseMs; onTriggered: win.hoverOpen = false }
    Timer { id: selectTimer; interval: Config.selectMs; onTriggered: { win.dismissed = true; win.pinned = false; win.selectedIndex = -1 } }

    // relógio (tick por minuto) p/ o texto sobre a bola escondida
    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    readonly property string dateText: Qt.formatDateTime(sysClock.date, Config.dateFormat)
    readonly property string timeText: Qt.formatDateTime(sysClock.date, Config.timeFormat)

    // ── Estado do Niri p/ ESTE monitor/workspace ─────────
    readonly property var monData: {
        if (!niri || !modelData) return null
        const byName = niri.monitorByName(modelData.name)
        if (byName) return byName
        const list = niri.monitors ?? []
        return (list.find(m => m.active) ?? list[0]) ?? null
    }
    readonly property var tags: (monData && monData.tags) ? monData.tags : []
    readonly property int activeTag: {
        for (let i = 0; i < tags.length; i++)
            if (tags[i].is_active) return tags[i].index
        return 0
    }
    // Anel com no mínimo Config.dotMinCount arcos: completa os workspaces reais com
    // "fantasmas" (vazios, sem workspace do niri por trás). Eles são só visuais: o
    // scroll troca apenas entre os reais, mas no wrap (último→1) o pontinho do anel
    // viaja NA DIREÇÃO do scroll, varrendo os fantasmas até chegar no 1.
    readonly property var allTags: {
        const out = tags.slice()
        for (let i = out.length; i < Config.dotMinCount; i++)
            out.push({ index: i + 1, id: -1, is_active: false, is_urgent: false, client_count: 0, ghost: true })
        return out
    }
    // direção da última troca por scroll (+1/-1); 0 = sem preferência (clique/teclado
    // → caminho mais curto). Consumida pelo anel do MenuBall ao animar a viagem.
    property int wsTravelDir: 0

    // Troca para o workspace `n` (idx do niri, 1-based) NESTE monitor. O
    // `focus-workspace` do niri age no monitor FOCADO, então, se este monitor não
    // estiver focado, focamos ele antes (`focus-monitor <nome>` aceita o nome direto).
    function viewTagHere(n) {
        const me = monData
        if (!me) return
        if (me.active) {                                   // já focado -> troca direto
            proc.exec(["niri", "msg", "action", "focus-workspace", "" + n])
            return
        }
        proc.exec(["sh", "-c",
            "niri msg action focus-monitor '" + modelData.name + "'; niri msg action focus-workspace " + n])
    }

    // ── Cristais multi-botão (áudio/sistema) ─────────────
    // seção (0 = base/chão … n-1 = na ponta) sob o cursor, dividindo o cristal em n
    // faixas verticais. Usa a geometria do HOVER (erguido e escalado a partir da
    // base), já que as seções só importam com o cursor no cristal.
    function crystalSectionAt(mx, my, n) {
        let i = crystalAt(mx, my)
        if (i < 0) i = hoverIndex
        if (i < 0) return 0
        const hVis = crystalHeight(i) * Config.crystalHoverScale
        return Math.max(0, Math.min(n - 1, Math.floor((height - my) / hVis * n)))
    }
    // nº de seções do cristal i (áudio=3, sistema=3, bandeja=nº de apps, demais=0)
    function crystalSections(i) {
        if (i === audioIndex) return 3
        if (i === settingsIndex) return 3
        if (i === trayIndex) return SystemTray.items.values.length
        return 0
    }
    // posição vertical de cada slider do submenu de áudio (0=headphone, 1=mic)
    function audioPillY(i) {
        return (ballCY - ballRadius - 8) - Config.audioSliderH / 2 - i * (Config.audioSliderH + 8)
    }
    function audioSliderAt(mx, my) {
        for (let i = 0; i < 2; i++)
            if (Math.abs(mx - ballCX) <= Config.audioSliderW / 2
             && Math.abs(my - audioPillY(i)) <= Config.audioSliderH / 2) return i
        return -1
    }

    // ── Hit-test (tudo por posição do cursor) ───────────
    // cristais em COLUNAS verticais ao lado da bola: acha a coluna mais próxima em X e
    // testa a altura conforme o estado (erguido = altura cheia com a escala de hover;
    // enterrado = só o peek). Testar a altura-alvo do próprio hoverIndex dá histerese:
    // o cursor pode subir acompanhando o cristal que emerge sem o hover piscar.
    function crystalAt(mx, my) {
        const n = menuItems.length
        if (n === 0 || overBallAt(mx, my)) return -1
        let best = -1, bestDx = 1e9
        for (let i = 0; i < n; i++) {
            const d = Math.abs(mx - crystalCX(i))
            if (d < bestDx) { bestDx = d; best = i }
        }
        if (bestDx > crystalW / 2 + Config.hitMargin) return -1
        const hVis = crystalRaised(best) ? crystalHeight(best) * Config.crystalHoverScale
                                         : Config.crystalPeek
        return my >= height - hVis - Config.hitMargin ? best : -1
    }
    // segmento do anel tracejado de workspaces sob o cursor (banda radial + setor
    // angular; o arco i é centrado em -90° + i·slot, casando com o desenho no MenuBall)
    function dotAt(mx, my) {
        const n = allTags.length
        if (n === 0) return -1
        const dx = mx - ballCX, dy = my - ballCY
        if (Math.abs(Math.hypot(dx, dy) - dotRingR) > Config.dotHitR) return -1
        const slot = 360 / n
        const theta = Math.atan2(dy, dx) * 180 / Math.PI      // 0=direita, 90=baixo (tela)
        const rel = (theta + 90 + slot / 2 + 720) % 360       // 0 = início do setor do 1º workspace
        return Math.min(n - 1, Math.floor(rel / slot))
    }
    function overBallAt(mx, my) { return Math.hypot(mx - ballCX, my - ballCY) <= ballRadius }
    // fecha o menu (usado antes de capturas, p/ não roubar o arrasto da seleção)
    function closeMenu() { dismissed = true; pinned = false }
    // fecha TODOS os menus/popups e recolhe a bola (usado pelo ESC)
    function closeAllMenus() {
        trayMenu.visible = false
        audioDevices.visible = false
        audioMode = false
        pinned = false
        dismissed = true
    }

    function refreshHover() {
        const mx = hoverMA.mouseX, my = hoverMA.mouseY
        if (!hoverMA.containsMouse) {
            overBall = false; hoverIndex = -1; crystalSection = -1; audioSliderHover = -1
        } else {
            overBall = overBallAt(mx, my)
            if (audioMode) {
                hoverIndex = -1; crystalSection = -1
                audioSliderHover = overBall ? -1 : audioSliderAt(mx, my)
            } else {
                hoverIndex = overBall ? -1 : crystalAt(mx, my)
                const ns = crystalSections(hoverIndex)
                crystalSection = ns > 0 ? crystalSectionAt(mx, my, ns) : -1
                audioSliderHover = -1
            }
        }
        // a bola abre por hover NELA (ou nos sliders); hover num cristal ergue só o
        // cristal — mas mantém a bola aberta se ela já estava (bola → cristal não recolhe)
        if (overBall || audioSliderHover !== -1 || (hoverOpen && hoverIndex !== -1)) { hoverCloseTimer.stop(); hoverOpen = true }
        else hoverCloseTimer.restart()
    }

    // processo p/ comandos one-shot (niri msg, ações dos cristais)
    Process { id: proc }

    // ── Foco da janela do app a partir do tray (esquerdo) ──────────────
    // O activate() do SNI é incoerente (alterna/não rouba foco). Em vez disso, achamos
    // a janela do app (niri msg --json windows, casando por app_id/título) e focamos com
    // `focus-window --id`, que foca qualquer janela incondicionalmente. Sem janela -> activate().
    property var pendingFocusTray: null
    function focusTrayApp(it) {
        pendingFocusTray = it
        clientsProc.exec(["niri", "msg", "--json", "windows"])
    }
    function matchTrayClient(clients, tray) {
        function norm(s) { return (s || "").toString().toLowerCase() }
        const fields = [norm(tray.id), norm(tray.title), norm(tray.tooltipTitle)].filter(s => s.length > 0)
        // 1) por app_id (sinal mais confiável: ex. tray "steam" -> app_id "steam")
        for (let i = 0; i < clients.length; i++) {
            const a = norm(clients[i].app_id)
            if (!a) continue
            for (let j = 0; j < fields.length; j++)
                if (a.indexOf(fields[j]) >= 0 || fields[j].indexOf(a) >= 0) return clients[i]
        }
        // 2) fallback por título
        for (let i = 0; i < clients.length; i++) {
            const t = norm(clients[i].title)
            for (let j = 0; j < fields.length; j++)
                if (fields[j].length >= 4 && t.indexOf(fields[j]) >= 0) return clients[i]
        }
        return null
    }
    Process {
        id: clientsProc
        stdout: SplitParser {
            onRead: line => {
                const it = win.pendingFocusTray
                win.pendingFocusTray = null
                if (!it) return
                let clients
                try { clients = JSON.parse(line) } catch (e) { it.activate(); return }
                const c = win.matchTrayClient(clients ?? [], it)
                if (c) proc.exec(["niri", "msg", "action", "focus-window", "--id", "" + c.id])
                else it.activate()   // app sem janela aberta -> abre/ativa
            }
        }
    }

    // menu estilizado do item da bandeja (system tray), aberto no clique direito
    TrayMenu { id: trayMenu; ctx: win }

    // seletor de dispositivo de áudio (direito no headphone/mic do cristal de áudio)
    AudioDevices { id: audioDevices; ctx: win }

    // ESC fecha todos os menus (a janela só recebe o teclado quando há um menu aberto)
    Item {
        anchors.fill: parent
        focus: win.anyPopup
        Keys.onEscapePressed: win.closeAllMenus()
    }

    // ── Máscara de input ────────────────────────────────
    //  Fechado: a bola + a faixa dos cristais no chão (peek hoverável; a faixa cresce
    //  enquanto um cristal estiver erguido). Aberto: a região central inteira.
    //  O resto é sempre click-through.
    mask: Region {
        shape: win.open ? RegionShape.Rect : RegionShape.Ellipse
        x: win.open ? Math.round(win.ballCX - win.menuHalf) : Math.round(win.ballCX - win.ballRadius)
        y: win.open ? 0 : Math.round(win.ballCY - win.ballRadius)
        width: win.open ? Math.round(win.menuHalf * 2) : Math.round(win.ballRadius * 2)
        height: win.open ? win.height : Math.round(win.ballRadius * 2)
        regions: [
            Region {   // faixa dos cristais (união com a região acima)
                shape: RegionShape.Rect
                x: Math.round(win.ballCX - win.rowHalf)
                y: Math.round(win.height - win.rowMaskH)
                width: Math.round(win.rowHalf * 2)
                height: Math.round(win.rowMaskH)
            }
        ]
    }

    // ── Componentes visuais ─────────────────────────────
    // CavaRing (círculo Cavasik): à frente das janelas do niri (a ShellWindow é camada
    // Top) e atrás de TODO o shell (z 0 < cristal z1 < barra/gótico z2 < bola z3 …).
    CavaRing {
        z: 0
        levels: win.levels
        cx: win.ballCX
        cy: win.ballCY
        r0: win.ballRadius
        rMax: Config.cavaRadMax
    }

    Repeater {                                              // cristais
        model: win.menuItems
        delegate: Crystal { ctx: win }
    }

    AudioMenu { ctx: win }                                  // submenu de áudio (sliders)

    // barra fina no fundo (a bola se funde nela)
    Rectangle {
        z: 2
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Config.barHeight
        color: Config.ball
    }

    GothicCorners { ctx: win }                              // filetes bola ↔ barra
    MenuBall { ctx: win }                                   // a bola

    // data/hora ao lado da bola (só quando escondida): data à esquerda, hora à direita
    Text {
        z: 4
        text: win.dateText
        color: Config.clock
        font.pixelSize: Config.clockSize
        font.bold: true
        x: win.ballCX - Config.clockSideGap - width   // borda direita encosta na bola pela esquerda
        y: win.height - win.ballPeek / 2 - height / 2  // centralizado na fatia visível da bola
        opacity: win.open ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Config.clockAnim } }
    }
    Text {
        z: 4
        text: win.timeText
        color: Config.clock
        font.pixelSize: Config.clockSize
        font.bold: true
        x: win.ballCX + Config.clockSideGap          // borda esquerda começa após a bola
        y: win.height - win.ballPeek / 2 - height / 2
        opacity: win.open ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Config.clockAnim } }
    }

    // ── Entrada: hover + TODOS os cliques (por hit-test) ──
    MouseArea {
        id: hoverMA
        anchors.fill: parent
        z: 10
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: win.refreshHover()
        onPositionChanged: win.refreshHover()
        onExited: win.refreshHover()

        onClicked: (mouse) => {
            // Botão direito: bandeja -> menu do app; áudio -> seletor de dispositivo
            if (mouse.button === Qt.RightButton) {
                if (win.audioMode) return   // ignora durante o submenu de sliders
                const rpi = win.crystalAt(mouseX, mouseY)
                if (rpi === win.trayIndex) {
                    if (trayMenu.visible) { trayMenu.visible = false; return }   // direito de novo fecha
                    const items = SystemTray.items.values
                    const s = items.length > 0 ? win.crystalSectionAt(mouseX, mouseY, items.length) : -1
                    const it = s >= 0 ? items[s] : null
                    if (it && it.menu) {
                        win.dismissed = false                                   // garante a bola junto do menu
                        trayMenu.openAt(it, Math.round(mouseX), Math.round(mouseY))
                    }
                } else if (rpi === win.audioIndex) {
                    if (audioDevices.visible) { audioDevices.visible = false; return }  // direito de novo fecha
                    const s = win.crystalSectionAt(mouseX, mouseY, 3)
                    win.dismissed = false
                    if (s === 2)      audioDevices.openAt("sink",   Math.round(mouseX), Math.round(mouseY))  // headphone -> saídas
                    else if (s === 1) audioDevices.openAt("source", Math.round(mouseX), Math.round(mouseY))  // mic -> entradas
                } else if (rpi === win.settingsIndex) {
                    // cristal de Sistema: sobre a lâmpada (seção 0) o direito também faz o toggle
                    if (win.crystalSectionAt(mouseX, mouseY, 3) === 0) {
                        IdleService.toggle()
                    }
                }
                return
            }
            // ===== a partir daqui: botão esquerdo (comportamento normal) =====
            // 1) ponto de workspace?
            const di = win.dotAt(mouseX, mouseY)
            if (di >= 0) {
                if (di < win.tags.length)                  // fantasma não tem workspace p/ focar
                    win.viewTagHere(win.tags[di].index)    // troca no monitor DESTA bola
                return
            }
            // 2) bola?
            if (win.overBallAt(mouseX, mouseY)) {
                if (trayMenu.visible || audioDevices.visible) {   // fecha popup + bola
                    trayMenu.visible = false; audioDevices.visible = false
                    win.pinned = false; win.dismissed = true; return
                }
                if (win.audioMode)  { win.audioMode = false; return }   // volta ao menu principal
                if (win.pinned) { win.pinned = false; win.dismissed = true }
                else            { win.pinned = true;  win.dismissed = false }
                return
            }
            // 3b) submenu de áudio -> clique no slider não faz nada (scroll ajusta); fora recolhe
            if (win.audioMode) {
                if (win.audioSliderAt(mouseX, mouseY) < 0) win.pinned = false
                return
            }
            // 4) cristal?
            const pi = win.crystalAt(mouseX, mouseY)
            if (pi >= 0) {
                if (pi === win.audioIndex) {
                    // cristal de áudio: seção define a ação
                    const s = win.crystalSectionAt(mouseX, mouseY, 3)
                    if (s === 2)      AudioService.toggleSinkMute()    // headphone (saída)
                    else if (s === 1) AudioService.toggleSourceMute()  // microfone (entrada)
                    else if (s === 0) win.audioMode = true             // config (abre sliders)
                } else if (pi === win.trayIndex) {
                    // cristal da bandeja: esquerdo = traz/foca a janela do app (via niri)
                    const items = SystemTray.items.values
                    if (items.length > 0) {
                        const it = items[win.crystalSectionAt(mouseX, mouseY, items.length)]
                        if (it) win.focusTrayApp(it)
                    }
                } else if (pi === win.settingsIndex) {
                    // cristal de sistema: topo=configurações, meio=gravar/parar, base=toggle de lock
                    const s = win.crystalSectionAt(mouseX, mouseY, 3)
                    if (s === 2) {
                        Settings.open = true                       // engrenagem -> janela de configurações
                        win.pinned = false; win.dismissed = true
                    } else if (s === 1) {
                        if (CaptureService.recording) {
                            CaptureService.stopRecording()         // parar gravação
                        } else {
                            // grava este monitor inteiro (a tela é escolhida por qual bola se clica)
                            win.closeMenu(); CaptureService.startRecording(win.modelData.name)
                        }
                    } else {
                        IdleService.toggle()                       // lâmpada -> inibe/reativa lock/idle
                    }
                } else {
                    const item = win.menuItems[pi]
                    if (item.launcher) {                         // lançador próprio (LauncherWindow)
                        LauncherService.toggle()
                        win.pinned = false; win.dismissed = true
                        return
                    }
                    if (item.spawn)                              // app gráfico: lança pelo niri (env Wayland)
                        proc.exec(["niri", "msg", "action", "spawn-sh", "--", item.spawn])
                    else if ((item.command ?? []).length > 0)    // comando direto (sem env Wayland)
                        proc.exec(item.command)
                    win.selectedIndex = pi
                    selectTimer.restart()
                }
                return
            }
            // 5) fora -> recolhe (e fecha os popups, se abertos)
            trayMenu.visible = false
            audioDevices.visible = false
            win.pinned = false
        }
    }

    // ── Captura de scroll (Item no topo; não bloqueia hover/clique) ──
    Item {
        anchors.fill: parent
        z: 20
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                const dir = event.angleDelta.y > 0 ? -1 : 1   // cima = +
                // submenu de áudio: scroll sobre um slider ajusta o volume
                if (win.audioMode) {
                    if (win.audioSliderHover === 0) AudioService.addSinkVolume(-dir * Config.volStep)
                    else if (win.audioSliderHover === 1) AudioService.addSourceVolume(-dir * Config.volStep)
                    return
                }
                // em qualquer outro lugar -> troca de workspace DESTE monitor
                // (só entre os reais, com wrap 1↔N; a direção guia a animação do anel)
                const total = win.tags.length
                if (total === 0) return
                const cur = win.activeTag > 0 ? win.activeTag : 1
                const next = ((cur - 1 + dir + total) % total) + 1
                if (next !== cur) {
                    win.wsTravelDir = dir
                    win.viewTagHere(next)
                }
            }
        }
    }
}
