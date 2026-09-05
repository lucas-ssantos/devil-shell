import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/services"   // LauncherService
import "root:/themes"     // Theme
import "root:/"           // Config

// Janela do lançador próprio. Overlay no monitor focado, com um
// campo de busca e uma lista de resultados. O MODO é derivado do texto digitado:
//   (vazio/texto)  aplicativos instalados — vazio lista os MAIS USADOS primeiro
//   /dir           navegador de arquivos (dirs + imagens/vídeos) -> abre no VLC
//   /proc          processos AGRUPADOS por app (soma real de RAM/CPU da subárvore;
//                  →/Enter expande p/ ver os filhos; Shift+Enter finaliza)
//   /notes         notas de texto (um .txt por nota; nome = 1ª linha). "Criar nota"
//                  ou abrir uma nota entra num EDITOR embutido (números de linha,
//                  Salvar/Voltar). Voltar sem salvar guarda um RASCUNHO; reabrir a
//                  nota mostra a tela de revisão (manter rascunho / descartar).
//                  Texto após "/notes " vira o título da nova nota; Delete apaga a nota.
//   /color-picker  captura a cor de um pixel da tela (grim+slurp+imagemagick) + histórico
//                  (Enter copia o HEX, Shift+Enter o RGB, Delete remove o item selecionado)
//   /bg            escolhedor de wallpaper (awww; Tab muda o alvo: todos/por monitor)
//   /theme         escolhedor de paleta do shell (ex.: "/theme CrimsonDevil" já filtra/aplica)
//   /reload        recarrega o Quickshell        /config  abre as configurações
//   /lock          bloqueia a tela (gtklock)
//   /reboot        reinicia o computador          /poweroff  desliga o computador
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

    // monitor focado NO MOMENTO DE ABRIR (fallback: o primeiro), travado numa
    // property — igual à SettingsWindow: um binding vivo em `niri.monitors` faria
    // a janela seguir o mouse p/ o outro monitor. O latch acontece no
    // onIsOpenChanged (junto com o reset da busca), antes do fade-in terminar.
    property var openScreen: null
    screen: openScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

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
        if (q === "/notes" || q.indexOf("/notes ") === 0) return "notes"
        if (q === "/color-picker" || q.indexOf("/color-picker ") === 0) return "color"
        if (q === "/bg" || q.indexOf("/bg ") === 0) return "bg"
        if (q === "/theme" || q.indexOf("/theme ") === 0) return "theme"
        if (q.length > 0 && q[0] === "/") return "cmds"
        return "apps"
    }
    // argumento após o prefixo do modo (filtro/expressão)
    readonly property string modeArg: {
        if (mode === "calc")  return query.substring(1)
        if (mode === "files") return query.length > 5 ? query.substring(5) : ""   // após "/dir "
        if (mode === "proc")  return query.length > 6 ? query.substring(6) : ""
        if (mode === "notes") return query.length > 7 ? query.substring(7) : ""   // após "/notes "
        if (mode === "color") return query.length > 14 ? query.substring(14) : ""   // após "/color-picker "
        if (mode === "bg")    return query.length > 4 ? query.substring(4) : ""   // após "/bg "
        if (mode === "theme") return query.length > 7 ? query.substring(7) : ""   // após "/theme "
        if (mode === "cmds")  return query.substring(1)
        return query
    }

    // ── /notes: editor / revisão de rascunho embutidos ──
    // Quando um destes está ativo, o campo de busca + a lista somem e o painel
    // mostra o editor (ou a tela de revisão) no lugar.
    readonly property bool notesEdit: LauncherService.editorOpen
    readonly property bool notesReview: LauncherService.sketchReviewPath !== ""
    readonly property bool notesFull: mode === "notes" && (notesEdit || notesReview)

    // ── Comandos "/" (paleta) ───────────────────────────
    readonly property var commands: [
        { cmd: "/dir",    glyph: "🖼", name: "Imagens e vídeos", desc: "navegar pelos arquivos e abrir no VLC", complete: true },
        { cmd: "/proc",   glyph: "⚡", name: "Processos",        desc: "listar e finalizar processos",          complete: true },
        { cmd: "/notes",  glyph: "📝", name: "Notas",            desc: "criar e abrir notas de texto",          complete: true },
        { cmd: "/color-picker", glyph: "💧", name: "Seletor de cor", desc: "capturar um pixel da tela e ver o histórico", complete: true },
        { cmd: "/bg",     glyph: "🌄", name: "Papel de parede",  desc: "escolher o wallpaper (todos ou por monitor)", complete: true },
        { cmd: "/theme",  glyph: "🎨", name: "Tema",             desc: "trocar a paleta do shell", complete: true },
        { cmd: "/config", glyph: "⚙", name: "Configurações",    desc: "abrir as configurações do shell",       complete: false },
        { cmd: "/reload", glyph: "↻", name: "Recarregar",       desc: "recarregar o Quickshell",               complete: false },
        { cmd: "/lock",   glyph: "🔒", name: "Bloquear tela",   desc: "bloquear a tela com o gtklock",         complete: false },
        { cmd: "/reboot",   glyph: "⟳", name: "Reiniciar", desc: "reiniciar o computador",  complete: false },
        { cmd: "/poweroff", glyph: "⏻", name: "Desligar",   desc: "desligar o computador",   complete: false }
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

    // ── Grupos do /proc: quais subárvores estão expandidas (chave = pid raiz) ──
    // Reatribui o mapa inteiro a cada toggle p/ o binding de `results` reavaliar.
    property var procExpanded: ({})
    function toggleGroup(pid) {
        const m = Object.assign({}, procExpanded)
        if (m[pid]) delete m[pid]; else m[pid] = true
        procExpanded = m
    }
    // processos "recipiente" (sessão/shell/dbus): NÃO viram grupo — cada filho deles
    // é a raiz do seu próprio app (senão tudo cairia num "systemd"/"niri" gigante).
    // comm vem truncado em 15 chars pelo ps (ex.: "dbus-broker-launch" -> "dbus-broker-lau").
    // inclui os wrappers de sandbox (bwrap/flatpak/firejail/snap): sem isso todo app
    // Flatpak apareceria agrupado como "bwrap" em vez do nome real.
    readonly property var procContainers: ["systemd", "(sd-pam)", "init", "niri",
        "dbus-daemon", "dbus-broker", "dbus-broker-lau", "login", "agetty", "sshd",
        "su", "sudo", "doas", "bash", "zsh", "fish", "sh", "dash",
        "quickshell", ".quickshell-wr",
        "bwrap", "flatpak", "firejail", "snap-confine", "snap"]

    // total de CPU em uso por TODOS os processos (independe do filtro de busca; soma
    // crua do %cpu do ps — fmtCpu divide pelos núcleos antes de exibir);
    // RAM vem pronta de LauncherService.memUsedMB (soma de RSS por processo conta
    // memória compartilhada várias vezes e passa do total físico da máquina)
    readonly property real procTotalCpu: {
        const list = LauncherService.procs
        let s = 0
        for (let i = 0; i < list.length; i++) s += list[i].cpu
        return s
    }
    function fmtMem(mb) {
        return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"
    }
    // %cpu cru (pode ser >100% p/ subárvores multi-thread) -> fatia real da máquina
    function fmtCpu(raw) {
        return (raw / Math.max(1, LauncherService.cpuCount)).toFixed(1) + "%"
    }

    // ── Alvo do /bg (todos os monitores ou um específico) ──
    property string bgTarget: "*"
    readonly property var bgTargets: {
        const mons = niri ? (niri.monitors ?? []) : []
        const out = [{ key: "*", label: mons.length === 2 ? "Ambos" : "Todos" }]
        for (let i = 0; i < mons.length; i++)
            out.push({ key: mons[i].name, label: mons[i].name })
        return out
    }
    function cycleBgTarget() {
        const ts = bgTargets
        const i = ts.findIndex(t => t.key === bgTarget)
        bgTarget = ts[(i + 1) % ts.length].key
    }

    // ── Resultados (kind: header|app|cmd|dir|file|proc|calc) ──
    readonly property var results: {
        if (mode === "apps")  return appResults(modeArg)
        if (mode === "cmds")  return cmdResults(modeArg)
        if (mode === "calc")  return calcResults(modeArg)
        if (mode === "files") return fileResults(modeArg)
        if (mode === "proc")  return procResults(modeArg)
        if (mode === "notes") return noteResults(modeArg)
        if (mode === "color") return colorResults(modeArg)
        if (mode === "bg")    return bgResults(modeArg)
        if (mode === "theme") return themeResults(modeArg)
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
                       fileType: f.fileType, up: false })
        }
        return out
    }
    function bgResults(q) {
        void Settings.data                              // dependência: "atual" muda com a seleção
        const ql = q.trim().toLowerCase()
        const cur = WallpaperService.currentFor(bgTarget)
        const out = []
        const list = WallpaperService.wallpapers
        for (let i = 0; i < list.length; i++) {
            const w = list[i]
            if (ql !== "" && w.name.toLowerCase().indexOf(ql) < 0) continue
            out.push({ kind: "bg", name: w.name, path: w.path, sub: w.path === cur ? "atual" : "" })
        }
        return out
    }
    function themeResults(q) {
        void Settings.data                              // dependência: "atual" muda com a seleção
        const ql = q.trim().toLowerCase()
        const cur = Theme.shellName
        const out = []
        const names = Theme.paletteNames
        for (let i = 0; i < names.length; i++) {
            const n = names[i]
            if (ql !== "" && n.toLowerCase().indexOf(ql) < 0) continue
            out.push({ kind: "theme", name: n, sub: n === cur ? "atual" : "" })
        }
        return out
    }
    function noteResults(q) {
        void LauncherService.notes                      // dependência: reavalia quando a lista muda
        const t = q.trim()
        const ql = t.toLowerCase()
        const out = [{ kind: "noteNew",
                       name: t === "" ? "Criar nota" : "Criar nota “" + t + "”",
                       sub: t === "" ? "abre o editor com uma nota nova" : "primeira linha: " + t }]
        const ns = LauncherService.notes.filter(n => ql === "" || n.name.toLowerCase().indexOf(ql) >= 0)
        if (ns.length > 0) out.push({ kind: "header", name: "Notas" })
        for (let i = 0; i < ns.length; i++) {
            const n = ns[i]
            out.push({ kind: "note", name: (n.hasSketch ? "● " : "") + n.name, path: n.path,
                       saved: n.saved, hasSketch: n.hasSketch,
                       sub: n.hasSketch ? (n.saved ? "rascunho não salvo desde a última edição"
                                                   : "rascunho não salvo — nunca foi salva")
                                        : "" })
        }
        return out
    }
    function colorResults(q) {
        void LauncherService.colorHistory               // dependência: reavalia quando o histórico muda
        const ql = q.trim().toLowerCase()
        const out = [{ kind: "colorpick", name: "Capturar cor da tela",
                       sub: "clique num pixel da tela pra pegar a cor" }]
        const hist = LauncherService.colorHistory.filter(c =>
            ql === "" || c.hex.toLowerCase().indexOf(ql) >= 0 || c.rgb.toLowerCase().indexOf(ql) >= 0)
        if (hist.length > 0) out.push({ kind: "header", name: "Histórico" })
        for (let i = 0; i < hist.length; i++)
            out.push({ kind: "color", name: hist[i].hex, sub: hist[i].rgb, hex: hist[i].hex, rgb: hist[i].rgb })
        return out
    }
    // ordena processos/grupos pelo critério atual (RAM/CPU = maior primeiro; nome/PID = crescente)
    function procCmp(a, b) {
        const sort = procSort
        if (sort === "cpu") return b.cpu - a.cpu || b.mem - a.mem
        if (sort === "ram") return b.mem - a.mem || b.cpu - a.cpu
        if (sort === "pid") return a.pid - b.pid
        return a.name.localeCompare(b.name, undefined, { sensitivity: "base" }) || a.pid - b.pid
    }
    // Monta a árvore de processos e agrupa cada app numa linha só (soma de RAM/CPU
    // de TODA a subárvore). Grupos com >1 processo são expansíveis (→ mostra os
    // filhos indentados). O filtro por nome/PID casa contra o grupo OU qualquer
    // filho; um filho casado força o grupo a abrir naquele render.
    function procResults(q) {
        void procExpanded                                    // dependência do binding
        const ql = q.trim().toLowerCase()
        const raw = LauncherService.procs
        const byPid = {}
        for (let i = 0; i < raw.length; i++) byPid[raw[i].pid] = raw[i]

        // raiz = quem não tem pai na lista OU cujo pai é um "recipiente"
        const isRoot = {}
        for (let i = 0; i < raw.length; i++) {
            const p = raw[i]
            const par = byPid[p.ppid]
            isRoot[p.pid] = !par || procContainers.indexOf(par.name) >= 0
        }
        // sobe até a raiz do app (guarda contra ciclos)
        function rootOf(p) {
            let cur = p
            for (let hop = 0; hop < 64; hop++) {
                if (isRoot[cur.pid]) return cur
                const par = byPid[cur.ppid]
                if (!par) return cur
                cur = par
            }
            return cur
        }
        // agrega a subárvore de cada raiz
        const groups = {}
        for (let i = 0; i < raw.length; i++) {
            const p = raw[i]
            const r = rootOf(p)
            let g = groups[r.pid]
            if (!g) g = groups[r.pid] = { pid: r.pid, name: r.name, cpu: 0, mem: 0, members: [] }
            g.cpu += p.cpu
            g.mem += p.mem
            g.members.push(p)
        }

        const out = []
        const list = []
        for (const k in groups) list.push(groups[k])
        list.sort(procCmp)
        for (let i = 0; i < list.length; i++) {
            const g = list[i]
            const multi = g.members.length > 1
            // filtro: casa o grupo, o pid raiz, ou algum membro
            let hitRoot = ql === "" || g.name.toLowerCase().indexOf(ql) >= 0 || ("" + g.pid).indexOf(ql) === 0
            const hitMembers = ql !== "" && g.members.some(m => m.name.toLowerCase().indexOf(ql) >= 0
                                                              || ("" + m.pid).indexOf(ql) === 0)
            if (!hitRoot && !hitMembers) continue

            const expanded = multi && (procExpanded[g.pid] === true || hitMembers)
            out.push({ kind: "proc", isGroup: true, expandable: multi, expanded: expanded,
                       name: g.name, pid: g.pid, cpu: g.cpu, mem: g.mem, count: g.members.length,
                       pids: g.members.map(m => m.pid) })
            if (expanded) {
                const kids = g.members.slice().sort(procCmp)
                for (let j = 0; j < kids.length; j++)
                    out.push({ kind: "proc", isChild: true, name: kids[j].name, pid: kids[j].pid,
                               cpu: kids[j].cpu, mem: kids[j].mem })
            }
        }
        return out
    }

    // ── Grade do /bg (colunas dependem da largura atual do painel) ──
    readonly property int bgCols: {
        if (mode !== "bg") return 1
        const cw = Config.launcherBgThumbW + Config.launcherBgCellGap
        return Math.max(1, Math.floor(col.width / cw))
    }

    // ── Seleção (pula headers) ──────────────────────────
    property int selIndex: 0
    // pid do item selecionado em /proc — o Timer de 2s reordena/relê a lista sozinho;
    // sem isso, cada tique jogava a seleção de volta pro topo (via onResultsChanged)
    // no meio de um kill ou de uma olhada na lista.
    property int selProcPid: -1
    onSelIndexChanged: {
        if (mode === "proc" && results[selIndex] && results[selIndex].kind === "proc")
            selProcPid = results[selIndex].pid
    }
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
        if (mode === "bg") bgGrid.positionViewAtIndex(selIndex, GridView.Contain)
        else list.positionViewAtIndex(selIndex, ListView.Contain)
    }
    onResultsChanged: {
        // /proc: acha o mesmo pid na lista relida; só cai pro topo se o processo já morreu
        if (mode === "proc" && selProcPid !== -1) {
            const i = results.findIndex(r => r.kind === "proc" && r.pid === selProcPid)
            if (i >= 0) {
                selIndex = i
                list.positionViewAtIndex(i, ListView.Contain)
                return
            }
        }
        selIndex = selectableIndex(0, 1)
        if (mode === "bg") bgGrid.positionViewAtBeginning()
        else list.positionViewAtBeginning()
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
            else if (it.cmd === "/lock") LauncherService.lock()
            else if (it.cmd === "/reboot") LauncherService.reboot()
            else if (it.cmd === "/poweroff") LauncherService.poweroff()
        } else if (it.kind === "dir") {
            if (it.up) LauncherService.dirUp()
            else LauncherService.listDir(it.path)
            setQuery("/dir ")                                   // limpa o filtro
        } else if (it.kind === "file") {
            LauncherService.openFile(it.path)
        } else if (it.kind === "proc") {
            const hard = (mods & Qt.ShiftModifier) !== 0
            if (it.isGroup && it.expandable) {
                // grupo de app: Enter abre/fecha; Shift+Enter finaliza a subárvore toda
                if (hard) LauncherService.killTree(it.pids, false)
                else win.toggleGroup(it.pid)
            } else {
                LauncherService.killProc(it.pid, hard)
            }
        } else if (it.kind === "noteNew") {
            LauncherService.newNote(win.modeArg)
        } else if (it.kind === "note") {
            if ((mods & Qt.ShiftModifier) !== 0) LauncherService.deleteNote(it.path)
            else if (it.hasSketch) LauncherService.reviewSketch(it.path)
            else LauncherService.editNote(it.path)
        } else if (it.kind === "colorpick") {
            LauncherService.pickColor(win.query)
        } else if (it.kind === "color") {
            LauncherService.copyColor((mods & Qt.ShiftModifier) ? it.rgb : it.hex)
            LauncherService.hide()
        } else if (it.kind === "bg") {
            WallpaperService.setFor(bgTarget, it.path)
            if ((mods & Qt.ShiftModifier) === 0) LauncherService.hide()   // Shift: segue aberto p/ o outro monitor
        } else if (it.kind === "theme") {
            Settings.set("themeShell", it.name)
            LauncherService.hide()
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
        if (!isOpen) {
            // fechou com o editor aberto → guarda um rascunho (não perde o texto);
            // na tela de revisão, só cancela
            if (LauncherService.editorOpen) LauncherService.leaveEditor(noteEditor.text)
            else if (LauncherService.sketchReviewPath !== "") LauncherService.cancelReview()
            return
        }
        // trava o monitor focado agora; não muda mais enquanto aberto
        const mons = niri ? (niri.monitors ?? []) : []
        const act = mons.find(m => m.active)
        const scr = act ? Quickshell.screens.find(sc => sc.name === act.name) : undefined
        openScreen = scr ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
        // /color-picker esconde a janela pra capturar e reabre sozinha (LauncherService.show());
        // colorReopenQuery guarda a query de então pra voltar direto pro modo, com o histórico
        // já atualizado, em vez de cair de volta nos aplicativos
        if (LauncherService.colorReopenQuery !== "") {
            input.text = LauncherService.colorReopenQuery
            LauncherService.colorReopenQuery = ""
        } else {
            input.text = ""
        }
        input.cursorPosition = input.text.length
        LauncherService.cwd = ""
        LauncherService.files = []
        bgTarget = "*"
        procExpanded = ({})
        input.forceActiveFocus()
    }
    // entrar no modo /dir pela 1ª vez carrega o $HOME; /proc liga o refresh (Timer);
    // /bg relê a pasta de wallpapers (pode ter ganhado imagens novas)
    onModeChanged: {
        if (mode === "files" && LauncherService.cwd === "")
            LauncherService.listDir(LauncherService.home)
        if (mode === "bg")
            WallpaperService.refresh()
        if (mode === "notes")
            LauncherService.refreshNotes()
    }
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: LauncherService.open && win.mode === "proc"   // não segue tique durante o fade-out
        onTriggered: LauncherService.refreshProcs()
    }
    // ao sair do editor / da revisão de notas, limpa o filtro e devolve o foco ao campo
    // (callLater: espera o campo de busca voltar a ser visível antes do forceActiveFocus)
    Connections {
        target: LauncherService
        function onEditorOpenChanged() {
            if (!LauncherService.editorOpen && win.mode === "notes" && !win.notesReview) {
                win.setQuery("/notes ")
                Qt.callLater(() => input.forceActiveFocus())
            }
        }
        function onSketchReviewPathChanged() {
            if (LauncherService.sketchReviewPath === "" && !LauncherService.editorOpen
                    && win.mode === "notes")
                Qt.callLater(() => input.forceActiveFocus())
        }
    }

    function fileUrl(p) {
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F")
    }
    readonly property string cwdPretty: {
        const h = LauncherService.home
        const c = LauncherService.cwd
        return c.indexOf(h) === 0 ? "~" + c.substring(h.length) : c
    }
    readonly property string bgDirPretty: {
        const h = LauncherService.home
        const d = Config.wallpaperDir
        return d.indexOf(h) === 0 ? "~" + d.substring(h.length) : d
    }
    readonly property string bgTargetLabel: {
        const t = bgTargets.find(t => t.key === bgTarget)
        return t ? t.label : bgTarget
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
        if (mode === "proc")  return "→/← ou Enter abre o app · Shift+Enter finaliza · nos filhos: Enter TERM, Shift+Enter KILL · Tab muda a ordem"
        if (mode === "notes") return "Enter abre no editor · Shift+Enter ou Delete apaga · digite p/ filtrar ou dar título à nova nota"
        if (mode === "color") return "Enter captura/copia o HEX · Shift+Enter copia o RGB · Delete remove do histórico"
        if (mode === "bg")    return "↑↓←→ navegar · Enter aplica em “" + bgTargetLabel + "” · Shift+Enter sem fechar · Tab muda o alvo"
        if (mode === "theme") return "↑↓ navegar · Enter aplica o tema · digite p/ filtrar"
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
        width: Math.min(parent.width - 80, win.mode === "bg" ? Config.launcherBgW
                                        : win.notesFull ? Config.launcherNotesW : Config.launcherW)
        Behavior on width {
            enabled: win.reveal === 1
            NumberAnimation { duration: Config.launcherResizeAnim; easing.type: Easing.OutCubic }
        }
        height: col.height + 24
        radius: Config.windowRadius(Config.launcherRadius)   // no draco, casa com o raio da barra
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

            // ── Campo de busca ── (some no editor/revisão de notas)
            Item {
                visible: !win.notesFull
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
                        if (ev.key === Qt.Key_Down) { win.moveSel(win.mode === "bg" ? win.bgCols : 1); ev.accepted = true }
                        else if (ev.key === Qt.Key_Up) { win.moveSel(win.mode === "bg" ? -win.bgCols : -1); ev.accepted = true }
                        else if (win.mode === "bg" && ev.key === Qt.Key_Right) { win.moveSel(1); ev.accepted = true }
                        else if (win.mode === "bg" && ev.key === Qt.Key_Left) { win.moveSel(-1); ev.accepted = true }
                        else if (win.mode === "proc" && ev.key === Qt.Key_Right) {
                            const it = win.results[win.selIndex]
                            if (it && it.isGroup && it.expandable && win.procExpanded[it.pid] !== true)
                                win.toggleGroup(it.pid)
                            ev.accepted = true
                        }
                        else if (win.mode === "proc" && ev.key === Qt.Key_Left) {
                            const it = win.results[win.selIndex]
                            if (it && it.isGroup && win.procExpanded[it.pid] === true) {
                                win.toggleGroup(it.pid)
                            } else if (it && it.isChild) {
                                // sobe pro cabeçalho do grupo e fecha
                                for (let i = win.selIndex - 1; i >= 0; i--)
                                    if (win.results[i] && win.results[i].isGroup) {
                                        win.selIndex = i
                                        if (win.procExpanded[win.results[i].pid] === true)
                                            win.toggleGroup(win.results[i].pid)
                                        break
                                    }
                            }
                            ev.accepted = true
                        }
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
                            else if (win.mode === "bg") win.cycleBgTarget()
                            ev.accepted = true
                        } else if (ev.key === Qt.Key_Backspace && win.mode === "files" && win.modeArg === ""
                                   && LauncherService.cwd !== "/" && LauncherService.cwd !== LauncherService.home) {
                            LauncherService.dirUp()   // no $HOME/raiz o Backspace volta a apagar o texto
                            ev.accepted = true
                        } else if (ev.key === Qt.Key_Delete && win.mode === "color"
                                   && win.results[win.selIndex] && win.results[win.selIndex].kind === "color") {
                            LauncherService.removeColorHistory(win.results[win.selIndex].hex)
                            ev.accepted = true
                        } else if (ev.key === Qt.Key_Delete && win.mode === "notes"
                                   && win.results[win.selIndex] && win.results[win.selIndex].kind === "note") {
                            LauncherService.deleteNote(win.results[win.selIndex].path)
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
                        : win.mode === "notes" ? "NOTAS"
                        : win.mode === "color" ? "COR"
                        : win.mode === "bg" ? "WALLPAPER"
                        : win.mode === "theme" ? "TEMA"
                        : win.mode === "calc" ? "CALC"
                        : "COMANDOS"
                    color: Config.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                }
            }

            // ── /dir e /bg: caminho atual / pasta dos wallpapers ──
            Text {
                visible: win.mode === "files" || win.mode === "bg"
                width: col.width
                text: win.mode === "files" ? win.cwdPretty : win.bgDirPretty
                color: Config.launcherSub
                font.pixelSize: Config.launcherFontSize - 1
                elide: Text.ElideLeft
                leftPadding: 6
            }

            // ── /bg: chips do alvo (todos / cada monitor) + toggle do carrossel ──
            Item {
                visible: win.mode === "bg"
                width: col.width
                height: 24

                Row {
                    spacing: 6
                    leftPadding: 6
                    Repeater {
                        model: win.bgTargets
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: win.bgTarget === modelData.key
                            width: tgtTxt.implicitWidth + 20
                            height: 24
                            radius: 12
                            color: sel ? Config.accent : Theme.surface0
                            border.color: sel ? Config.accent : Theme.surface2
                            border.width: 1
                            Text {
                                id: tgtTxt
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                color: parent.sel ? Theme.crust : Config.launcherSub
                                font.pixelSize: 11
                                font.bold: parent.sel
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { win.bgTarget = parent.modelData.key; input.forceActiveFocus() }
                            }
                        }
                    }
                }

                // carrossel: troca automática periódica (WallpaperService observa o Config)
                Rectangle {
                    readonly property bool on: Config.wallpaperCarousel
                    anchors.right: parent.right
                    width: carTxt.implicitWidth + 20
                    height: 24
                    radius: 12
                    color: on ? Config.accent : Theme.surface0
                    border.color: on ? Config.accent : Theme.surface2
                    border.width: 1
                    Text {
                        id: carTxt
                        anchors.centerIn: parent
                        text: "Carrossel " + (parent.on ? "" + Config.wallpaperCarouselMin + " min" : "off")
                        color: parent.on ? Theme.crust : Config.launcherSub
                        font.pixelSize: 11
                        font.bold: parent.on
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Settings.set("wallpaperCarousel", !parent.on); input.forceActiveFocus() }
                    }
                }
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

            Rectangle { visible: !win.notesFull; width: col.width; height: 1; color: Config.launcherBorder }

            // ── /proc: rótulos das colunas (PID/CPU/RAM) — casam com os widths
            //    64/74/88 das linhas de processo; acende no acento a coluna ordenada ──
            Item {
                visible: win.mode === "proc"
                width: col.width
                height: 15
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "APLICATIVO"
                    color: win.procSort === "name" ? Config.accent : Config.launcherSub
                    font.pixelSize: Config.launcherFontSize - 3
                    font.bold: true; font.letterSpacing: 1
                }
                Row {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Text {
                        width: 64; horizontalAlignment: Text.AlignRight; text: "PID"
                        color: win.procSort === "pid" ? Config.accent : Config.launcherSub
                        font.pixelSize: Config.launcherFontSize - 3
                        font.bold: true; font.letterSpacing: 1
                    }
                    Text {
                        width: 74; horizontalAlignment: Text.AlignRight; text: "CPU"
                        color: win.procSort === "cpu" ? Config.accent : Config.launcherSub
                        font.pixelSize: Config.launcherFontSize - 3
                        font.bold: true; font.letterSpacing: 1
                    }
                    Text {
                        width: 88; horizontalAlignment: Text.AlignRight; text: "RAM"
                        color: win.procSort === "ram" ? Config.accent : Config.launcherSub
                        font.pixelSize: Config.launcherFontSize - 3
                        font.bold: true; font.letterSpacing: 1
                    }
                }
            }
            // total de CPU/RAM em uso na máquina, alinhado às mesmas colunas
            Item {
                visible: win.mode === "proc"
                width: col.width
                height: Config.launcherRowH
                Text {
                    anchors { left: parent.left; leftMargin: 12; right: totalCols.left; rightMargin: 8
                              verticalCenter: parent.verticalCenter }
                    text: "Total em uso"
                    color: Config.accent
                    font.pixelSize: Config.launcherFontSize
                    font.bold: true
                    elide: Text.ElideRight
                }
                Row {
                    id: totalCols
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Text { width: 64; horizontalAlignment: Text.AlignRight; text: "" }
                    Text {
                        width: 74; horizontalAlignment: Text.AlignRight
                        text: win.fmtCpu(win.procTotalCpu)
                        color: Config.accent
                        font.pixelSize: Config.launcherFontSize - 1
                        font.family: "monospace"
                        font.bold: true
                    }
                    Text {
                        width: 88; horizontalAlignment: Text.AlignRight
                        text: win.fmtMem(LauncherService.memUsedMB)
                        color: Config.accent
                        font.pixelSize: Config.launcherFontSize - 1
                        font.family: "monospace"
                        font.bold: true
                    }
                }
            }
            Rectangle { visible: win.mode === "proc"; width: col.width; height: 1; color: Config.launcherBorder }

            // ── Lista de resultados (todos os modos exceto /bg, que usa a grade abaixo) ──
            ListView {
                id: list
                visible: win.mode !== "bg" && !win.notesFull
                width: col.width
                // altura acompanha o conteúdo até o teto; vazio mantém espaço p/ o aviso
                height: Math.min(Math.max(contentHeight, win.resultCount === 0 ? 64 : 0), Config.launcherListMaxH)
                // anima o crescer/encolher conforme o filtro muda (o painel acompanha via col);
                // desligado durante o abrir/fechar p/ não brigar com o reveal (reset do campo)
                Behavior on height {
                    enabled: win.reveal === 1
                    NumberAnimation { duration: Config.launcherResizeAnim; easing.type: Easing.OutCubic }
                }
                clip: true
                model: win.mode === "bg" ? [] : win.results
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
                                      : (row.modelData.kind === "file" && row.modelData.fileType === "image")
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
                            Rectangle {   // amostra de cor do tema (acento cru da paleta)
                                visible: row.modelData.kind === "theme"
                                anchors.centerIn: parent
                                width: Config.launcherIconSize; height: Config.launcherIconSize
                                radius: width / 2
                                color: row.modelData.kind === "theme"
                                       ? (Theme.palettes[row.modelData.name] ?? Theme).mauve : "transparent"
                                border.color: row.modelData.sub === "atual" ? Config.accent : Theme.surface2
                                border.width: row.modelData.sub === "atual" ? 2 : 1
                            }
                            Rectangle {   // amostra da cor capturada (valor cru do usuário — não vem da paleta)
                                visible: row.modelData.kind === "color"
                                anchors.centerIn: parent
                                width: Config.launcherIconSize; height: Config.launcherIconSize
                                radius: 6
                                color: row.modelData.hex ?? "transparent"
                                border.color: Theme.surface2
                                border.width: 1
                            }
                            Text {   // glifo (comandos, pastas, vídeo/áudio/pdf, capturar cor, notas)
                                visible: row.modelData.kind === "cmd" || row.modelData.kind === "dir"
                                      || row.modelData.kind === "colorpick"
                                      || row.modelData.kind === "note" || row.modelData.kind === "noteNew"
                                      || (row.modelData.kind === "file" && row.modelData.fileType !== "image")
                                anchors.centerIn: parent
                                text: row.modelData.kind === "cmd" ? (row.modelData.glyph ?? "❯")
                                    : row.modelData.kind === "colorpick" ? "💧"
                                    : row.modelData.kind === "noteNew" ? "➕"
                                    : row.modelData.kind === "note" ? "📝"
                                    : row.modelData.kind === "dir" ? (row.modelData.up ? "↩" : "📁")
                                    : row.modelData.fileType === "audio" ? "🎵"
                                    : row.modelData.fileType === "pdf" ? "📄"
                                    : "🎬"
                                color: Config.launcherText   // sem isso cai no preto padrão do QML — some em tema escuro
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

                        // linha de processo: grupo de app (soma da subárvore, expansível)
                        // ou processo-filho indentado. Colunas PID/CPU/RAM à direita.
                        Item {
                            id: procLine
                            visible: row.modelData.kind === "proc"
                            anchors.fill: parent
                            anchors { leftMargin: 12; rightMargin: 10 }
                            readonly property bool isChild: row.modelData.isChild === true
                            readonly property bool isGroup: row.modelData.isGroup === true
                            readonly property bool expandable: row.modelData.expandable === true
                            readonly property bool emphasize: isGroup && expandable   // linha "cabeçalho"

                            Text {   // triângulo de expandir/recolher (só grupos com >1 processo)
                                id: caret
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                width: 16
                                horizontalAlignment: Text.AlignHCenter
                                text: procLine.expandable ? (row.modelData.expanded ? "▾" : "▸") : ""
                                color: Config.launcherSub
                                font.pixelSize: Config.launcherFontSize - 3
                            }
                            Text {   // nome do app (+ nº de processos) ou "└ nome" do filho
                                anchors { left: caret.right; leftMargin: procLine.isChild ? 16 : 2
                                          right: procCols.left; rightMargin: 8
                                          verticalCenter: parent.verticalCenter }
                                text: procLine.isChild
                                      ? "└ " + (row.modelData.name ?? "")
                                      : (row.modelData.name ?? "") + (procLine.expandable ? "  ·" + row.modelData.count : "")
                                color: procLine.isChild ? Config.launcherSub : Config.launcherText
                                font.pixelSize: procLine.isChild ? Config.launcherFontSize - 1 : Config.launcherFontSize
                                font.bold: procLine.emphasize
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
                                    text: win.fmtCpu(row.modelData.cpu ?? 0)
                                    color: win.procSort === "cpu" ? Config.accent : Config.launcherSub
                                    font.pixelSize: Config.launcherFontSize - 1
                                    font.family: "monospace"
                                    font.bold: procLine.emphasize
                                }
                                Text {
                                    width: 88; horizontalAlignment: Text.AlignRight
                                    text: win.fmtMem(row.modelData.mem ?? 0)
                                    color: win.procSort === "ram" ? Config.accent : Config.launcherSub
                                    font.pixelSize: Config.launcherFontSize - 1
                                    font.family: "monospace"
                                    font.bold: procLine.emphasize
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

            // ── Grade do /bg: cada wallpaper como imagem grande + nome embaixo (menor) ──
            GridView {
                id: bgGrid
                visible: win.mode === "bg"
                width: col.width
                cellWidth: Config.launcherBgThumbW + Config.launcherBgCellGap
                cellHeight: Config.launcherBgThumbH + Config.launcherBgNameSize + 22 + Config.launcherBgCellGap
                // altura acompanha o conteúdo até o teto; vazio mantém espaço p/ o aviso
                height: Math.min(Math.max(contentHeight, win.resultCount === 0 ? 64 : 0), Config.launcherBgListMaxH)
                Behavior on height {
                    enabled: win.reveal === 1
                    NumberAnimation { duration: Config.launcherResizeAnim; easing.type: Easing.OutCubic }
                }
                clip: true
                model: win.mode === "bg" ? win.results : []
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === win.selIndex
                    readonly property bool current: modelData.sub === "atual"
                    width: bgGrid.cellWidth - Config.launcherBgCellGap
                    height: bgGrid.cellHeight - Config.launcherBgCellGap

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: cell.selected ? Config.launcherSel : "transparent"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Item {
                                width: parent.width
                                height: Config.launcherBgThumbH
                                Image {
                                    anchors.fill: parent
                                    source: win.fileUrl(cell.modelData.path)
                                    sourceSize: Qt.size(Config.launcherBgThumbW * 2, Config.launcherBgThumbH * 2)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                Rectangle {   // realce do wallpaper aplicado no momento
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: 6
                                    border.width: cell.current ? 2 : 0
                                    border.color: Config.accent
                                }
                            }
                            Text {
                                width: parent.width
                                text: cell.modelData.name ?? ""
                                color: cell.current ? Config.accent : Config.launcherText
                                font.pixelSize: Config.launcherBgNameSize
                                font.bold: cell.current
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideMiddle
                            }
                        }
                    }

                    MouseArea {
                        id: cellMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (mouse) => win.hoverSelect(cellMA, mouse.x, mouse.y, cell.index)
                        onClicked: (mouse) => win.activate(cell.modelData, mouse.modifiers)
                    }
                }

                // barra de rolagem fina (mesmo estilo da lista)
                Rectangle {
                    visible: bgGrid.contentHeight > bgGrid.height
                    anchors { right: parent.right; rightMargin: 1 }
                    width: 4; radius: 2
                    color: Theme.surface2
                    height: bgGrid.contentHeight > 0 ? bgGrid.height * (bgGrid.height / bgGrid.contentHeight) : 0
                    y: (bgGrid.contentHeight > bgGrid.height)
                       ? (bgGrid.contentY / (bgGrid.contentHeight - bgGrid.height)) * (bgGrid.height - height)
                       : 0
                }

                // vazio: nenhuma imagem na pasta configurada
                Text {
                    visible: win.resultCount === 0
                    anchors.centerIn: parent
                    text: "Nenhuma imagem em " + win.bgDirPretty
                    color: Config.launcherSub
                    font.pixelSize: Config.launcherFontSize
                }
            }

            // ══════════ /notes: editor de texto embutido ══════════
            Item {
                id: notesEditorBox
                visible: win.mode === "notes" && win.notesEdit
                width: col.width
                height: visible ? (edHeader.height + 8 + edFrame.height + 8 + edHint.height) : 0

                // texto do editor (a fonte de verdade enquanto edita)
                property alias text: noteEditor.text
                readonly property bool dirty: text !== LauncherService.editorInitial
                readonly property string title: {
                    const l = ("" + noteEditor.text).split("\n")[0].trim()
                    return l !== "" ? l : "(sem título)"
                }

                function loadIn() {
                    noteEditor.text = LauncherService.editorLoaded
                    noteEditor.cursorPosition = noteEditor.text.length
                    Qt.callLater(() => noteEditor.forceActiveFocus())
                }
                function save()  { LauncherService.saveEditor(noteEditor.text) }
                function leave() { LauncherService.leaveEditor(noteEditor.text) }
                onVisibleChanged: if (visible) loadIn()

                FontMetrics { id: edFm; font: noteEditor.font }

                // cabeçalho: nome da nota + botões Voltar / Salvar
                Item {
                    id: edHeader
                    width: parent.width
                    height: 30
                    Text {
                        anchors { left: parent.left; leftMargin: 6; right: edBtns.left; rightMargin: 10
                                  verticalCenter: parent.verticalCenter }
                        text: notesEditorBox.title + (notesEditorBox.dirty ? "  ·  não salvo" : "")
                        color: notesEditorBox.dirty ? Config.accent : Config.launcherText
                        font.pixelSize: Config.launcherFontSize + 1
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Row {
                        id: edBtns
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Repeater {
                            model: [{ k: "back", label: "← Voltar", accent: false },
                                    { k: "save", label: "Salvar",   accent: true }]
                            delegate: Rectangle {
                                required property var modelData
                                width: bTxt.implicitWidth + 20
                                height: 24
                                radius: 12
                                color: modelData.accent ? Config.accent : Theme.surface0
                                border.color: modelData.accent ? Config.accent : Theme.surface2
                                border.width: 1
                                Text {
                                    id: bTxt
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    color: parent.modelData.accent ? Theme.crust : Config.launcherText
                                    font.pixelSize: 11
                                    font.bold: parent.modelData.accent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.modelData.k === "save" ? notesEditorBox.save() : notesEditorBox.leave()
                                }
                            }
                        }
                    }
                }

                // moldura da área de edição: calha de números (overlay fixo à esquerda)
                // + TextEdit num Flickable (rola nos dois eixos, sem wrap)
                Rectangle {
                    id: edFrame
                    anchors.top: edHeader.bottom
                    anchors.topMargin: 8
                    width: parent.width
                    height: Config.launcherNotesEditorH
                    radius: 8
                    color: Theme.surface0
                    border.color: Config.launcherBorder
                    border.width: 1
                    clip: true

                    readonly property int pad: 6
                    readonly property int gutterW: Math.max(28,
                        Math.round(edFm.advanceWidth("8") * ("" + Math.max(1, noteEditor.lineCount)).length) + 14)

                    Flickable {
                        id: edFlick
                        anchors.fill: parent
                        anchors.leftMargin: edFrame.pad + edFrame.gutterW + 5
                        anchors.rightMargin: edFrame.pad
                        anchors.topMargin: edFrame.pad
                        anchors.bottomMargin: edFrame.pad
                        contentWidth: Math.max(width, noteEditor.contentWidth + 4)
                        contentHeight: Math.max(height, noteEditor.contentHeight)
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        TextEdit {
                            id: noteEditor
                            width: Math.max(edFlick.width, contentWidth + 4)
                            color: Config.launcherText
                            font.family: "monospace"
                            font.pixelSize: Config.launcherFontSize
                            selectionColor: Config.launcherSel
                            selectByMouse: true
                            wrapMode: TextEdit.NoWrap
                            textFormat: TextEdit.PlainText
                            persistentSelection: true

                            // mantém o cursor visível dentro do Flickable (com clamp aos limites)
                            onCursorRectangleChanged: {
                                const r = cursorRectangle
                                const maxY = Math.max(0, edFlick.contentHeight - edFlick.height)
                                const maxX = Math.max(0, edFlick.contentWidth - edFlick.width)
                                let ny = edFlick.contentY
                                if (r.y < ny) ny = r.y
                                else if (r.y + r.height > ny + edFlick.height) ny = r.y + r.height - edFlick.height
                                edFlick.contentY = Math.max(0, Math.min(ny, maxY))
                                let nx = edFlick.contentX
                                if (r.x < nx + 8) nx = r.x - 8
                                else if (r.x > nx + edFlick.width - 8) nx = r.x - edFlick.width + 24
                                edFlick.contentX = Math.max(0, Math.min(nx, maxX))
                            }
                            Keys.onPressed: (ev) => {
                                if (ev.key === Qt.Key_Escape) {
                                    notesEditorBox.leave(); ev.accepted = true
                                } else if (ev.key === Qt.Key_S && (ev.modifiers & Qt.ControlModifier)) {
                                    notesEditorBox.save(); ev.accepted = true
                                } else if (ev.key === Qt.Key_Tab) {
                                    noteEditor.insert(noteEditor.cursorPosition, "    ")
                                    ev.accepted = true
                                }
                            }
                        }
                    }

                    // calha de números: overlay fixo à esquerda, só o Y acompanha o scroll
                    Item {
                        x: edFrame.pad
                        y: edFrame.pad
                        width: edFrame.gutterW
                        height: edFrame.height - 2 * edFrame.pad
                        clip: true
                        Column {
                            y: -edFlick.contentY
                            width: parent.width
                            Repeater {
                                model: Math.max(1, noteEditor.lineCount)
                                delegate: Text {
                                    required property int index
                                    width: edFrame.gutterW - 6
                                    height: edFm.lineSpacing
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                    text: "" + (index + 1)
                                    color: Config.launcherSub
                                    font.family: "monospace"
                                    font.pixelSize: Config.launcherFontSize
                                }
                            }
                        }
                    }
                    Rectangle {   // filete separando calha e texto
                        x: edFrame.pad + edFrame.gutterW + 2
                        y: edFrame.pad
                        width: 1
                        height: edFrame.height - 2 * edFrame.pad
                        color: Config.launcherBorder
                    }

                    // barra de rolagem vertical fina (overlay fixo sobre a moldura)
                    Rectangle {
                        visible: edFlick.contentHeight > edFlick.height
                        anchors { right: parent.right; rightMargin: 2 }
                        y: edFrame.pad + (edFlick.contentHeight > edFlick.height
                                ? (edFlick.contentY / (edFlick.contentHeight - edFlick.height))
                                  * (edFlick.height - height)
                                : 0)
                        width: 4; radius: 2
                        color: Theme.surface2
                        height: edFlick.contentHeight > 0
                                ? edFlick.height * (edFlick.height / edFlick.contentHeight) : 0
                    }
                }

                Text {
                    id: edHint
                    anchors.top: edFrame.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    width: parent.width - 12
                    text: "Ctrl+S salva · Esc/Voltar guarda um rascunho e volta · o nome da nota é a 1ª linha"
                    color: Config.launcherSub
                    font.pixelSize: Config.launcherFontSize - 3
                    elide: Text.ElideRight
                }
            }

            // ══════════ /notes: revisão de rascunho não salvo ══════════
            Item {
                id: notesReviewBox
                visible: win.mode === "notes" && win.notesReview
                width: col.width
                height: visible ? (rvHead.height + 6 + rvSub.height + 8 + rvFrame.height + 10 + rvBtns.height) : 0

                // o campo de busca fica invisível aqui (perde o foco) → esta tela
                // captura o teclado sozinha: Enter mantém, Delete descarta, Esc cancela
                focus: visible
                activeFocusOnTab: false
                onVisibleChanged: if (visible) forceActiveFocus()
                Keys.onPressed: (ev) => {
                    if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { LauncherService.keepSketch(); ev.accepted = true }
                    else if (ev.key === Qt.Key_Delete) { LauncherService.discardSketch(); ev.accepted = true }
                    else if (ev.key === Qt.Key_Escape) { LauncherService.cancelReview(); ev.accepted = true }
                }

                Text {
                    id: rvHead
                    width: parent.width
                    anchors.left: parent.left; anchors.leftMargin: 6
                    text: "“" + LauncherService.sketchReviewName + "” foi fechada sem salvar"
                    color: Config.launcherText
                    font.pixelSize: Config.launcherFontSize + 2
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    id: rvSub
                    anchors.top: rvHead.bottom; anchors.topMargin: 6
                    anchors.left: parent.left; anchors.leftMargin: 6
                    width: parent.width - 12
                    text: "Há um rascunho guardado. Manter e continuar editando, ou descartar e "
                          + "abrir a última versão salva?"
                    color: Config.launcherSub
                    font.pixelSize: Config.launcherFontSize - 1
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    id: rvFrame
                    anchors.top: rvSub.bottom; anchors.topMargin: 8
                    width: parent.width
                    height: Math.min(Config.launcherNotesEditorH, 240)
                    radius: 8
                    color: Theme.surface0
                    border.color: Config.launcherBorder
                    border.width: 1
                    clip: true
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 8
                        contentWidth: width
                        contentHeight: rvText.height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        Text {
                            id: rvText
                            width: parent.width
                            text: LauncherService.sketchReviewText
                            color: Config.launcherText
                            font.family: "monospace"
                            font.pixelSize: Config.launcherFontSize - 1
                            wrapMode: Text.Wrap
                        }
                    }
                }
                Row {
                    id: rvBtns
                    anchors.top: rvFrame.bottom; anchors.topMargin: 10
                    anchors.left: parent.left; anchors.leftMargin: 6
                    spacing: 8
                    Repeater {
                        model: [{ k: "keep",    label: "Manter rascunho", accent: true },
                                { k: "discard", label: "Descartar",       accent: false },
                                { k: "cancel",  label: "Cancelar",        accent: false }]
                        delegate: Rectangle {
                            required property var modelData
                            width: rvTxt.implicitWidth + 22
                            height: 26
                            radius: 13
                            color: modelData.accent ? Config.accent : Theme.surface0
                            border.color: modelData.accent ? Config.accent : Theme.surface2
                            border.width: 1
                            Text {
                                id: rvTxt
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                color: parent.modelData.accent ? Theme.crust : Config.launcherText
                                font.pixelSize: 11
                                font.bold: parent.modelData.accent
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.modelData.k === "keep") LauncherService.keepSketch()
                                    else if (parent.modelData.k === "discard") LauncherService.discardSketch()
                                    else LauncherService.cancelReview()
                                }
                            }
                        }
                    }
                }
            }

            // ── Rodapé: dicas + contagem ──
            Item {
                visible: !win.notesFull
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
