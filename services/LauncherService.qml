pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"           // Config (launcherTerminal)

// Lançador de aplicativos próprio — a parte NÃO-visual.
// A janela (windows/LauncherWindow.qml) é só view; aqui ficam:
//   • a lista de apps instalados (DesktopEntries do Quickshell) + contagem de uso
//     persistida em ~/.config/quickshell/launcher-usage.json ("mais usados");
//   • o lançamento via `niri msg action spawn-sh` (env Wayland correto, ver CLAUDE.md);
//   • a navegação de arquivos do modo /dir (find por diretório, só mídia) → VLC;
//   • a lista de processos do modo /proc (ps) + finalizar (kill);
//   • a calculadora do modo "=" (parser próprio — SEM eval, p/ não expor o escopo QML);
//   • as ações /reload (Quickshell.reload) e /config (Settings.open);
//   • o IpcHandler "launcher" p/ keybind do niri: `qs ipc call launcher toggle`.
Singleton {
    id: svc

    // ── Estado de abertura (a LauncherWindow observa) ──
    property bool open: false
    function show()   { open = true }
    function hide()   { open = false }
    function toggle() { open = !open }

    readonly property string home: Quickshell.env("HOME")

    // escapa UMA string p/ dentro de aspas simples de shell
    function shq(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'" }

    // pede ao niri para rodar `script` pela shell dele (apps gráficos precisam do
    // ambiente Wayland do compositor; PATH mínimo → estende antes, como no CaptureService)
    function spawn(script) {
        const full = "export PATH=\"$HOME/.cargo/bin:$HOME/.local/bin:$PATH\"; " + script
        spawnProc.exec(["niri", "msg", "action", "spawn-sh", "--", full])
    }
    Process { id: spawnProc }

    // ═════════════════════════ Aplicativos instalados ═════════════════════════
    // DesktopEntries varre os .desktop do sistema (XDG); `values` notifica mudanças.
    readonly property var apps: {
        const list = DesktopEntries.applications.values
        const out = []
        for (let i = 0; i < list.length; i++)
            if (!list[i].noDisplay) out.push(list[i])
        out.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
        return out
    }

    // contagem de uso (id do .desktop -> nº de lançamentos), p/ "mais usados"
    property var usage: ({})
    function usageOf(id) { return (usage && usage[id]) ? usage[id] : 0 }
    function bumpUsage(id) {
        var d = {}
        for (var k in usage) d[k] = usage[k]
        d[id] = (d[id] ?? 0) + 1
        usage = d                      // reatribui o mapa inteiro p/ os bindings reavaliarem
        usageSaveTimer.restart()
    }
    readonly property string usagePath: home + "/.config/quickshell/launcher-usage.json"
    FileView {
        id: usageFile
        path: svc.usagePath
        blockLoading: true
        printErrors: false             // 1ª execução: arquivo ainda não existe (normal)
        onLoaded: {
            try { svc.usage = JSON.parse(usageFile.text() || "{}") }
            catch (e) { svc.usage = ({}) }
        }
        onLoadFailed: svc.usage = ({})
    }
    Timer { id: usageSaveTimer; interval: 400; onTriggered: usageFile.setText(JSON.stringify(svc.usage, null, 2)) }

    // lança um DesktopEntry pelo compositor. Usa `command` (argv já sem os field
    // codes %f/%u), não execute(): o execDetached do Quickshell não herda o env Wayland.
    function launchApp(entry) {
        if (!entry) return
        const argv = entry.command ?? []
        if (argv.length === 0) return
        let line = argv.map(shq).join(" ")
        if (entry.runInTerminal) line = shq(Config.launcherTerminal) + " -e " + line
        spawn("exec " + line)
        bumpUsage(entry.id)
        hide()
    }

    // ═════════════════════════ /dir — arquivos de mídia ═════════════════════════
    property string cwd: ""            // diretório atual do navegador
    property var files: []             // [{ name, path, isDir, isVideo }] do cwd (só dirs + mídia)
    property int dirSeq: 0             // descarta respostas fora de ordem (navegação rápida)

    readonly property var imageExts: ["jpg","jpeg","png","gif","webp","bmp","svg","avif","jxl","tif","tiff","heic","heif","ico"]
    readonly property var videoExts: ["mp4","mkv","webm","avi","mov","m4v","wmv","flv","mpg","mpeg","m2ts","ts","ogv","3gp"]

    function extOf(name) {
        const d = name.lastIndexOf(".")
        return d > 0 ? name.substring(d + 1).toLowerCase() : ""
    }

    function listDir(path) {
        cwd = path
        dirSeq++
        const seq = dirSeq
        dirProc.seq = seq
        // -L segue symlinks (dir apontado vira navegável); %y\t%f = tipo + nome
        dirProc.exec(["sh", "-c",
            "cd -- " + shq(path) + " 2>/dev/null && find -L . -maxdepth 1 -mindepth 1 \\( -type d -o -type f \\) -printf '%y\\t%f\\n' 2>/dev/null"])
    }
    function dirUp() {
        if (cwd === "/" || cwd === "") return
        const cut = cwd.lastIndexOf("/")
        listDir(cut <= 0 ? "/" : cwd.substring(0, cut))
    }
    Process {
        id: dirProc
        property int seq: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (dirProc.seq !== svc.dirSeq) return   // navegação mudou no meio: ignora
                const dirs = [], media = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const tab = lines[i].indexOf("\t")
                    if (tab < 0) continue
                    const type = lines[i].substring(0, tab)
                    const name = lines[i].substring(tab + 1)
                    if (name === "" || name[0] === ".") continue          // oculta dotfiles
                    const base = svc.cwd === "/" ? "" : svc.cwd
                    if (type === "d") {
                        dirs.push({ name: name, path: base + "/" + name, isDir: true, isVideo: false })
                    } else {
                        const ext = svc.extOf(name)
                        const isVid = svc.videoExts.indexOf(ext) >= 0
                        if (isVid || svc.imageExts.indexOf(ext) >= 0)
                            media.push({ name: name, path: base + "/" + name, isDir: false, isVideo: isVid })
                    }
                }
                const cmp = (a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base", numeric: true })
                dirs.sort(cmp); media.sort(cmp)
                svc.files = dirs.concat(media)
            }
        }
    }

    // abre imagem/vídeo no VLC (app gráfico -> pelo compositor)
    function openFile(path) {
        spawn("exec vlc " + shq(path))
        hide()
    }

    // ═════════════════════════ /proc — processos ═════════════════════════
    property var procs: []             // [{ pid, cpu, mem, name }] (mem em MiB)

    function refreshProcs() { psProc.exec(["ps", "axo", "pid=,pcpu=,pmem=,rss=,comm="]) }
    Process {
        id: psProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    // pid %cpu %mem rss comm  (comm pode ter espaços: "Isolated Web Co")
                    const m = lines[i].match(/^\s*(\d+)\s+([\d.,]+)\s+([\d.,]+)\s+(\d+)\s+(.+)$/)
                    if (!m) continue
                    out.push({
                        pid: parseInt(m[1]),
                        cpu: parseFloat(m[2].replace(",", ".")),
                        mem: Math.round(parseInt(m[4]) / 1024),
                        name: m[5].trim()
                    })
                }
                svc.procs = out
            }
        }
    }

    // finaliza um processo (padrão: SIGTERM; hard=true: SIGKILL) e relê a lista
    function killProc(pid, hard) {
        killP.exec(["kill", hard ? "-KILL" : "-TERM", "" + pid])
        killRefresh.restart()
    }
    Process { id: killP }
    Timer { id: killRefresh; interval: 350; onTriggered: svc.refreshProcs() }

    // ═════════════════════════ Ações /reload e /config ═════════════════════════
    function reloadShell() { hide(); Quickshell.reload(false) }   // false = soft (reusa janelas)
    function openConfig()  { hide(); Settings.open = true }       // mesma pasta: sem import

    // ═════════════════════════ "=" — calculadora ═════════════════════════
    // Parser recursivo próprio (nada de eval: eval veria o escopo QML — Settings etc.).
    // Suporta: + - * / % ^ (e **), parênteses, unário, funções (sqrt, sin, log…),
    // constantes pi/e/tau, multiplicação implícita "2pi"/"3(1+2)" e notação 2e3.
    // Vírgula: sem "(" na expressão é decimal (=1,5+2); com função, separa argumentos.
    function calc(src) {
        let s = ("" + (src ?? "")).replace(/\*\*/g, "^")
        if (s.indexOf("(") === -1) s = s.replace(/,/g, ".")
        let i = 0
        const funcs = {
            sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, exp: Math.exp,
            ln: Math.log, log: Math.log10, log10: Math.log10, log2: Math.log2,
            sin: Math.sin, cos: Math.cos, tan: Math.tan,
            asin: Math.asin, acos: Math.acos, atan: Math.atan,
            floor: Math.floor, ceil: Math.ceil, round: Math.round,
            min: Math.min, max: Math.max, pow: Math.pow
        }
        const consts = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI }

        function err(m) { const e = new Error(m); e.calc = true; throw e }
        function peek() {
            while (i < s.length && (s[i] === " " || s[i] === "\t")) i++
            return i < s.length ? s[i] : ""
        }
        function parseExpr() {
            let v = parseTerm()
            for (;;) {
                const c = peek()
                if (c === "+") { i++; v += parseTerm() }
                else if (c === "-" || c === "−") { i++; v -= parseTerm() }
                else break
            }
            return v
        }
        function parseTerm() {
            let v = parsePow()
            for (;;) {
                const c = peek()
                if (c === "*" || c === "×") { i++; v *= parsePow() }
                else if (c === "/" || c === "÷") { i++; v /= parsePow() }
                else if (c === "%") { i++; v %= parsePow() }
                else if (c === "(" || /[a-zA-Zπ]/.test(c)) v *= parsePow()   // multiplicação implícita
                else break
            }
            return v
        }
        function parsePow() {
            const b = parseUnary()
            if (peek() === "^") { i++; return Math.pow(b, parsePow()) }   // ^ associa à direita
            return b
        }
        function parseUnary() {
            const c = peek()
            if (c === "-" || c === "−") { i++; return -parseUnary() }
            if (c === "+") { i++; return parseUnary() }
            return parseAtom()
        }
        function parseAtom() {
            const c = peek()
            if (c === "(") {
                i++
                const v = parseExpr()
                if (peek() !== ")") err("falta fechar parêntese")
                i++
                return v
            }
            if (/[0-9.]/.test(c)) return parseNumber()
            if (/[a-zA-Zπ]/.test(c)) return parseIdent()
            err(c === "" ? "expressão incompleta" : "símbolo inesperado “" + c + "”")
        }
        function parseNumber() {
            peek()
            const start = i
            while (i < s.length && /[0-9]/.test(s[i])) i++
            if (s[i] === ".") { i++; while (i < s.length && /[0-9]/.test(s[i])) i++ }
            if (s[i] === "e" || s[i] === "E") {           // notação científica 2e3
                const save = i
                i++
                if (s[i] === "+" || s[i] === "-") i++
                if (/[0-9]/.test(s[i])) { while (i < s.length && /[0-9]/.test(s[i])) i++ }
                else i = save                             // era a constante e (ex.: "2e")
            }
            const v = parseFloat(s.substring(start, i))
            if (isNaN(v)) err("número inválido")
            return v
        }
        function parseIdent() {
            peek()
            if (s[i] === "π") { i++; return Math.PI }
            const start = i
            while (i < s.length && /[a-zA-Z0-9_]/.test(s[i])) i++
            const name = s.substring(start, i).toLowerCase()
            if (peek() === "(") {
                const f = funcs[name]
                if (!f) err("função desconhecida “" + name + "”")
                i++
                const args = []
                if (peek() !== ")") {
                    args.push(parseExpr())
                    while (peek() === "," || peek() === ";") { i++; args.push(parseExpr()) }
                }
                if (peek() !== ")") err("falta fechar parêntese")
                i++
                return f.apply(null, args)
            }
            if (consts[name] !== undefined) return consts[name]
            err("nome desconhecido “" + name + "”")
        }

        try {
            if (peek() === "") return { ok: false, error: "expressão vazia" }
            const v = parseExpr()
            if (peek() !== "") err("símbolo inesperado “" + s[i] + "”")
            if (typeof v !== "number" || isNaN(v)) return { ok: false, error: "resultado indefinido" }
            return { ok: true, value: v, text: fmtCalc(v) }
        } catch (e) {
            return { ok: false, error: e.calc ? e.message : "expressão inválida" }
        }
    }
    // formata sem ruído de float (0.30000000000000004 -> 0.3)
    function fmtCalc(v) {
        if (!isFinite(v)) return v > 0 ? "∞" : "-∞"
        const r = Number(v.toPrecision(12))
        const a = Math.abs(r)
        if (a !== 0 && (a >= 1e15 || a < 1e-9)) return r.toExponential(8).replace(/\.?0+e/, "e")
        return "" + r
    }

    // ═════════════════════════ IPC (keybind do niri) ═════════════════════════
    // `qs ipc call launcher toggle` — o singleton é instanciado no boot pela
    // LauncherWindow (shell.qml), então o alvo existe desde o início.
    // ⚠️ NÃO nomear uma função IPC de "show": o CLI engole (`qs ipc show` é subcomando).
    IpcHandler {
        target: "launcher"
        function toggle(): void { svc.toggle() }
        function open(): void   { svc.show() }
        function close(): void  { svc.hide() }
    }
}
