import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import QtQuick
import "root:/ui"         // DracoCapsule, CalendarPopup, TempPopup, RamPopup, TrayMenu, AudioDevices
import "root:/services"   // AudioService, CaptureService, IdleService, LauncherService, SensorsService, Settings
import "root:/"           // Config (raiz)

// Barra do modo DRACO (uma por monitor): substitui bola/cristais/cápsulas por uma barra
// FLUTUANTE no topo, estilo Noctalia — não encosta nas bordas (margens), cantos
// arredondados, widgets em cápsulas — e reserva espaço (exclusive zone) p/ as janelas
// do niri ficarem abaixo dela; o niri ainda soma os `gaps` dele entre a barra e a
// janela (Config.dracoGap é folga EXTRA).
//   Esquerda: lançador · relógio (popup do calendário) · recursos RAM/CPU (popup do
//             sistema) · temperatura da CPU (popup de temperaturas)
//   Centro:   título da janela ATIVA deste monitor (com o ícone do app); sem janela no
//             workspace, as cápsulas dos workspaces (clique troca; mín. Config.dracoWsMin)
//   Direita:  saída/microfone (esquerdo = mudo, scroll = volume, direito = dispositivos) ·
//             gravação de tela DESTE monitor · lock/idle (lâmpada) · configurações · bandeja
//             (esquerdo = foca a janela do app, direito = menu do app)
// Scroll no fundo da barra troca o workspace deste monitor (wrap 1↔N), como na bola.
// Só existe (visible) com Config.isDraco; fora disso não reserva espaço nenhum.
PanelWindow {
    id: bar
    property var modelData      // a screen (monitor)
    property var niri           // NiriService

    screen: modelData
    visible: Config.isDraco
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    anchors { top: true; left: true; right: true }
    margins { top: Config.dracoMarginTop; left: Config.dracoMarginSide; right: Config.dracoMarginSide }
    implicitHeight: Config.dracoBarH
    // reserva barra + folga extra; a margem do topo o compositor soma sozinho (protocolo
    // layer-shell: "the exclusive zone includes the margin"). Escondida → não reserva nada.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Config.isDraco ? Math.round(Config.dracoBarH + Config.dracoGap) : 0

    // ── Estado do niri p/ ESTE monitor ──
    readonly property var monData: (niri && modelData) ? niri.monitorByName(modelData.name) : null
    readonly property var tags: (monData && monData.tags) ? monData.tags : []
    readonly property int activeTag: {
        for (let i = 0; i < tags.length; i++)
            if (tags[i].is_active) return tags[i].index
        return 0
    }
    // cápsulas de workspace: os reais + "fantasmas" até Config.dracoWsMin (só visuais)
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

    // ── Popups (brotam abaixo da cápsula que os abre, centralizados nela) ──
    // ponto de ancoragem: centro-X da cápsula (coord. da janela) + base da barra
    function anchorOf(item) {
        const p = item.mapToItem(null, item.width / 2, 0)
        return { x: p.x, y: bar.height }
    }
    function closePopups() { calendarPopup.close(); tempPopup.close(); ramPopup.close() }
    function togglePopup(popup, item) {
        const wasOpen = popup.visible
        closePopups()
        if (!wasOpen) { const a = anchorOf(item); popup.openAt(a.x, a.y) }
    }
    function toggleDevices(kind, item) {
        if (audioDevices.visible && audioDevices.kind === kind) { audioDevices.visible = false; return }
        const a = anchorOf(item)
        audioDevices.openAt(kind, a.x, a.y)
    }
    CalendarPopup { id: calendarPopup; ctx: bar; floating: true }
    TempPopup     { id: tempPopup;     ctx: bar; floating: true }
    RamPopup      { id: ramPopup;      ctx: bar; floating: true }
    TrayMenu      { id: trayMenu;      ctx: bar; below: true }
    AudioDevices  { id: audioDevices;  ctx: bar; below: true }

    // ── Corpo da barra ──
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: Config.dracoRadius
        color: Qt.rgba(Config.dracoBg.r, Config.dracoBg.g, Config.dracoBg.b, Config.dracoBgOpacity)
        border.color: Config.dracoBorder
        border.width: 1

        // scroll no fundo (e nas cápsulas que não consomem a roda) → workspace deste monitor
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: (w) => bar.switchWorkspace(w.angleDelta.y > 0 ? -1 : 1)   // cima = anterior
        }

        // ══ Esquerda ══
        Row {
            id: leftRow
            anchors { left: parent.left; leftMargin: Config.dracoPad; verticalCenter: parent.verticalCenter }
            spacing: Config.dracoSpacing

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
                icon2: Config.iconCpu
                label2: SensorsService.cpuUsage
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

        // ══ Centro: título da janela ativa OU cápsulas de workspaces ══
        Item {
            id: center
            anchors.centerIn: parent
            height: Config.dracoCapsuleH
            width: bar.hasWin ? titleCap.width : wsRow.width
            // o título nunca invade as laterais: teto = o que sobra entre os dois blocos
            readonly property real titleMaxW: Math.max(120, Math.min(Config.dracoTitleMaxW,
                bar.width - 2 * Math.max(leftRow.width, rightRow.width) - 4 * Config.dracoPad))

            DracoCapsule {
                id: titleCap
                visible: bar.hasWin
                image: bar.appIcon
                label: bar.activeWin ? (bar.activeWin.title || bar.activeWin.appId || "") : ""
                labelMaxW: center.titleMaxW
                // apagado quando a janela ativa deste monitor não é a focada da sessão
                textColor: (bar.activeWin && bar.activeWin.focused) ? Config.dracoText : Config.dracoSub
                onClicked: if (bar.activeWin && bar.niri) bar.niri.focusWindow(bar.activeWin.id)
            }
            Row {
                id: wsRow
                visible: !bar.hasWin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Config.dracoSpacing
                Repeater {
                    model: bar.wsList
                    delegate: Rectangle {
                        id: pill
                        required property var modelData
                        readonly property bool isActive: modelData.is_active === true
                        readonly property bool ghost: modelData.ghost === true
                        readonly property bool busy: (modelData.client_count ?? 0) > 0
                        anchors.verticalCenter: parent.verticalCenter
                        height: Config.dracoCapsuleH - 6
                        // a ativa fica alongada (pílula), as outras quase redondas
                        width: Math.max(height, num.implicitWidth + 14) + (isActive ? 14 : 0)
                        radius: height / 2
                        color: isActive ? Config.dracoAccent
                             : pillMA.containsMouse ? Config.dracoCapsuleHover : Config.dracoCapsuleBg
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
        Row {
            id: rightRow
            anchors { right: parent.right; rightMargin: Config.dracoPad; verticalCenter: parent.verticalCenter }
            spacing: Config.dracoSpacing

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
            Rectangle {                                      // bandeja (system tray)
                id: trayCap
                visible: SystemTray.items.values.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: trayRow.implicitWidth + 2 * Config.dracoCapsulePad
                height: Config.dracoCapsuleH
                radius: height / 2
                color: Config.dracoCapsuleBg

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 8
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
                            Text {                           // fallback: inicial do app
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
}
