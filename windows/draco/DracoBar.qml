import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import "root:/ui"         // DracoCapsule, CalendarPopup, TempPopup, RamPopup, TrayMenu, AudioDevices
import "root:/services"   // AudioService, CaptureService, IdleService, LauncherService, SensorsService, Settings
import "root:/"           // Config (raiz)

// Barra do modo DRACO (uma por monitor): substitui bola/cristais/cápsulas por uma barra
// COLADA no topo, estilo Noctalia — ocupa uma fração da largura da tela (centralizada),
// cantos arredondados só embaixo, fundo translúcido e uma SOMBRA difusa por trás — e
// reserva espaço (exclusive zone) p/ as janelas do niri ficarem abaixo dela; o niri ainda
// soma os `gaps` dele entre a barra e a janela (Config.dracoGap é folga EXTRA).
// Os widgets são "chapados" (sem pílula própria) dentro de três chips discretos:
//   Esquerda: lançador · relógio (popup do calendário) · recursos RAM/CPU (popup do
//             sistema) · temperatura da CPU (popup de temperaturas)
//   Centro:   título da janela ATIVA deste monitor (com o ícone do app); sem janela no
//             workspace, as pílulas dos workspaces (clique troca; mín. Config.dracoWsMin)
//   Direita:  saída/microfone (esquerdo = mudo, scroll = volume, direito = dispositivos) ·
//             gravação de tela DESTE monitor · lock/idle (lâmpada) · configurações · bandeja
//             (esquerdo = foca a janela do app, direito = menu do app)
// Scroll no fundo da barra troca o workspace deste monitor (wrap 1↔N), como na bola.
// Só existe (visible) com Config.isDraco; fora disso não reserva espaço nenhum.
PanelWindow {
    id: bar
    property var modelData      // a screen (monitor)
    property var niri           // NiriService
    property var levels: []     // níveis do CavaService (mini-visualizador nos vãos da barra)
    property int menuCount: 0   // nº de cristais do modo devil (p/ esperar o afundar deles antes de entrar)

    screen: modelData
    // visibilidade gerida pela TRANSIÇÃO de modo (ver abaixo)
    visible: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    // a surface vai de ponta a ponta no topo: a barra (fração da largura) fica centralizada
    // dentro dela e a sombra cabe nas laterais/embaixo. Começa na BORDA da tela (sem margem)
    // p/ a barra poder deslizar de lá; a folga do topo (se houver) é desenhada dentro.
    anchors { top: true; left: true; right: true }
    // faixa extra p/ a sombra (embaixo): desfoque + deslocamento
    readonly property real shadowPad: Config.dracoShadowBlur > 0 ? Config.dracoShadowBlur + Config.dracoShadowOffsetY + 2 : 0
    implicitHeight: Config.dracoMarginTop + Config.dracoBarH + shadowPad
    // reserva folga do topo + barra + folga extra enquanto a barra está em cena (shown); a zona
    // cai junto com o deslizar de saída → as janelas do niri voltam a subir. Escondida → nada.
    // A faixa da sombra NÃO é reservada: ela cai sobre o gap/janelas, como uma sombra de verdade.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: shown ? Math.round(Config.dracoMarginTop + Config.dracoBarH + Config.dracoGap) : 0
    // só a barra recebe input; as laterais e a faixa da sombra são click-through
    mask: Region {
        x: Math.round(panel.x); y: Math.round(panel.y)
        width: Math.round(panel.width); height: Math.round(panel.height)
    }

    // ── Transição de modo (Config.isDraco) ──
    // Draco liga -> espera a bola/cristais afundarem (Config.modeSinkTotal) e entra deslizando da
    // borda superior (panel.y). Devil volta -> fecha popups, sai deslizando p/ cima e a janela é
    // escondida ao fim (dracoSlideMs). Boot já no draco: aparece direto.
    property bool shown: false
    property bool entering: false   // sentido do deslize em curso (setado ANTES de `shown`, p/ o easing)
    Component.onCompleted: if (Config.isDraco) visible = true   // boot já no draco: desliza assim que mapear
    // entrar: mostra a janela e só COMEÇA o deslize quando a surface estiver mapeada de fato
    // (backingWindowVisible) — senão a animação roda no vazio e a barra já aparece no lugar
    Timer { id: enterTimer; interval: Config.modeSinkTotal(bar.menuCount) + 40; onTriggered: bar.visible = true }
    Timer { id: enterStartTimer; interval: 40; onTriggered: { bar.entering = true; bar.shown = true } }
    Timer { id: leaveTimer; interval: Config.dracoSlideMs + 40; onTriggered: bar.visible = false }
    onBackingWindowVisibleChanged: if (backingWindowVisible && !shown && Config.isDraco) enterStartTimer.restart()
    Connections {
        target: Config
        function onIsDracoChanged() {
            if (Config.isDraco) {
                leaveTimer.stop()
                if (bar.visible && bar.backingWindowVisible) enterStartTimer.restart()   // ainda mapeada (toggle rápido)
                else enterTimer.restart()
            } else {
                enterTimer.stop(); enterStartTimer.stop()
                bar.closePopups(); trayMenu.visible = false; audioDevices.visible = false
                bar.entering = false; bar.shown = false
                leaveTimer.restart()
            }
        }
    }

    // ── Estado do niri p/ ESTE monitor ──
    readonly property var monData: (niri && modelData) ? niri.monitorByName(modelData.name) : null
    readonly property var tags: (monData && monData.tags) ? monData.tags : []
    readonly property int activeTag: {
        for (let i = 0; i < tags.length; i++)
            if (tags[i].is_active) return tags[i].index
        return 0
    }
    // pílulas de workspace: os reais + "fantasmas" até Config.dracoWsMin (só visuais)
    readonly property var wsList: {
        const out = tags.slice()
        for (let i = out.length; i < Config.dracoWsMin; i++)
            out.push({ index: i + 1, id: -1, is_active: false, is_urgent: false, client_count: 0, ghost: true })
        return out
    }
    // janela ativa do workspace ativo deste monitor (NiriService.activeWinByOutput)
    readonly property var activeWin: {
        if (!niri || !modelData) return null
        const m = niri.activeWinByOutput
        return (m && m[modelData.name]) ? m[modelData.name] : null
    }
    readonly property bool hasWin: activeWin !== null
    // ícone do app pela .desktop (heurística do Quickshell); "" se não achar
    readonly property string appIcon: {
        if (!activeWin || !activeWin.appId) return ""
        const e = DesktopEntries.heuristicLookup(activeWin.appId)
        return (e && e.icon) ? Quickshell.iconPath(e.icon, true) : ""
    }
    // troca de workspace por scroll (só entre os reais, wrap 1↔N)
    function switchWorkspace(dir) {
        const total = tags.length
        if (total === 0 || !niri) return
        const cur = activeTag > 0 ? activeTag : 1
        const next = ((cur - 1 + dir + total) % total) + 1
        if (next !== cur) niri.focusWorkspaceOn(modelData.name, next)
    }

    // relógio: precisão de segundos só se o formato mostrar segundos
    SystemClock {
        id: sysClock
        precision: Config.dracoClockFormat.indexOf("s") >= 0 ? SystemClock.Seconds : SystemClock.Minutes
    }

    // ── Popups (brotam abaixo do widget que os abre, centralizados nele) ──
    // ponto de ancoragem: centro-X do widget (coord. da janela) + base da barra
    function anchorOf(item) {
        const p = item.mapToItem(null, item.width / 2, 0)
        return { x: p.x, y: panel.y + panel.height }
    }
    function closePopups() { calendarPopup.close(); tempPopup.close(); ramPopup.close() }
    function togglePopup(popup, item) {
        const wasOpen = popup.visible
        closePopups()
        if (!wasOpen) { const a = anchorOf(item); popup.openAt(a.x, a.y) }
    }
    // O clique-direito que fecha o popup de dispositivos QUEBRA o grabFocus dele (o niri
    // some com a superfície) e ainda é reentregue ao widget — sem guarda, esse 2º evento
    // cairia aqui de novo com `audioDevices.visible` já falso e REABRIRIA o popup. Guardamos
    // quando/qual dispositivo fechou por último: um novo toggle do MESMO tipo logo em
    // seguida (mesma ação de clique) apenas mantém fechado; de outro tipo ainda troca.
    property double audioClosedAt: 0
    property string audioClosedKind: ""
    Connections {
        target: audioDevices
        function onVisibleChanged() {
            if (!audioDevices.visible) { bar.audioClosedAt = Date.now(); bar.audioClosedKind = audioDevices.kind }
        }
    }
    function toggleDevices(kind, item) {
        const justClosedSame = bar.audioClosedKind === kind && (Date.now() - bar.audioClosedAt) < 250
        if ((audioDevices.visible && audioDevices.kind === kind) || justClosedSame) {
            audioDevices.visible = false
            return
        }
        const a = anchorOf(item)
        audioDevices.openAt(kind, a.x, a.y)
    }
    CalendarPopup { id: calendarPopup; ctx: bar; floating: true }
    TempPopup     { id: tempPopup;     ctx: bar; floating: true }
    RamPopup      { id: ramPopup;      ctx: bar; floating: true }
    TrayMenu      { id: trayMenu;      ctx: bar; below: true }
    AudioDevices  { id: audioDevices;  ctx: bar; below: true }

    // chip: fundo discreto de um GRUPO de widgets (esquerda / centro / direita); os filhos
    // declarados dentro dele caem na Row interna
    component Chip: Rectangle {
        default property alias content: chipRow.data
        implicitWidth: chipRow.implicitWidth + 2 * Config.dracoChipPad
        implicitHeight: Config.dracoCapsuleH + 2 * Config.dracoChipPad
        radius: Config.dracoChipRadius
        color: Qt.rgba(Config.dracoCapsuleBg.r, Config.dracoCapsuleBg.g, Config.dracoCapsuleBg.b, Config.dracoChipOpacity)
        Row { id: chipRow; anchors.centerIn: parent; spacing: Config.dracoSpacing }
    }

    // ── Corpo da barra ──
    Item {
        id: panel
        width: Math.round(bar.width * Config.dracoWidthFrac)
        x: Math.round((bar.width - width) / 2)
        height: Config.dracoBarH
        // desliza da borda superior da tela: escondida, fica inteira (sombra incluída) acima da surface
        y: bar.shown ? Config.dracoMarginTop : -(Config.dracoBarH + bar.shadowPad + 2)
        Behavior on y { NumberAnimation { duration: Config.dracoSlideMs; easing.type: bar.entering ? Easing.OutCubic : Easing.InCubic } }

        // fundo + sombra. O Canvas é maior que a barra (margens negativas) p/ a sombra caber; a
        // sombra é pintada como halo da forma e depois a PRÓPRIA forma é recortada
        // (destination-out) — senão ela escureceria o fundo translúcido por baixo. Cantos de
        // baixo arredondados; os de cima só se houver folga do topo (barra "solta").
        Canvas {
            id: bgCanvas
            anchors.fill: parent
            anchors.margins: -bar.shadowPad
            antialiasing: true
            property color bg: Config.dracoBg
            property real  bgA: Config.dracoBgOpacity
            property color sh: Config.dracoShadow
            property real  shA: Config.dracoShadowOpacity
            property real  blur: Config.dracoShadowBlur
            property real  offY: Config.dracoShadowOffsetY
            property real  rad: Config.dracoRadius
            property real  topRad: Config.dracoMarginTop > 0 ? Config.dracoRadius : 0
            property color edge: Config.dracoBorder
            property real  edgeW: Config.dracoBorderW
            onBgChanged: requestPaint()
            onBgAChanged: requestPaint()
            onShChanged: requestPaint()
            onShAChanged: requestPaint()
            onBlurChanged: requestPaint()
            onOffYChanged: requestPaint()
            onRadChanged: requestPaint()
            onTopRadChanged: requestPaint()
            onEdgeChanged: requestPaint()
            onEdgeWChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            // caminho da barra: retângulo com cantos de cima `rt` e de baixo `rb`
            function shape(g, x, y, w, h, rt, rb) {
                g.beginPath()
                g.moveTo(x + rt, y)
                g.lineTo(x + w - rt, y)
                if (rt > 0) g.arcTo(x + w, y, x + w, y + rt, rt)
                g.lineTo(x + w, y + h - rb)
                g.arcTo(x + w, y + h, x + w - rb, y + h, rb)
                g.lineTo(x + rb, y + h)
                g.arcTo(x, y + h, x, y + h - rb, rb)
                g.lineTo(x, y + rt)
                if (rt > 0) g.arcTo(x, y, x + rt, y, rt)
                g.closePath()
            }
            onPaint: {
                const g = getContext("2d")
                g.reset()
                const p = bar.shadowPad
                const x = p, y = p, w = width - 2 * p, h = height - 2 * p
                if (w <= 0 || h <= 0) return
                const rb = Math.max(0, Math.min(rad, w / 2, h / 2))
                const rt = Math.max(0, Math.min(topRad, w / 2, h / 2))
                // 1) sombra: forma opaca com shadow; depois a forma é recortada -> sobra só o halo
                if (blur > 0 && shA > 0) {
                    g.save()
                    g.shadowColor = Qt.rgba(sh.r, sh.g, sh.b, shA)
                    g.shadowBlur = blur
                    g.shadowOffsetY = offY
                    g.fillStyle = "#000000"   // qualquer cor opaca: só a sombra sobrevive ao recorte
                    shape(g, x, y, w, h, rt, rb)
                    g.fill()
                    g.restore()
                    g.globalCompositeOperation = "destination-out"
                    shape(g, x, y, w, h, rt, rb)
                    g.fill()
                    g.globalCompositeOperation = "source-over"
                }
                // 2) corpo translúcido
                g.fillStyle = Qt.rgba(bg.r, bg.g, bg.b, bgA)
                shape(g, x, y, w, h, rt, rb)
                g.fill()
                // 3) borda opcional (dentro da forma)
                if (edgeW > 0) {
                    g.strokeStyle = edge
                    g.lineWidth = edgeW
                    shape(g, x + edgeW / 2, y + edgeW / 2, w - edgeW, h - edgeW, rt, rb)
                    g.stroke()
                }
            }
        }

        // scroll no fundo (e nos widgets que não consomem a roda) → workspace deste monitor
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (w) => bar.switchWorkspace(w.angleDelta.y > 0 ? -1 : 1)   // cima = anterior
        }

        // ══ Visualizador CAVA: forma de onda APENAS nos vãos (chip central ↔ chips laterais) ══
        // Não passa por trás dos widgets. Metade do espectro em cada vão; o chip central
        // fica no lugar da quebra do meio. Puramente visual (o scroll segue p/ o MouseArea
        // acima). Some se o vão ficar estreito demais (título de janela longo no centro).
        DracoCava {
            id: cavaLeft
            visible: Config.dracoCavaEnabled && bar.shown && width >= Config.dracoCavaMinW
            levels: bar.levels
            segment: "left"
            height: parent.height
            anchors {
                left: leftChip.right; right: centerChip.left
                leftMargin: Config.dracoPad; rightMargin: Config.dracoPad
                verticalCenter: parent.verticalCenter
            }
        }
        DracoCava {
            id: cavaRight
            visible: Config.dracoCavaEnabled && bar.shown && width >= Config.dracoCavaMinW
            levels: bar.levels
            segment: "right"
            height: parent.height
            anchors {
                left: centerChip.right; right: rightChip.left
                leftMargin: Config.dracoPad; rightMargin: Config.dracoPad
                verticalCenter: parent.verticalCenter
            }
        }

        // ══ Esquerda ══
        Chip {
            id: leftChip
            anchors { left: parent.left; leftMargin: Config.dracoPad; verticalCenter: parent.verticalCenter }

            DracoCapsule {                                   // lançador próprio
                icon: Config.iconLauncher
                iconColor: Config.dracoAccent
                active: LauncherService.open
                onClicked: LauncherService.toggle()
            }
            DracoCapsule {                                   // relógio → calendário
                id: clockCap
                icon: Config.iconClock
                label: Qt.formatDateTime(sysClock.date, Config.dracoClockFormat)
                active: calendarPopup.visible
                onClicked: bar.togglePopup(calendarPopup, clockCap)
            }
            DracoCapsule {                                   // recursos: RAM + CPU → popup do sistema
                id: resCap
                icon: Config.iconRam
                label: SensorsService.ramUsage
                //icon2: Config.iconCpu
                //label2: SensorsService.cpuUsage
                active: ramPopup.visible
                onClicked: bar.togglePopup(ramPopup, resCap)
            }
            DracoCapsule {                                   // temperatura da CPU → popup de temperaturas
                id: tempCap
                icon: Config.iconWeather
                label: SensorsService.cpuTemp
                active: tempPopup.visible
                onClicked: bar.togglePopup(tempPopup, tempCap)
            }
        }

        // ══ Centro: título da janela ativa OU pílulas de workspaces ══
        Chip {
            id: centerChip
            anchors.centerIn: parent
            // o título nunca invade os chips laterais: teto = o que sobra entre os dois
            readonly property real titleMaxW: Math.max(120, Math.min(Config.dracoTitleMaxW,
                panel.width - 2 * Math.max(leftChip.width, rightChip.width) - 6 * Config.dracoPad))

            DracoCapsule {
                id: titleCap
                visible: bar.hasWin
                image: bar.appIcon
                label: bar.activeWin ? (bar.activeWin.title || bar.activeWin.appId || "") : ""
                labelMaxW: centerChip.titleMaxW
                // apagado quando a janela ativa deste monitor não é a focada da sessão
                textColor: (bar.activeWin && bar.activeWin.focused) ? Config.dracoText : Config.dracoSub
                onClicked: if (bar.activeWin && bar.niri) bar.niri.focusWindow(bar.activeWin.id)
            }
            Row {
                id: wsRow
                visible: !bar.hasWin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                leftPadding: 4; rightPadding: 4
                Repeater {
                    model: bar.wsList
                    delegate: Rectangle {
                        id: pill
                        required property var modelData
                        readonly property bool isActive: modelData.is_active === true
                        readonly property bool ghost: modelData.ghost === true
                        readonly property bool busy: (modelData.client_count ?? 0) > 0
                        anchors.verticalCenter: parent.verticalCenter
                        height: Config.dracoCapsuleH - 4
                        // a ativa fica alongada (pílula), as outras quase redondas
                        width: Math.max(height, num.implicitWidth + 12) + (isActive ? 14 : 0)
                        radius: height / 2
                        color: isActive ? Config.dracoAccent : Config.dracoCapsuleHover
                        opacity: (isActive || pillMA.containsMouse) ? 1.0 : 0.8
                        border.width: modelData.is_urgent ? 1 : 0
                        border.color: Config.dotUrgent
                        Behavior on width { NumberAnimation { duration: Config.dracoAnim; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Config.dracoAnim } }
                        Text {
                            id: num
                            anchors.centerIn: parent
                            text: pill.modelData.index
                            font.pixelSize: Config.dracoTextSize
                            font.bold: pill.isActive || pill.busy
                            color: pill.isActive ? Config.dracoAccentText
                                 : pill.busy ? Config.dracoText : Config.dracoSub
                        }
                        MouseArea {
                            id: pillMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pill.ghost ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: if (!pill.ghost && bar.niri) bar.niri.focusWorkspaceOn(bar.modelData.name, pill.modelData.index)
                        }
                    }
                }
            }
        }

        // ══ Direita ══
        Chip {
            id: rightChip
            anchors { right: parent.right; rightMargin: Config.dracoPad; verticalCenter: parent.verticalCenter }

            DracoCapsule {                                   // saída (headphone)
                id: sinkCap
                icon: AudioService.sinkMuted ? Config.iconOutputMuted : Config.iconOutput
                iconColor: AudioService.sinkMuted ? Config.audioMutedColor : Config.dracoText
                label: Math.round(AudioService.sinkVolume * 100) + "%"
                textColor: AudioService.sinkMuted ? Config.dracoSub : Config.dracoText
                wheelEnabled: true
                active: audioDevices.visible && audioDevices.kind === "sink"
                onClicked: AudioService.toggleSinkMute()
                onWheel: (dir) => AudioService.addSinkVolume(dir * Config.volStep)
                onRightClicked: bar.toggleDevices("sink", sinkCap)
            }
            DracoCapsule {                                   // microfone
                id: sourceCap
                icon: AudioService.sourceMuted ? Config.iconInputMuted : Config.iconInput
                iconColor: AudioService.sourceMuted ? Config.audioMutedColor : Config.dracoText
                label: Math.round(AudioService.sourceVolume * 100) + "%"
                textColor: AudioService.sourceMuted ? Config.dracoSub : Config.dracoText
                wheelEnabled: true
                active: audioDevices.visible && audioDevices.kind === "source"
                onClicked: AudioService.toggleSourceMute()
                onWheel: (dir) => AudioService.addSourceVolume(dir * Config.volStep)
                onRightClicked: bar.toggleDevices("source", sourceCap)
            }
            DracoCapsule {                                   // gravação de tela DESTE monitor
                icon: CaptureService.recording ? Config.iconRecording : Config.iconRecord
                iconColor: CaptureService.recording ? Config.captureRecColor : Config.dracoText
                onClicked: CaptureService.toggleRecording(bar.modelData.name)
            }
            DracoCapsule {                                   // lock/idle: lâmpada acesa = inibido
                icon: Config.iconIdle
                iconColor: IdleService.inhibited ? Config.idleOnColor : Config.dracoText
                iconOpacity: IdleService.inhibited ? 1.0 : 0.55
                onClicked: IdleService.toggle()
            }
            DracoCapsule {                                   // configurações do shell
                icon: Config.iconConfig
                active: Settings.open
                onClicked: Settings.open = true
            }
            Row {                                            // bandeja (system tray): ícones chapados
                visible: SystemTray.items.values.length > 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                leftPadding: 5; rightPadding: 5
                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        id: trayCell
                        required property var modelData
                        width: Config.dracoIconSize + 4
                        height: Config.dracoCapsuleH
                        Image {
                            id: trayImg
                            // só aparece quando carregou (evita o ícone "quebrado" de SNIs tortos)
                            visible: status === Image.Ready
                            anchors.centerIn: parent
                            source: trayCell.modelData.icon
                            sourceSize.width: Config.dracoIconSize + 2
                            sourceSize.height: Config.dracoIconSize + 2
                            width: Config.dracoIconSize + 2
                            height: Config.dracoIconSize + 2
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Text {                               // fallback: inicial do app
                            visible: trayImg.status !== Image.Ready
                            anchors.centerIn: parent
                            text: (trayCell.modelData.title || trayCell.modelData.id || "?").charAt(0).toUpperCase()
                            font.pixelSize: Config.dracoIconSize
                            font.bold: true
                            color: Config.dracoText
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    if (trayMenu.visible) { trayMenu.visible = false; return }   // direito de novo fecha
                                    if (trayCell.modelData.menu) {
                                        const a = bar.anchorOf(trayCell)
                                        trayMenu.openAt(trayCell.modelData, a.x, a.y)
                                    }
                                } else if (bar.niri) {
                                    bar.niri.focusTrayApp(trayCell.modelData)   // esquerdo: traz/foca a janela do app
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
