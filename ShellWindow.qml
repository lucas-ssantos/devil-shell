import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

// Janela do shell (camada de cima): bola/menu, pétalas, submenu de layouts,
// cava radial, barra e TODA a lógica de interação (hover/clique/scroll).
// Funciona como "controlador": os componentes visuais recebem `win` e leem o estado daqui.
PanelWindow {
    id: win

    // ── Entradas ──
    property var modelData          // a screen (monitor)
    property var menuItems: []      // itens das pétalas
    property var layoutItems: []    // opções de layout do Mango
    property var mango              // serviço MangoLayout
    property var levels: []         // níveis do cava

    screen: modelData
    color: "transparent"
    anchors { bottom: true; left: true; right: true }   // largura total -> barra atravessa a tela
    exclusiveZone: 0
    implicitHeight: Config.shellHeight   // espaço extra acima da bola p/ o submenu

    // ── Geometria (valores em Config.qml) ───────────────
    readonly property real ballRadius: Config.ballRadius
    readonly property real ballCX: width / 2
    readonly property real ballPeek: Config.ballPeek
    readonly property real ballCYRest: height - ballPeek + ballRadius
    readonly property real ballCYOpen: height - ballRadius
    property real ballCY: open ? ballCYOpen : ballCYRest
    Behavior on ballCY { NumberAnimation { duration: Config.ballAnim; easing.type: Easing.OutCubic } }
    readonly property real petalW: Config.petalW
    readonly property real petalH: Config.petalH
    readonly property real petalDist: ballRadius + Config.petalGap + petalH / 2
    readonly property real petalShrink: Config.petalShrink
    readonly property real petalTouch: ballRadius + petalH * petalShrink / 2
    readonly property real petalFlare: Config.petalFlare
    readonly property real hitOuterR: petalDist + petalH / 2 + Config.hitMargin
    readonly property real menuHalf: hitOuterR + Config.menuMargin
    readonly property real dotRingR: ballRadius * Config.dotRingFactor
    readonly property real gothicR: Config.gothicR
    readonly property real cavaRadMax: Config.cavaRadMax
    readonly property real layoutRowH: Config.layoutRowH
    readonly property real layoutPillW: Config.layoutPillW
    readonly property real layoutBow: Config.layoutBow
    property real petalRotation: 0
    Behavior on petalRotation { NumberAnimation { duration: Config.petalRotAnim; easing.type: Easing.OutCubic } }

    // ── Estado de abertura ──────────────────────────────
    property bool pinned: false
    property bool dismissed: false
    property bool overBall: false
    property int  hoverIndex: -1
    property int  selectedIndex: -1
    property bool layoutMode: false
    property bool audioMode: false      // submenu de áudio (config) aberto
    property int  petalSection: -1      // seção da pétala multi-botão sob o cursor
    property int  audioSliderHover: -1  // slider de áudio sob o cursor (0/1)
    property bool hoverOpen: false
    readonly property bool open: !dismissed && (pinned || hoverOpen)
    readonly property int audioIndex: {
        for (let i = 0; i < menuItems.length; i++) if (menuItems[i].audio) return i
        return -1
    }
    readonly property int captureIndex: {
        for (let i = 0; i < menuItems.length; i++) if (menuItems[i].capture) return i
        return -1
    }
    readonly property int trayIndex: {
        for (let i = 0; i < menuItems.length; i++) if (menuItems[i].tray) return i
        return -1
    }
    onHoverOpenChanged: if (!hoverOpen) dismissed = false
    onOpenChanged: if (!open) { selectedIndex = -1; layoutMode = false; audioMode = false }

    Timer { id: hoverCloseTimer; interval: Config.hoverCloseMs; onTriggered: win.hoverOpen = false }
    Timer { id: selectTimer; interval: Config.selectMs; onTriggered: { win.dismissed = true; win.pinned = false; win.selectedIndex = -1 } }

    // relógio (tick por minuto) p/ o texto sobre a bola escondida
    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    readonly property string dateText: Qt.formatDateTime(sysClock.date, Config.dateFormat)
    readonly property string timeText: Qt.formatDateTime(sysClock.date, Config.timeFormat)

    // ── Estado do MangoWC p/ ESTE monitor/workspace ──────
    readonly property var monData: {
        if (!mango || !modelData) return null
        const byName = mango.monitorByName(modelData.name)
        if (byName) return byName
        const list = mango.monitors ?? []
        return (list.find(m => m.active) ?? list[0]) ?? null
    }
    readonly property var tags: (monData && monData.tags) ? monData.tags : []
    readonly property int activeTag: {
        for (let i = 0; i < tags.length; i++)
            if (tags[i].is_active) return tags[i].index
        return 0
    }
    readonly property string currentLayoutSymbol: monData ? (monData.layout_symbol ?? "?") : "?"
    readonly property string currentLayoutName: mango ? (mango.layoutNames[currentLayoutSymbol] ?? currentLayoutSymbol) : currentLayoutSymbol
    readonly property bool showLayoutName: layoutMode || hoverIndex === 0
    readonly property string displayLayoutName: layoutMode
        ? (hoverIndex >= 0 ? (layoutItems[hoverIndex].label ?? "") : currentLayoutName)
        : currentLayoutName

    // Troca para o workspace `n` NESTE monitor. O `view` do mango age no monitor
    // FOCADO, então, se este monitor não estiver focado, focamos ele antes (direção
    // calculada pela posição do monitor focado vs. este — vale p/ 2 monitores).
    function viewTagHere(n) {
        const me = monData
        if (!me) return
        if (me.active) {                                   // já focado -> troca direto
            proc.exec(["mmsg", "dispatch", "view," + n + ",0"])
            return
        }
        const list = mango ? (mango.monitors ?? []) : []
        const cur = list.find(m => m.active)
        let dir = "right"
        if (cur) {
            if ((me.x ?? 0) !== (cur.x ?? 0))      dir = (me.x > cur.x) ? "right" : "left"
            else if ((me.y ?? 0) !== (cur.y ?? 0)) dir = (me.y > cur.y) ? "down" : "up"
        }
        proc.exec(["sh", "-c", "mmsg dispatch focusmon," + dir + "; mmsg dispatch view," + n + ",0"])
    }

    // ── Submenu de layouts: posição de cada opção (lista curvada) ──
    function layoutPillX(i) {
        const t = (i + 0.5) / layoutItems.length
        return ballCX + layoutBow * Math.sin(t * Math.PI)
    }
    function layoutPillY(i) {
        return (ballCY - ballRadius - Config.layoutGap) - layoutRowH / 2 - i * layoutRowH
    }
    function layoutAt(mx, my) {
        const n = layoutItems.length
        for (let i = 0; i < n; i++)
            if (Math.abs(mx - layoutPillX(i)) <= layoutPillW / 2
             && Math.abs(my - layoutPillY(i)) <= layoutRowH / 2) return i
        return -1
    }

    // ── Pétalas multi-botão (áudio/captura) ─────────────
    // seção (0 = junto à bola … n-1 = na ponta) sob o cursor, dividindo a pétala em n
    function petalSectionAt(mx, my, n) {
        const dx = mx - ballCX, dy = ballCY - my
        const r = Math.sqrt(dx * dx + dy * dy)
        const r0 = petalDist - petalH / 2, r1 = petalDist + petalH / 2
        return Math.max(0, Math.min(n - 1, Math.floor((r - r0) / (r1 - r0) * n)))
    }
    // nº de seções da pétala i (áudio=3, captura=2, bandeja=nº de apps, demais=0)
    function petalSections(i) {
        if (i === audioIndex) return 3
        if (i === captureIndex) return 2
        if (i === trayIndex) return SystemTray.items.values.length
        return 0
    }
    // posição vertical de cada slider do submenu de áudio (0=headphone, 1=mic)
    function audioPillY(i) {
        return (ballCY - ballRadius - Config.layoutGap) - Config.audioSliderH / 2 - i * (Config.audioSliderH + 8)
    }
    function audioSliderAt(mx, my) {
        for (let i = 0; i < 2; i++)
            if (Math.abs(mx - ballCX) <= Config.audioSliderW / 2
             && Math.abs(my - audioPillY(i)) <= Config.audioSliderH / 2) return i
        return -1
    }

    // ── Hit-test (tudo por posição do cursor) ───────────
    // pétalas em anel: 1ª em 180°, +30° por pétala, circulando toda a bola (+ scroll).
    // (0°=direita, 90°=topo, 180°=esquerda; o ícone fica sempre na vertical pela contra-rotação)
    function petalAngle(i) { return Config.petalStartDeg + Config.petalDir * i * Config.petalStepDeg + petalRotation }
    function petalAt(mx, my) {
        const dx = mx - ballCX, dy = ballCY - my
        const r = Math.sqrt(dx * dx + dy * dy)
        const n = menuItems.length
        if (n === 0 || r <= ballRadius || r > hitOuterR) return -1
        const theta = Math.atan2(dy, dx) * 180 / Math.PI
        let best = -1, bestDiff = 1e9
        for (let i = 0; i < n; i++) {
            const d = Math.abs(((theta - petalAngle(i) + 540) % 360) - 180)
            if (d < bestDiff) { bestDiff = d; best = i }
        }
        return bestDiff <= Config.petalStepDeg / 2 ? best : -1   // tolerância = metade do passo
    }
    function dotAt(mx, my) {
        const n = tags.length
        for (let i = 0; i < n; i++) {
            const ang = (-90 + i * 360 / Math.max(1, n)) * Math.PI / 180
            const dxp = ballCX + dotRingR * Math.cos(ang)
            const dyp = ballCY + dotRingR * Math.sin(ang)
            if (Math.hypot(mx - dxp, my - dyp) <= Config.dotHitR) return i
        }
        return -1
    }
    function overBallAt(mx, my) { return Math.hypot(mx - ballCX, my - ballCY) <= ballRadius }
    // fecha o menu (usado antes de capturas, p/ não roubar o arrasto do slurp)
    function closeMenu() { dismissed = true; pinned = false }

    function refreshHover() {
        const mx = hoverMA.mouseX, my = hoverMA.mouseY
        if (!hoverMA.containsMouse) {
            overBall = false; hoverIndex = -1; petalSection = -1; audioSliderHover = -1
        } else {
            overBall = overBallAt(mx, my)
            if (audioMode) {
                hoverIndex = -1; petalSection = -1
                audioSliderHover = overBall ? -1 : audioSliderAt(mx, my)
            } else if (layoutMode) {
                hoverIndex = overBall ? -1 : layoutAt(mx, my); petalSection = -1; audioSliderHover = -1
            } else {
                hoverIndex = overBall ? -1 : petalAt(mx, my)
                const ns = petalSections(hoverIndex)
                petalSection = ns > 0 ? petalSectionAt(mx, my, ns) : -1
                audioSliderHover = -1
            }
        }
        if (overBall || hoverIndex !== -1 || audioSliderHover !== -1) { hoverCloseTimer.stop(); hoverOpen = true }
        else hoverCloseTimer.restart()
    }

    // processo p/ comandos one-shot (mmsg view/setlayout, ações das pétalas)
    Process { id: proc }

    // menu nativo do item da bandeja (system tray), aberto no clique direito
    property real trayMenuX: 0
    property real trayMenuY: 0
    QsMenuAnchor {
        id: trayMenu
        anchor.window: win
        anchor.rect.x: win.trayMenuX
        anchor.rect.y: win.trayMenuY
        anchor.rect.width: 1
        anchor.rect.height: 1
    }

    // ── Máscara de input ────────────────────────────────
    //  Fechado: só a bola é clicável. Aberto: só a região central (resto = click-through).
    mask: Region {
        shape: win.open ? RegionShape.Rect : RegionShape.Ellipse
        x: win.open ? Math.round(win.ballCX - win.menuHalf) : Math.round(win.ballCX - win.ballRadius)
        y: win.open ? 0 : Math.round(win.ballCY - win.ballRadius)
        width: win.open ? Math.round(win.menuHalf * 2) : Math.round(win.ballRadius * 2)
        height: win.open ? win.height : Math.round(win.ballRadius * 2)
    }

    // ── Componentes visuais ─────────────────────────────
    CavaRing { ctx: win }                                   // anel de áudio (atrás da bola)

    Repeater {                                              // pétalas
        model: win.menuItems
        delegate: Petal { ctx: win }
    }

    LayoutMenu { ctx: win }                                 // submenu de layouts
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
            // Botão direito: só age na pétala da bandeja -> abre o menu do app (sair/fechar etc)
            if (mouse.button === Qt.RightButton) {
                if (win.petalAt(mouseX, mouseY) === win.trayIndex) {
                    const items = SystemTray.items.values
                    const s = items.length > 0 ? win.petalSectionAt(mouseX, mouseY, items.length) : -1
                    const it = s >= 0 ? items[s] : null
                    if (it && it.menu) {
                        win.trayMenuX = Math.round(mouseX)
                        win.trayMenuY = Math.round(mouseY)
                        trayMenu.menu = it.menu
                        trayMenu.open()
                    }
                }
                return
            }
            // ===== a partir daqui: botão esquerdo (comportamento normal) =====
            // 1) ponto de workspace?
            const di = win.dotAt(mouseX, mouseY)
            if (di >= 0) {
                win.viewTagHere(win.tags[di].index)   // troca no monitor DESTA bola
                return
            }
            // 2) bola?
            if (win.overBallAt(mouseX, mouseY)) {
                if (win.audioMode)  { win.audioMode = false; return }   // volta ao menu principal
                if (win.layoutMode) { win.layoutMode = false; return }  // volta ao menu principal
                if (win.pinned) { win.pinned = false; win.dismissed = true }
                else            { win.pinned = true;  win.dismissed = false }
                return
            }
            // 3) submenu de layouts -> escolher na lista
            if (win.layoutMode) {
                const li = win.layoutAt(mouseX, mouseY)
                if (li >= 0) {
                    proc.exec(["mmsg", "dispatch", "setlayout," + win.layoutItems[li].name])
                    selectTimer.restart()
                } else {
                    win.pinned = false
                }
                return
            }
            // 3b) submenu de áudio -> clique no slider não faz nada (scroll ajusta); fora recolhe
            if (win.audioMode) {
                if (win.audioSliderAt(mouseX, mouseY) < 0) win.pinned = false
                return
            }
            // 4) pétala?
            const pi = win.petalAt(mouseX, mouseY)
            if (pi >= 0) {
                if (pi === win.audioIndex) {
                    // 5ª pétala (áudio): seção define a ação
                    const s = win.petalSectionAt(mouseX, mouseY, 3)
                    if (s === 2)      AudioService.toggleSinkMute()    // headphone (saída)
                    else if (s === 1) AudioService.toggleSourceMute()  // microfone (entrada)
                    else if (s === 0) win.audioMode = true             // config (abre sliders)
                } else if (pi === win.captureIndex) {
                    // 4ª pétala (captura): topo = print, base = gravar/parar
                    const s = win.petalSectionAt(mouseX, mouseY, 2)
                    if (s === 1) {
                        win.closeMenu(); CaptureService.screenshot()       // print (fecha o menu p/ não atrapalhar)
                    } else if (CaptureService.recording) {
                        CaptureService.stopRecording()                     // parar gravação
                    } else {
                        // grava este monitor inteiro (a tela é escolhida por qual bola se clica)
                        win.closeMenu(); CaptureService.startRecording(win.modelData.name)
                    }
                } else if (pi === win.trayIndex) {
                    // 7ª pétala (bandeja): esquerdo = ação padrão do app (foca/alterna a janela)
                    const items = SystemTray.items.values
                    if (items.length > 0) {
                        const it = items[win.petalSectionAt(mouseX, mouseY, items.length)]
                        if (it) it.activate()
                    }
                } else if (pi === 0) {
                    win.layoutMode = true   // 1ª pétala = abre o submenu de layouts
                } else {
                    const cmd = win.menuItems[pi].command ?? []
                    if (cmd.length > 0) proc.exec(cmd)
                    win.selectedIndex = pi
                    selectTimer.restart()
                }
                return
            }
            // 5) fora -> recolhe
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
                // na região das pétalas (aberto, fora da bola) -> gira o anel
                if (win.open && !win.overBall && !win.layoutMode) {
                    win.petalRotation += dir * Config.petalStepDeg
                    return
                }
                // sobre a bola (ou fechado) -> troca de workspace DESTE monitor
                const total = win.tags.length
                if (total === 0) return
                const cur = win.activeTag > 0 ? win.activeTag : 1
                const next = ((cur - 1 + dir + total) % total) + 1
                if (next !== cur)
                    win.viewTagHere(next)
            }
        }
    }
}
