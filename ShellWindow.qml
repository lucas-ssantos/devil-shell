import Quickshell
import Quickshell.Io
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
    implicitHeight: 360   // espaço extra acima da bola p/ o submenu de layouts

    // ── Geometria ──────────────────────────────────────
    readonly property real ballRadius: 46
    readonly property real ballCX: width / 2
    readonly property real ballPeek: 28
    readonly property real ballCYRest: height - ballPeek + ballRadius
    readonly property real ballCYOpen: height - ballRadius
    property real ballCY: open ? ballCYOpen : ballCYRest
    Behavior on ballCY { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property real petalW: 26
    readonly property real petalH: 84
    readonly property real petalDist: ballRadius + 10 + petalH / 2
    readonly property real petalShrink: 0.8
    readonly property real petalTouch: ballRadius + petalH * petalShrink / 2
    readonly property real petalFlare: 8
    readonly property real hitOuterR: petalDist + petalH / 2 + 8
    readonly property real menuHalf: hitOuterR + 16
    readonly property real dotRingR: ballRadius * 0.62
    readonly property real gothicR: 32
    readonly property real cavaRadMax: 55
    readonly property real layoutRowH: 23
    readonly property real layoutPillW: 132
    readonly property real layoutBow: 38
    property real petalRotation: 0
    Behavior on petalRotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // ── Estado de abertura ──────────────────────────────
    property bool pinned: false
    property bool dismissed: false
    property bool overBall: false
    property int  hoverIndex: -1
    property int  selectedIndex: -1
    property bool layoutMode: false
    property bool hoverOpen: false
    readonly property bool open: !dismissed && (pinned || hoverOpen)
    onHoverOpenChanged: if (!hoverOpen) dismissed = false
    onOpenChanged: if (!open) { selectedIndex = -1; layoutMode = false }

    Timer { id: hoverCloseTimer; interval: 130; onTriggered: win.hoverOpen = false }
    Timer { id: selectTimer; interval: 200; onTriggered: { win.dismissed = true; win.pinned = false; win.selectedIndex = -1 } }

    // relógio (tick por minuto) p/ o texto sobre a bola escondida
    SystemClock { id: sysClock; precision: SystemClock.Minutes }
    readonly property string clockText: Qt.formatDateTime(sysClock.date, "d/M HH:mm")

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

    // ── Submenu de layouts: posição de cada opção (lista curvada) ──
    function layoutPillX(i) {
        const t = (i + 0.5) / layoutItems.length
        return ballCX + layoutBow * Math.sin(t * Math.PI)
    }
    function layoutPillY(i) {
        return (ballCY - ballRadius - 8) - layoutRowH / 2 - i * layoutRowH
    }
    function layoutAt(mx, my) {
        const n = layoutItems.length
        for (let i = 0; i < n; i++)
            if (Math.abs(mx - layoutPillX(i)) <= layoutPillW / 2
             && Math.abs(my - layoutPillY(i)) <= layoutRowH / 2) return i
        return -1
    }

    // ── Hit-test (tudo por posição do cursor) ───────────
    // pétalas em anel: 30° entre cada, partindo de 0° (+ rotação do scroll)
    function petalAngle(i) { return i * 30 + petalRotation }
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
        return bestDiff <= 15 ? best : -1   // tolerância = metade dos 30°
    }
    function dotAt(mx, my) {
        const n = tags.length
        for (let i = 0; i < n; i++) {
            const ang = (-90 + i * 360 / Math.max(1, n)) * Math.PI / 180
            const dxp = ballCX + dotRingR * Math.cos(ang)
            const dyp = ballCY + dotRingR * Math.sin(ang)
            if (Math.hypot(mx - dxp, my - dyp) <= 9) return i
        }
        return -1
    }
    function overBallAt(mx, my) { return Math.hypot(mx - ballCX, my - ballCY) <= ballRadius }

    function refreshHover() {
        if (!hoverMA.containsMouse) {
            overBall = false; hoverIndex = -1
        } else {
            overBall = overBallAt(hoverMA.mouseX, hoverMA.mouseY)
            hoverIndex = overBall ? -1
                : (layoutMode ? layoutAt(hoverMA.mouseX, hoverMA.mouseY)
                              : petalAt(hoverMA.mouseX, hoverMA.mouseY))
        }
        if (overBall || hoverIndex !== -1) { hoverCloseTimer.stop(); hoverOpen = true }
        else hoverCloseTimer.restart()
    }

    // processo p/ comandos one-shot (mmsg view/setlayout, ações das pétalas)
    Process { id: proc }

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

    // barra fina no fundo (a bola se funde nela)
    Rectangle {
        z: 2
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: "#11111b"
    }

    GothicCorners { ctx: win }                              // filetes bola ↔ barra
    MenuBall { ctx: win }                                   // a bola

    // data/hora inclinada sobre a bola (só quando escondida)
    Text {
        z: 4
        text: win.clockText
        color: "#cdd6f4"
        font.pixelSize: 13
        font.bold: true
        transformOrigin: Item.Center
        x: win.ballCX - width / 2
        y: (win.height - win.ballPeek) - height - 5
        opacity: win.open ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // ── Entrada: hover + TODOS os cliques (por hit-test) ──
    MouseArea {
        id: hoverMA
        anchors.fill: parent
        z: 10
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onEntered: win.refreshHover()
        onPositionChanged: win.refreshHover()
        onExited: win.refreshHover()

        onClicked: {
            // 1) ponto de workspace?
            const di = win.dotAt(mouseX, mouseY)
            if (di >= 0) {
                proc.exec(["mmsg", "dispatch", "view," + win.tags[di].index + ",0"])
                return
            }
            // 2) bola?
            if (win.overBallAt(mouseX, mouseY)) {
                if (win.layoutMode) { win.layoutMode = false; return }  // volta ao menu principal
                if (win.pinned) { win.pinned = false; win.dismissed = true }
                else            { win.pinned = true;  win.dismissed = false }
                return
            }
            // 3) submenu de layouts aberto -> escolher na lista
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
            // 4) pétala?
            const pi = win.petalAt(mouseX, mouseY)
            if (pi >= 0) {
                if (pi === 0) {
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
                const dir = event.angleDelta.y > 0 ? -1 : 1
                // na região das pétalas (aberto, fora da bola) -> gira o anel
                if (win.open && !win.overBall && !win.layoutMode) {
                    win.petalRotation += dir * 30
                    return
                }
                // sobre a bola (ou fechado) -> troca de workspace
                const total = win.tags.length
                if (total === 0) return
                const cur = win.activeTag > 0 ? win.activeTag : 1
                const next = ((cur - 1 + dir + total) % total) + 1
                if (next !== cur)
                    proc.exec(["mmsg", "dispatch", "view," + next + ",0"])
            }
        }
    }
}
