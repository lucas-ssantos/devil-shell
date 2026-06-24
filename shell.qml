import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    MangoLayout { id: mango }

    // ── CAVA: visualizador de áudio (saída raw via stdout) ──
    // cada frame vira um array de níveis 0..1 (mesmo p/ todos os monitores)
    property var cavaLevels: []
    Process {
        id: cavaProc
        command: ["cava", "-p", "/home/luke/.config/quickshell/cava.conf"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";")
                const arr = []
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue
                    arr.push(parseInt(parts[i]) / 1000)
                }
                if (arr.length > 0) root.cavaLevels = arr
            }
        }
    }
    Timer { interval: 2000; running: !cavaProc.running; onTriggered: cavaProc.running = true }

    // ──────────────────────────────────────────────────────────────
    //  Itens das pétalas (submenus). 100% data-driven: adicione/remova
    //  itens aqui e as pétalas se reorganizam sozinhas no semicírculo.
    //  Cada item: { icon: "símbolo", label: "nome", command: [argv] }
    //  command vazio ([]) = sem ação (placeholder).
    // ──────────────────────────────────────────────────────────────
    readonly property var menuItems: [
        { icon: "★", label: "Item 1", command: [] },
        { icon: "◆", label: "Item 2", command: [] },
        { icon: "●", label: "Item 3", command: [] },
        { icon: "▲", label: "Item 4", command: [] },
        { icon: "■", label: "Item 5", command: [] }
    ]

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                property var modelData
                screen: modelData

                color: "transparent"
                anchors { bottom: true; left: true; right: true }   // largura total -> barra atravessa a tela
                exclusiveZone: 0
                implicitHeight: 220

                // ── Geometria do menu ──────────────────────────────
                readonly property real ballRadius: 46
                readonly property real ballCX: width / 2
                // bola "espreitando": em repouso o centro fica abaixo da tela (só uma
                // fatia de `ballPeek` px aparece); ao abrir, sobe e fica toda visível.
                readonly property real ballPeek: 28
                readonly property real ballCYRest: height - ballPeek + ballRadius
                readonly property real ballCYOpen: height - ballRadius
                property real ballCY: open ? ballCYOpen : ballCYRest
                Behavior on ballCY { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                readonly property real petalW: 26
                readonly property real petalH: 84
                readonly property real petalDist: ballRadius + 10 + petalH / 2   // centro-bola → centro-pétala
                readonly property real petalShrink: 0.8                          // escala das pétalas não-hover
                readonly property real petalTouch: ballRadius + petalH * petalShrink / 2  // recuada encostando na bola
                readonly property real hitOuterR: petalDist + petalH / 2 + 8     // alcance do hit-test das pétalas
                readonly property real menuHalf: hitOuterR + 16                  // meia-largura interativa qdo aberto
                readonly property real dotRingR: ballRadius * 0.62
                readonly property real gothicR: 32   // raio do "canto gótico" (filete bola ↔ barra) — mais presença
                readonly property real cavaMaxH: 120 // altura máx das barras lineares do cava
                readonly property real cavaRadMax: 38 // comprimento máx dos espetos radiais do cava

                // ── Estado de abertura ──────────────────────────────
                property bool pinned: false        // travado por clique na bola
                property bool dismissed: false     // fecha à força mesmo com hover (até o cursor sair)
                property bool overBall: false       // cursor sobre a bola
                property int  hoverIndex: -1        // pétala sob o cursor (-1 = nenhuma)
                property int  selectedIndex: -1     // pétala clicada (anim. de "as outras somem")
                // hover COM debounce: um leave/enter transitório (ao recomitar a máscara)
                // não recolhe o menu sem querer.
                property bool hoverOpen: false
                readonly property bool open: !dismissed && (pinned || hoverOpen)

                // só libera o "dismissed" quando o cursor realmente sai (hoverOpen cai)
                onHoverOpenChanged: if (!hoverOpen) dismissed = false

                Timer { id: hoverCloseTimer; interval: 130; onTriggered: win.hoverOpen = false }
                // após clicar numa pétala: destaca-a um instante e fecha
                Timer {
                    id: selectTimer
                    interval: 200
                    onTriggered: { win.dismissed = true; win.pinned = false; win.selectedIndex = -1 }
                }

                // relógio (tick por minuto) p/ o texto sobre a bola escondida
                SystemClock { id: sysClock; precision: SystemClock.Minutes }
                readonly property string clockText: Qt.formatDateTime(sysClock.date, "d/M HH:mm")

                // ── Estado do MangoWC p/ ESTE monitor ───────────────
                readonly property var monData: {
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

                // ── Hit-test (tudo por posição do cursor) ───────────
                // ângulo (graus) da pétala i: i=0 à esquerda (158°) … direita (22°); centro 90°
                function petalAngle(i) {
                    const n = root.menuItems.length
                    return n <= 1 ? 90 : 158 - i * (158 - 22) / (n - 1)
                }
                // índice da pétala sob (mx,my) ou -1
                function petalAt(mx, my) {
                    const dx = mx - ballCX
                    const dy = ballCY - my            // pra cima é positivo
                    const r = Math.sqrt(dx * dx + dy * dy)
                    const n = root.menuItems.length
                    if (n === 0 || r <= ballRadius || r > hitOuterR) return -1
                    const theta = Math.atan2(dy, dx) * 180 / Math.PI
                    let best = -1, bestDiff = 1e9
                    for (let i = 0; i < n; i++) {
                        const d = Math.abs(theta - petalAngle(i))
                        if (d < bestDiff) { bestDiff = d; best = i }
                    }
                    const spacing = n > 1 ? (158 - 22) / (n - 1) : 140
                    return bestDiff <= spacing / 2 + 2 ? best : -1
                }
                // índice (na lista tags) do ponto de workspace sob (mx,my) ou -1
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
                function overBallAt(mx, my) {
                    return Math.hypot(mx - ballCX, my - ballCY) <= ballRadius
                }

                function refreshHover() {
                    if (!hoverMA.containsMouse) {
                        overBall = false; hoverIndex = -1
                    } else {
                        overBall = overBallAt(hoverMA.mouseX, hoverMA.mouseY)
                        hoverIndex = overBall ? -1 : petalAt(hoverMA.mouseX, hoverMA.mouseY)
                    }
                    if (overBall || hoverIndex !== -1) { hoverCloseTimer.stop(); hoverOpen = true }
                    else hoverCloseTimer.restart()
                }

                // Processo p/ comandos one-shot (mmsg view, ações das pétalas)
                Process { id: proc }

                // ── Máscara de input ────────────────────────────────
                //  Fechado: só a bola é clicável (resto da janela = click-through).
                //  Aberto: janela toda ativa (mover entre pétalas / clicar fora).
                mask: Region {
                    shape: win.open ? RegionShape.Rect : RegionShape.Ellipse
                    // aberto: só a região central (bola + pétalas) é interativa; o resto da
                    // barra de largura total continua click-through.
                    x: win.open ? Math.round(win.ballCX - win.menuHalf) : Math.round(win.ballCX - win.ballRadius)
                    y: win.open ? 0 : Math.round(win.ballCY - win.ballRadius)
                    width: win.open ? Math.round(win.menuHalf * 2) : Math.round(win.ballRadius * 2)
                    height: win.open ? win.height : Math.round(win.ballRadius * 2)
                }

                // ── CAVA: barras lineares atrás de tudo (sobem da barra de fundo) ──
                Repeater {
                    model: root.cavaLevels.length
                    delegate: Rectangle {
                        required property int index
                        readonly property real slot: win.width / Math.max(1, root.cavaLevels.length)
                        readonly property real bx: slot * (index + 0.5)
                        readonly property real v: root.cavaLevels[index] ?? 0
                        z: 0
                        width: Math.max(2, slot * 0.6)
                        x: bx - width / 2
                        height: Math.max(0, v) * win.cavaMaxH
                        y: win.height - height
                        radius: width / 2
                        color: "#cba6f7"
                        opacity: 0.4
                        // some sobre a bola (contorno) — ali quem aparece é o anel radial
                        visible: Math.abs(bx - win.ballCX) > win.ballRadius + 10
                    }
                }

                // ── CAVA: anel radial em volta da bola (atrás dela) ──
                Repeater {
                    model: root.cavaLevels.length
                    delegate: Rectangle {
                        required property int index
                        readonly property int n: root.cavaLevels.length
                        readonly property real ang: index / Math.max(1, n) * 2 * Math.PI - Math.PI / 2
                        readonly property real v: root.cavaLevels[index] ?? 0
                        z: 0
                        width: 3
                        radius: 1.5
                        height: Math.max(0, v) * win.cavaRadMax           // espeto a partir da borda da bola
                        x: win.ballCX + win.ballRadius * Math.cos(ang) - width / 2
                        y: win.ballCY + win.ballRadius * Math.sin(ang)
                        transformOrigin: Item.Top
                        rotation: 90 - ang * 180 / Math.PI                // aponta radialmente p/ fora
                        color: "#cba6f7"
                        opacity: 0.55
                    }
                }

                // ── Pétalas (auto-organizadas; só visuais) ───────────
                Repeater {
                    model: root.menuItems

                    delegate: Item {
                        id: petal
                        required property var modelData
                        required property int index

                        readonly property real angleDeg: win.petalAngle(index)
                        readonly property real angleRad: angleDeg * Math.PI / 180
                        readonly property bool hovered: win.hoverIndex === index
                        readonly property bool selected: win.selectedIndex === index
                        readonly property bool vanished: win.selectedIndex !== -1 && !selected

                        width: win.petalW
                        height: win.petalH
                        transformOrigin: Item.Center
                        rotation: 90 - angleDeg
                        z: 1

                        property real dist: !win.open ? 0
                            : (hovered || selected)     ? win.petalDist
                            : (win.hoverIndex !== -1)   ? win.petalTouch   // outra em hover -> recua até a bola
                            : win.petalDist
                        x: win.ballCX + dist * Math.cos(angleRad) - width / 2
                        y: win.ballCY - dist * Math.sin(angleRad) - height / 2

                        opacity: (win.open && !vanished) ? 1.0 : 0.0

                        Behavior on dist { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        // crescimento do hover só no visual (não afeta hit-test)
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            transformOrigin: Item.Center
                            scale: (petal.hovered || petal.selected) ? 1.2
                                 : (win.hoverIndex !== -1)           ? win.petalShrink   // outra em hover -> encolhe
                                 : 1.0
                            color: petal.hovered ? "#f38ba8" : "#eba0ac"
                            Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }
                        }

                        Text {
                            anchors.centerIn: parent
                            rotation: -petal.rotation
                            text: petal.modelData.icon ?? ""
                            font.pixelSize: 16
                            color: "#1e1e2e"
                        }
                    }
                }

                // ── Barra fina no fundo da tela (a bola se funde nela) ──
                Rectangle {
                    z: 2
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: "#11111b"
                }

                // ── Cantos góticos: filetes côncavos ligando a bola à barra ──
                Canvas {
                    id: gothic
                    z: 2
                    anchors.fill: parent
                    antialiasing: true
                    property real cy: win.ballCY      // repinta enquanto a bola sobe/desce
                    onCyChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    // arco menor (determinístico) de P1 a P2 em torno de C
                    function arcMinor(ctx, C, P1, P2) {
                        const r = Math.hypot(P1.x - C.x, P1.y - C.y)
                        const a1 = Math.atan2(P1.y - C.y, P1.x - C.x)
                        const a2 = Math.atan2(P2.y - C.y, P2.x - C.x)
                        let d = a2 - a1
                        while (d <= -Math.PI) d += 2 * Math.PI
                        while (d >   Math.PI) d -= 2 * Math.PI
                        ctx.arc(C.x, C.y, r, a1, a2, d < 0)
                    }
                    // adiciona o subpath de um filete (s = +1 direito, -1 esquerdo)
                    function addLobe(ctx, s) {
                        const cx = win.ballCX, cyc = win.ballCY, R = win.ballRadius
                        const baseY = height, f = win.gothicR
                        const dyc = baseY - cyc
                        if (Math.abs(dyc) > R) return            // círculo não cruza a borda
                        const xc = Math.sqrt(R * R - dyc * dyc)  // cruzamento círculo × borda
                        const vy = (baseY - f) - cyc
                        if ((R + f) <= Math.abs(vy)) return
                        const xf = Math.sqrt((R + f) * (R + f) - vy * vy)
                        const k = R / (R + f)
                        const P  = { x: cx + s * xc,     y: baseY }       // cruzamento
                        const BR = { x: cx + s * xf,     y: baseY }       // base do filete
                        const F  = { x: cx + s * xf,     y: baseY - f }   // centro do filete
                        const T  = { x: cx + s * k * xf, y: cyc + k * vy } // tangente no círculo
                        const C  = { x: cx, y: cyc }
                        ctx.moveTo(P.x, P.y)
                        ctx.lineTo(BR.x, BR.y)
                        arcMinor(ctx, F, BR, T)   // filete côncavo (borda → círculo)
                        arcMinor(ctx, C, T, P)    // de volta pelo círculo até o cruzamento
                        ctx.closePath()
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = "#11111b"
                        // só os filetes; eles entram um pouco por baixo da bola (overlap)
                        ctx.beginPath()
                        addLobe(ctx, 1)
                        addLobe(ctx, -1)
                        ctx.fill()
                    }
                }

                // ── A bola (o "menu"; só visual) ─────────────────────
                Rectangle {
                    id: ball
                    z: 3
                    // ~2px maior que o raio usado pelos filetes: cobre a junção (overlap), sem emenda
                    readonly property real r2: win.ballRadius + 2
                    width: r2 * 2
                    height: width
                    radius: width / 2
                    x: win.ballCX - r2
                    y: win.ballCY - r2
                    color: "#11111b"
                    antialiasing: true
                    border.width: 0

                    // número do workspace ativo no centro (o "contador")
                    Text {
                        anchors.centerIn: parent
                        text: win.activeTag > 0 ? win.activeTag : ""
                        color: "#a6e3a1"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    // workspaces em anel (ativo destacado)
                    Repeater {
                        model: win.tags
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            readonly property int n: win.tags.length
                            readonly property real a: (-90 + index * 360 / Math.max(1, n)) * Math.PI / 180
                            readonly property bool active: modelData.is_active

                            width: active ? 11 : 8
                            height: width
                            radius: width / 2
                            x: ball.width / 2 + win.dotRingR * Math.cos(a) - width / 2
                            y: ball.height / 2 + win.dotRingR * Math.sin(a) - height / 2
                            color: active                  ? "#a6e3a1"
                                 : modelData.is_urgent     ? "#f38ba8"
                                 : modelData.client_count > 0 ? "#5c7a52"
                                 : "#45475a"
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }
                    }
                }

                // ── Data/hora inclinada sobre a bola (só quando escondida) ──
                Text {
                    id: clockLabel
                    z: 4
                    text: win.clockText
                    color: "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                    rotation: 0
                    transformOrigin: Item.Center
                    x: win.ballCX - width / 2
                    y: (win.height - win.ballPeek) - height - 5   // logo acima da fatia, sobrepondo um tico
                    opacity: win.open ? 0 : 1
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // ── MouseArea única no TOPO: hover + TODOS os cliques ─
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
                        // 2) bola? -> alterna travado
                        if (win.overBallAt(mouseX, mouseY)) {
                            if (win.pinned) { win.pinned = false; win.dismissed = true }
                            else            { win.pinned = true;  win.dismissed = false }
                            return
                        }
                        // 3) pétala? -> executa, as demais somem, destaca e fecha
                        const pi = win.petalAt(mouseX, mouseY)
                        if (pi >= 0) {
                            const cmd = root.menuItems[pi].command ?? []
                            if (cmd.length > 0) proc.exec(cmd)
                            win.selectedIndex = pi
                            selectTimer.restart()
                            return
                        }
                        // 4) fora -> recolhe
                        win.pinned = false
                    }
                }

                // ── Captura de scroll (Item no topo; não bloqueia hover/clique) ──
                Item {
                    anchors.fill: parent
                    z: 20
                    WheelHandler {
                        id: wsScroll
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => {
                            const total = win.tags.length
                            if (total === 0) return
                            const cur = win.activeTag > 0 ? win.activeTag : 1
                            const delta = event.angleDelta.y > 0 ? -1 : 1        // cima = anterior
                            const next = ((cur - 1 + delta + total) % total) + 1 // dá a volta (1↔total)
                            if (next !== cur)
                                proc.exec(["mmsg", "dispatch", "view," + next + ",0"])
                        }
                    }
                }
            }
        }
    }
}
