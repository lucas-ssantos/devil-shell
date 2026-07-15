import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/services"   // LauncherService
import "root:/themes"     // Theme
import "root:/"           // Config

// Janela do lançador próprio (substitui o rofi). Overlay no monitor focado, com um
// campo de busca e uma lista de resultados. O MODO é derivado do texto digitado:
//   (vazio/texto)  aplicativos instalados — vazio lista os MAIS USADOS primeiro
//   /dir           navegador de arquivos (dirs + imagens/vídeos) -> abre no VLC
//   /proc          processos (ordenável por nome/PID/RAM/CPU; Enter finaliza)
//   /reload        recarrega o Quickshell        /config  abre as configurações
//   =expressão     calculadora (=5+5 -> 10)
// Teclado: ↑/↓ navega, Enter ativa, Esc fecha, Tab ordena (/proc),
//          Backspace com filtro vazio sobe um diretório (/dir).
// A lógica não-visual (apps, uso, find, ps, kill, parser) vive no LauncherService.
PanelWindow {
    id: win
    property var niri   // NiriService, p/ achar o monitor focado

    // ── Animação de abrir/fechar ────────────────────────
    // `reveal` anima 0↔1 seguindo LauncherService.open; a janela só some de fato
    // quando o fade-out termina (senão o Wayland destruiria a surface na hora).
    property real reveal: LauncherService.open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Config.launcherAnim; easing.type: Easing.OutCubic } }
    visible: LauncherService.open || reveal > 0.001

    // monitor focado (fallback: o primeiro) — igual à SettingsWindow
    screen: {
        const list = niri ? (niri.monitors ?? []) : []
        const a = list.find(m => m.active)
        if (a) {
            const s = Quickshell.screens.find(sc => sc.name === a.name)
            if (s) return s
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    WlrLayershell.layer: WlrLayer.Overlay
    // solta o teclado assim que começa a fechar (não espera o fade-out)
    WlrLayershell.keyboardFocus: LauncherService.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0

    // ── Modo derivado do texto ──────────────────────────
    readonly property string query: input.text
    readonly property string mode: {
        const q = query
        if (q.length > 0 && q[0] === "=") return "calc"
        if (q === "/dir" || q.indexOf("/dir ") === 0) return "files"
        if (q === "/proc" || q.indexOf("/proc ") === 0) return "proc"
        if (q.length > 0 && q[0] === "/") return "cmds"
        return "apps"
    }
    // argumento após o prefixo do modo (filtro/expressão)
    readonly property string modeArg: {
        if (mode === "calc")  return query.substring(1)
        if (mode === "files") return query.length > 5 ? query.substring(5) : ""   // após "/dir "
        if (mode === "proc")  return query.length > 6 ? query.substring(6) : ""
        if (mode === "cmds")  return query.substring(1)
        return query
    }

    // ── Comandos "/" (paleta) ───────────────────────────
    readonly property var commands: [
        { cmd: "/dir",    glyph: "🖼", name: "Imagens e vídeos", desc: "navegar pelos arquivos e abrir no VLC", complete: true },
        { cmd: "/proc",   glyph: "⚡", name: "Processos",        desc: "listar e finalizar processos",          complete: true },
        { cmd: "/config", glyph: "⚙", name: "Configurações",    desc: "abrir as configurações do shell",       complete: false },
        { cmd: "/reload", glyph: "↻", name: "Recarregar",       desc: "recarregar o Quickshell",               complete: false }
    ]

    // ── Ordenação do /proc ──────────────────────────────
    property string procSort: "name"   // name | pid | ram | cpu
    readonly property var procSorts: [
        { key: "name", label: "Nome A–Z" },
        { key: "pid",  label: "PID" },
        { key: "ram",  label: "RAM" },
        { key: "cpu",  label: "CPU" }
    ]
    function cycleSort() {
        const order = ["name", "pid", "ram", "cpu"]
        procSort = order[(order.indexOf(procSort) + 1) % order.length]
    }

    // ── Resultados (kind: header|app|cmd|dir|file|proc|calc) ──
    readonly property var results: {
        if (mode === "apps")  return appResults(modeArg)
        if (mode === "cmds")  return cmdResults(modeArg)
        if (mode === "calc")  return calcResults(modeArg)
        if (mode === "files") return fileResults(modeArg)
        if (mode === "proc")  return procResults(modeArg)
        return []
    }

    function appItem(a) {
        return { kind: "app", name: a.name, sub: a.comment || a.genericName || "",
                 icon: Quickshell.iconPath(a.icon, true), entry: a }
    }
    // pontuação da busca de apps (prefixo > início de palavra > substring > metadados),
    // com um empurrão pelos mais usados
    function appScore(a, q) {
        const name = a.name.toLowerCase()
        let s = 0
        if (name === q) s = 200
        else if (name.indexOf(q) === 0) s = 120
        else if (name.split(/\s+/).some(w => w.indexOf(q) === 0)) s = 90
        else if (name.indexOf(q) >= 0) s = 60
        else {
            const hay = ((a.genericName || "") + " " + (a.comment || "") + " "
                       + (a.keywords || []).join(" ") + " " + a.id).toLowerCase()
            if (hay.indexOf(q) >= 0) s = 30
        }
        if (s > 0) s += Math.min(LauncherService.usageOf(a.id), 30) * 0.5
        return s
    }
    function appResults(q) {
        void LauncherService.usage                     // dependência: reavalia quando o uso muda
        const apps = LauncherService.apps
        const ql = q.trim().toLowerCase()
        if (ql === "") {
            const out = []
            const used = apps.filter(a => LauncherService.usageOf(a.id) > 0)
            used.sort((a, b) => LauncherService.usageOf(b.id) - LauncherService.usageOf(a.id)
                                || a.name.localeCompare(b.name))
            const top = used.slice(0, Config.launcherTopUsed)
            if (top.length > 0) {
                out.push({ kind: "header", name: "Mais usados" })
                for (let i = 0; i < top.length; i++) out.push(appItem(top[i]))
                out.push({ kind: "header", name: "Todos os aplicativos" })
            }
            for (let i = 0; i < apps.length; i++) out.push(appItem(apps[i]))
            return out
        }
        const scored = []
        for (let i = 0; i < apps.length; i++) {
            const s = appScore(apps[i], ql)
            if (s > 0) scored.push({ s: s, a: apps[i] })
        }
        scored.sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name))
        return scored.map(p => appItem(p.a))
    }
    function cmdResults(q) {
        const ql = q.trim().toLowerCase()
        return commands
            .filter(c => ql === "" || c.cmd.substring(1).indexOf(ql) === 0 || c.name.toLowerCase().indexOf(ql) >= 0)
            .map(c => ({ kind: "cmd", name: c.name, sub: c.cmd + " — " + c.desc,
                         glyph: c.glyph, cmd: c.cmd, complete: c.complete }))
    }
    function calcResults(expr) {
        if (expr.trim() === "")
            return [{ kind: "calc", ok: false, display: "Digite uma expressão…",
                      sub: "ex.: =5+5 · =sqrt(2)*3 · =2^10 · =sin(pi/2)" }]
        const r = LauncherService.calc(expr)
        if (r.ok) return [{ kind: "calc", ok: true, value: r.text,
                            display: expr.trim() + " = " + r.text, sub: "Enter continua a conta com o resultado" }]
        return [{ kind: "calc", ok: false, display: "Expressão inválida", sub: r.error }]
    }
    function fileResults(q) {
        const ql = q.trim().toLowerCase()
        const out = []
        if (LauncherService.cwd !== "/")
            out.push({ kind: "dir", name: "..", path: "", up: true })
        const fs = LauncherService.files
        for (let i = 0; i < fs.length; i++) {
            const f = fs[i]
            if (ql !== "" && f.name.toLowerCase().indexOf(ql) < 0) continue
            out.push({ kind: f.isDir ? "dir" : "file", name: f.name, path: f.path,
                       isVideo: f.isVideo, up: false })
        }
        return out
    }
    function procResults(q) {
        const ql = q.trim().toLowerCase()
        const sort = procSort
        const list = LauncherService.procs.filter(p => ql === "" || p.name.toLowerCase().indexOf(ql) >= 0
                                                      || ("" + p.pid).indexOf(ql) === 0)
        list.sort((a, b) => {
            if (sort === "cpu") return b.cpu - a.cpu || b.mem - a.mem
            if (sort === "ram") return b.mem - a.mem || b.cpu - a.cpu
            if (sort === "pid") return a.pid - b.pid
            return a.name.localeCompare(b.name, undefined, { sensitivity: "base" }) || a.pid - b.pid
        })
        return list.map(p => ({ kind: "proc", name: p.name, pid: p.pid, cpu: p.cpu, mem: p.mem }))
    }

    // ── Seleção (pula headers) ──────────────────────────
    property int selIndex: 0
    function selectableIndex(from, dir) {
        const n = results.length
        if (n === 0) return -1
        let i = ((from % n) + n) % n
        for (let k = 0; k < n; k++) {
            if (results[i].kind !== "header") return i
            i = ((i + dir) % n + n) % n
        }
        return -1
    }
    function moveSel(dir) {
        const i = selectableIndex(selIndex + dir, dir >= 0 ? 1 : -1)
        if (i < 0) return
        selIndex = i
        list.positionViewAtIndex(selIndex, ListView.Contain)
    }
    onResultsChanged: {
        selIndex = selectableIndex(0, 1)
        list.positionViewAtBeginning()
    }

    // ── Ativação (Enter/clique) ─────────────────────────
    function setQuery(t) { input.text = t; input.cursorPosition = t.length }
    function activate(it, mods) {
        if (!it || it.kind === "header") return
        if (it.kind === "app") {
            LauncherService.launchApp(it.entry)
        } else if (it.kind === "cmd") {
            if (it.complete) setQuery(it.cmd + " ")             // entra no modo
            else if (it.cmd === "/reload") LauncherService.reloadShell()
            else if (it.cmd === "/config") LauncherService.openConfig()
        } else if (it.kind === "dir") {
            if (it.up) LauncherService.dirUp()
            else LauncherService.listDir(it.path)
            setQuery("/dir ")                                   // limpa o filtro
        } else if (it.kind === "file") {
            LauncherService.openFile(it.path)
        } else if (it.kind === "proc") {
            LauncherService.killProc(it.pid, (mods & Qt.ShiftModifier) !== 0)
        } else if (it.kind === "calc") {
            if (it.ok) setQuery("=" + it.value)                 // encadeia a conta
        }
    }

    // hover só muda a seleção quando o MOUSE se move de verdade (rolar a lista sob o
    // cursor parado dispara hover sintético e brigaria com a navegação por teclado)
    property real lastMx: -1
    property real lastMy: -1
    function hoverSelect(item, mx, my, index) {
        const p = item.mapToItem(panel, mx, my)
        if (p.x === lastMx && p.y === lastMy) return
        lastMx = p.x; lastMy = p.y
        selIndex = index
    }

    // reset ao abrir: busca limpa, navegador de volta ao $HOME, foco no campo.
    // Observa `open` (não `visible`): durante o fade-out a janela segue visível,
    // e reabrir nesse meio-tempo também precisa resetar.
    readonly property bool isOpen: LauncherService.open
    onIsOpenChanged: {
        if (!isOpen) return
        input.text = ""
        LauncherService.cwd = ""
        LauncherService.files = []
        input.forceActiveFocus()
    }
    // entrar no modo /dir pela 1ª vez carrega o $HOME; /proc liga o refresh (Timer)
    onModeChanged: {
        if (mode === "files" && LauncherService.cwd === "")
            LauncherService.listDir(LauncherService.home)
    }
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: LauncherService.open && win.mode === "proc"   // não segue tique durante o fade-out
        onTriggered: LauncherService.refreshProcs()
    }

    function fileUrl(p) {
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F")
    }
    readonly property string cwdPretty: {
        const h = LauncherService.home
        const c = LauncherService.cwd
        return c.indexOf(h) === 0 ? "~" + c.substring(h.length) : c
    }
    readonly property int resultCount: {
        let n = 0
        for (let i = 0; i < results.length; i++)
            if (results[i].kind !== "header") n++
        return n
    }
    readonly property string hintText: {
        if (mode === "apps")  return "↑↓ navegar · Enter abrir · “/” comandos · “=” calculadora"
        if (mode === "cmds")  return "Enter escolhe o comando"
        if (mode === "files") return "Enter abre no VLC / entra na pasta · Backspace sobe · digite p/ filtrar"
        if (mode === "proc")  return "Enter finaliza (TERM) · Shift+Enter mata (KILL) · Tab muda a ordem"
        if (mode === "calc")  return "Enter usa o resultado na próxima conta"
        return ""
    }

    // fundo escurecido (clicar fora fecha) — esmaece junto com o reveal
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.45 * win.reveal
        MouseArea { anchors.fill: parent; onClicked: LauncherService.hide() }
    }

    // ── Painel central ──────────────────────────────────
    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        // entra descendo de leve (+fade+zoom); sai pelo caminho inverso
        y: Math.max(24, parent.height * Config.launcherYFactor) - 14 * (1 - win.reveal)
        opacity: win.reveal
        scale: 0.96 + 0.04 * win.reveal
        transformOrigin: Item.Top
        width: Math.min(parent.width - 80, Config.launcherW)
        height: col.height + 24
        radius: Config.launcherRadius
        color: Config.launcherBg
        border.color: Config.launcherBorder
        border.width: 1

        // engole cliques (não fecha ao clicar dentro) e devolve o foco ao campo
        MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

        Column {
            id: col
            x: 12; y: 12
            width: panel.width - 24
            spacing: 8

            // ── Campo de busca ──
            Item {
                width: col.width
                height: 40

                Text {   // símbolo do modo
                    id: prompt
                    anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    text: win.mode === "calc" ? "=" : "❯"
                    color: Config.accent
                    font.pixelSize: Config.launcherInputSize
                    font.bold: true
                }
                TextInput {
                    id: input
                    anchors { left: prompt.right; leftMargin: 10; right: badge.left; rightMargin: 8
                              verticalCenter: parent.verticalCenter }
                    color: Config.launcherText
                    font.pixelSize: Config.launcherInputSize
                    selectByMouse: true
                    clip: true
                    focus: true
                    // teclado do lançador (setas/Enter/Esc/Tab/Backspace especial)
                    Keys.onPressed: (ev) => {
                        if (ev.key === Qt.Key_Down) { win.moveSel(1); ev.accepted = true }
                        else if (ev.key === Qt.Key_Up) { win.moveSel(-1); ev.accepted = true }
                        else if (ev.key === Qt.Key_PageDown) { win.moveSel(8); ev.accepted = true }
                        else if (ev.key === Qt.Key_PageUp) { win.moveSel(-8); ev.accepted = true }
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                            win.activate(win.results[win.selIndex], ev.modifiers)
                            ev.accepted = true
                        } else if (ev.key === Qt.Key_Escape) {
                            LauncherService.hide()
                            ev.accepted = true
                        } else if (ev.key === Qt.Key_Tab) {
                            if (win.mode === "proc") win.cycleSort()
                            ev.accepted = true
                        } else if (ev.key === Qt.Key_Backspace && win.mode === "files" && win.modeArg === ""
                                   && LauncherService.cwd !== "/" && LauncherService.cwd !== LauncherService.home) {
                            LauncherService.dirUp()   // no $HOME/raiz o Backspace volta a apagar o texto
                            ev.accepted = true
                        }
                    }
                }
                Text {   // placeholder
                    anchors.fill: input
                    visible: input.text === ""
                    verticalAlignment: Text.AlignVCenter
                    text: "Buscar aplicativos…   ( “/” comandos · “=” calculadora )"
                    color: Config.launcherSub
                    font.pixelSize: Config.launcherInputSize
                    elide: Text.ElideRight
                }
                Text {   // selo do modo atual
                    id: badge
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    visible: win.mode !== "apps"
                    text: win.mode === "apps" ? ""              // some E libera a largura p/ o campo
                        : win.mode === "files" ? "ARQUIVOS"
                        : win.mode === "proc" ? "PROCESSOS"
                        : win.mode === "calc" ? "CALC"
                        : "COMANDOS"
                    color: Config.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                }
            }

            // ── /dir: caminho atual ──
            Text {
                visible: win.mode === "files"
                width: col.width
                text: win.cwdPretty
                color: Config.launcherSub
                font.pixelSize: Config.launcherFontSize - 1
                elide: Text.ElideLeft
                leftPadding: 6
            }

            // ── /proc: chips de ordenação ──
            Row {
                visible: win.mode === "proc"
                spacing: 6
                leftPadding: 6
                Repeater {
                    model: win.procSorts
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: win.procSort === modelData.key
                        width: chipTxt.implicitWidth + 20
                        height: 24
                        radius: 12
                        color: sel ? Config.accent : Theme.surface0
                        border.color: sel ? Config.accent : Theme.surface2
                        border.width: 1
                        Text {
                            id: chipTxt
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: parent.sel ? Theme.crust : Config.launcherSub
                            font.pixelSize: 11
                            font.bold: parent.sel
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { win.procSort = parent.modelData.key; input.forceActiveFocus() }
                        }
                    }
                }
            }

            Rectangle { width: col.width; height: 1; color: Config.launcherBorder }

            // ── Lista de resultados ──
            ListView {
                id: list
                width: col.width
                // altura acompanha o conteúdo até o teto; vazio mantém espaço p/ o aviso
                height: Math.min(Math.max(contentHeight, win.resultCount === 0 ? 64 : 0), Config.launcherListMaxH)
                clip: true
                model: win.results
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isHeader: modelData.kind === "header"
                    readonly property bool selected: index === win.selIndex
                    width: list.width
                    height: isHeader ? 26 : Config.launcherRowH

                    // cabeçalho de seção ("Mais usados" / "Todos os aplicativos")
                    Text {
                        visible: row.isHeader
                        anchors { left: parent.left; leftMargin: 6; bottom: parent.bottom; bottomMargin: 3 }
                        text: row.modelData.name ?? ""
                        color: Config.accent
                        font.pixelSize: 11
                        font.bold: true
                    }

                    // linha normal
                    Rectangle {
                        visible: !row.isHeader
                        anchors.fill: parent
                        radius: 8
                        color: row.selected ? Config.launcherSel : "transparent"

                        Item {   // ícone / miniatura / glifo
                            id: iconBox
                            width: Config.launcherIconSize + 8
                            height: parent.height
                            anchors { left: parent.left; leftMargin: 6 }
                            visible: row.modelData.kind !== "proc" && row.modelData.kind !== "calc"

                            Image {   // ícone de app ou miniatura de imagem
                                anchors.centerIn: parent
                                visible: ("" + source) !== ""
                                source: row.modelData.kind === "app" ? (row.modelData.icon ?? "")
                                      : (row.modelData.kind === "file" && !row.modelData.isVideo)
                                        ? win.fileUrl(row.modelData.path) : ""
                                sourceSize: Qt.size(Config.launcherIconSize * 2, Config.launcherIconSize * 2)
                                width: Config.launcherIconSize
                                height: Config.launcherIconSize
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                            Rectangle {   // fallback de app sem ícone: inicial num círculo
                                visible: row.modelData.kind === "app" && (row.modelData.icon ?? "") === ""
                                anchors.centerIn: parent
                                width: Config.launcherIconSize; height: Config.launcherIconSize
                                radius: width / 2
                                color: Theme.surface1
                                Text {
                                    anchors.centerIn: parent
                                    text: (row.modelData.name ?? "?").charAt(0).toUpperCase()
                                    color: Config.launcherText
                                    font.pixelSize: Config.launcherIconSize * 0.55
                                    font.bold: true
                                }
                            }
                            Text {   // glifo (comandos, pastas, vídeos)
                                visible: row.modelData.kind === "cmd" || row.modelData.kind === "dir"
                                      || (row.modelData.kind === "file" && row.modelData.isVideo)
                                anchors.centerIn: parent
                                text: row.modelData.kind === "cmd" ? (row.modelData.glyph ?? "❯")
                                    : row.modelData.kind === "dir" ? (row.modelData.up ? "↩" : "📁")
                                    : "🎬"
                                font.pixelSize: Config.launcherIconSize * 0.8
                            }
                        }

                        // texto principal + secundário (apps/comandos/arquivos)
                        Column {
                            visible: row.modelData.kind !== "proc" && row.modelData.kind !== "calc"
                            anchors { left: iconBox.right; leftMargin: 8; right: parent.right; rightMargin: 10
                                      verticalCenter: parent.verticalCenter }
                            spacing: 1
                            Text {
                                width: parent.width
                                text: row.modelData.name ?? ""
                                color: Config.launcherText
                                font.pixelSize: Config.launcherFontSize
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                visible: (row.modelData.sub ?? "") !== ""
                                text: row.modelData.sub ?? ""
                                color: Config.launcherSub
                                font.pixelSize: Config.launcherFontSize - 2
                                elide: Text.ElideRight
                            }
                        }

                        // linha de processo: nome + colunas PID/CPU/RAM
                        Item {
                            visible: row.modelData.kind === "proc"
                            anchors.fill: parent
                            anchors { leftMargin: 12; rightMargin: 10 }
                            Text {
                                anchors { left: parent.left; right: procCols.left; rightMargin: 8
                                          verticalCenter: parent.verticalCenter }
                                text: row.modelData.name ?? ""
                                color: Config.launcherText
                                font.pixelSize: Config.launcherFontSize
                                elide: Text.ElideRight
                            }
                            Row {
                                id: procCols
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 0
                                Text {
                                    width: 64; horizontalAlignment: Text.AlignRight
                                    text: "" + (row.modelData.pid ?? "")
                                    color: Config.launcherSub
                                    font.pixelSize: Config.launcherFontSize - 1
                                    font.family: "monospace"
                                }
                                Text {
                                    width: 74; horizontalAlignment: Text.AlignRight
                                    text: (row.modelData.cpu ?? 0).toFixed(1) + "%"
                                    color: win.procSort === "cpu" ? Config.accent : Config.launcherSub
                                    font.pixelSize: Config.launcherFontSize - 1
                                    font.family: "monospace"
                                }
                                Text {
                                    width: 88; horizontalAlignment: Text.AlignRight
                                    text: (row.modelData.mem ?? 0) + " MB"
                                    color: win.procSort === "ram" ? Config.accent : Config.launcherSub
                                    font.pixelSize: Config.launcherFontSize - 1
                                    font.family: "monospace"
                                }
                            }
                        }

                        // linha da calculadora: expressão = resultado
                        Text {
                            visible: row.modelData.kind === "calc"
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12
                                      verticalCenter: parent.verticalCenter }
                            text: row.modelData.display ?? ""
                            color: row.modelData.ok ? Config.launcherText : Config.launcherSub
                            font.pixelSize: Config.launcherFontSize + 3
                            font.bold: row.modelData.ok === true
                            elide: Text.ElideLeft
                        }

                        MouseArea {
                            id: rowMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: (mouse) => win.hoverSelect(rowMA, mouse.x, mouse.y, row.index)
                            onClicked: (mouse) => win.activate(row.modelData, mouse.modifiers)
                        }
                    }
                }

                // barra de rolagem fina (mesmo estilo da SettingsWindow)
                Rectangle {
                    visible: list.contentHeight > list.height
                    anchors { right: parent.right; rightMargin: 1 }
                    width: 4; radius: 2
                    color: Theme.surface2
                    height: list.contentHeight > 0 ? list.height * (list.height / list.contentHeight) : 0
                    y: (list.contentHeight > list.height)
                       ? (list.contentY / (list.contentHeight - list.height)) * (list.height - height)
                       : 0
                }

                // vazio: nada encontrado
                Text {
                    visible: win.resultCount === 0
                    anchors.centerIn: parent
                    text: win.mode === "files" ? "Nenhuma pasta ou mídia aqui" : "Nada encontrado"
                    color: Config.launcherSub
                    font.pixelSize: Config.launcherFontSize
                }
            }

            // ── Rodapé: dicas + contagem ──
            Item {
                width: col.width
                height: 18
                Text {
                    anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    width: parent.width - countTxt.width - 24
                    text: win.hintText
                    color: Config.launcherSub
                    font.pixelSize: Config.launcherFontSize - 3
                    elide: Text.ElideRight
                }
                Text {
                    id: countTxt
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    visible: win.mode !== "calc"
                    text: win.resultCount + (win.resultCount === 1 ? " item" : " itens")
                    color: Config.launcherSub
                    font.pixelSize: Config.launcherFontSize - 3
                }
            }
        }
    }
}
