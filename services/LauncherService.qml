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
//   • a navegação de arquivos do modo /dir (find por diretório, imagem/vídeo/áudio/pdf)
//     → VLC (imagem/vídeo/áudio) ou Zen Browser (pdf, via flatpak --file-forwarding);
//   • a lista de processos do modo /proc (ps) + finalizar (kill);
//   • as notas do modo /notes (um .txt por nota em Config.launcherNotesDir; o nome
//     da nota é a 1ª linha do arquivo) + o editor de texto EMBUTIDO, com rascunhos
//     ("sketch") p/ quem sai sem salvar e revisão ao reabrir;
//   • o modo /color-picker (grim+slurp+imagemagick escolhem UM pixel da tela) + histórico
//     persistido, com cópia pro clipboard (wl-copy) de um item salvo;
//   • a calculadora do modo "=" (parser próprio — SEM eval, p/ não expor o escopo QML);
//   • as ações /reload (Quickshell.reload), /config (Settings.open) e /reboot,
//     /poweroff (rodam reboot/poweroff no terminal configurado);
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
    property var files: []             // [{ name, path, isDir, fileType }] do cwd (só dirs + mídia/pdf)
    property int dirSeq: 0             // descarta respostas fora de ordem (navegação rápida)

    // fileType: "image" | "video" | "audio" | "pdf"
    readonly property var imageExts: ["jpg","jpeg","png","gif","webp","bmp","svg","avif","jxl","tif","tiff","heic","heif","ico"]
    readonly property var videoExts: ["mp4","mkv","webm","avi","mov","m4v","wmv","flv","mpg","mpeg","m2ts","ts","ogv","3gp"]
    readonly property var audioExts: ["mp3","wav","flac","ogg","oga","opus","m4a","aac","wma","aiff","alac"]
    readonly property var pdfExts: ["pdf"]

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
                        dirs.push({ name: name, path: base + "/" + name, isDir: true })
                    } else {
                        const ext = svc.extOf(name)
                        const fileType = svc.imageExts.indexOf(ext) >= 0 ? "image"
                                        : svc.videoExts.indexOf(ext) >= 0 ? "video"
                                        : svc.audioExts.indexOf(ext) >= 0 ? "audio"
                                        : svc.pdfExts.indexOf(ext) >= 0 ? "pdf" : ""
                        if (fileType !== "")
                            media.push({ name: name, path: base + "/" + name, isDir: false, fileType: fileType })
                    }
                }
                const cmp = (a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base", numeric: true })
                dirs.sort(cmp); media.sort(cmp)
                svc.files = dirs.concat(media)
            }
        }
    }

    // abre imagem/vídeo/áudio no VLC; PDF no Zen Browser (flatpak — --file-forwarding
    // usa o portal de documentos, então funciona mesmo fora do filesystem liberado ao
    // sandbox, ex.: xdg-download). Sempre pelo compositor (app gráfico, ver CLAUDE.md).
    function openFile(path) {
        const ext = extOf(path.substring(path.lastIndexOf("/") + 1))
        if (pdfExts.indexOf(ext) >= 0)
            spawn("exec flatpak run --file-forwarding app.zen_browser.zen @@u file://" + shq(path) + " @@")
        else
            spawn("exec vlc " + shq(path))
        hide()
    }

    // ═════════════════════════ /proc — processos ═════════════════════════
    // [{ pid, ppid, cpu, mem, name }] (mem em MiB, fracionário). O `ppid` deixa a
    // view (LauncherWindow) montar a ÁRVORE e agrupar toda a subárvore de um app
    // num item só (ex.: as dezenas de "Isolated Web Co" do navegador viram 1 linha
    // com a soma real de RAM/CPU, expansível pra ver os filhos).
    property var procs: []
    // RAM realmente em uso no sistema (MiB) — NÃO é a soma do RSS de cada processo
    // (isso conta várias vezes a mesma lib compartilhada e passa fácil do total físico).
    // Vem de /proc/meminfo: usado = MemTotal - MemAvailable (mesma conta do `free` moderno).
    property real memUsedMB: 0
    property real memTotalMB: 0
    // nº de núcleos lógicos — o `%cpu` do ps é "tempo de CPU / tempo de vida" e um
    // processo/subárvore multi-thread passa fácil de 100%. A view divide por isto p/
    // mostrar a fatia REAL da máquina (0–100% no total), não "% de um núcleo".
    property int cpuCount: 1

    function refreshProcs() {
        psProc.exec(["ps", "-eo", "pid=,ppid=,pcpu=,rss=,comm="])
        memProc.exec(["cat", "/proc/meminfo"])
        if (svc.cpuCount <= 1) nprocProc.exec(["nproc"])
    }
    Process {
        id: nprocProc
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())
                if (n > 0) svc.cpuCount = n
            }
        }
    }
    Process {
        id: psProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    // pid ppid %cpu rss comm  (comm pode ter espaços: "Isolated Web Co")
                    const m = lines[i].match(/^\s*(\d+)\s+(\d+)\s+([\d.,]+)\s+(\d+)\s+(.+)$/)
                    if (!m) continue
                    const pid = parseInt(m[1]), ppid = parseInt(m[2])
                    if (pid === 2 || ppid === 2) continue   // descarta threads de kernel (filhos do kthreadd)
                    out.push({
                        pid: pid,
                        ppid: ppid,
                        cpu: parseFloat(m[3].replace(",", ".")),
                        mem: parseInt(m[4]) / 1024,   // MiB (fracionário; a view soma e formata)
                        name: m[5].trim()
                    })
                }
                svc.procs = out
            }
        }
    }
    Process {
        id: memProc
        stdout: StdioCollector {
            onStreamFinished: {
                const info = {}
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^(\w+):\s+(\d+)/)
                    if (m) info[m[1]] = parseInt(m[2])
                }
                if (info.MemTotal) {
                    const availKb = info.MemAvailable !== undefined ? info.MemAvailable : info.MemFree
                    svc.memTotalMB = info.MemTotal / 1024
                    svc.memUsedMB = (info.MemTotal - availKb) / 1024
                }
            }
        }
    }

    // finaliza um processo (padrão: SIGTERM; hard=true: SIGKILL) e relê a lista
    function killProc(pid, hard) {
        killP.exec(["kill", hard ? "-KILL" : "-TERM", "" + pid])
        killRefresh.restart()
    }
    // finaliza o GRUPO inteiro de um app (todos os PIDs da subárvore de uma vez)
    function killTree(pids, hard) {
        if (!pids || pids.length === 0) return
        killP.exec(["kill", hard ? "-KILL" : "-TERM"].concat(pids.map(p => "" + p)))
        killRefresh.restart()
    }
    Process { id: killP }
    Timer { id: killRefresh; interval: 350; onTriggered: svc.refreshProcs() }

    // ═════════════════════════ /color-picker — captura de cor da tela ═════════════════════════
    // Sem ferramenta pronta equivalente ao awww/gpu-screen-recorder pra "escolher 1 pixel";
    // compõe grim (screenshot) + slurp -p (seleciona 1 PONTO — geometria "X,Y 1x1", já pronta
    // pro -g do grim) + imagemagick (lê o pixel do PNG de 1x1 e devolve "srgb(r,g,b)"). Roda
    // pelo compositor (spawn(), apps gráficos Wayland — ver CLAUDE.md); como o spawn-sh só
    // LANÇA e larga o processo (sem devolver stdout pro Process que chamou), o resultado é
    // escrito num arquivo de cache e um poll curto (Timer+Process) o lê. Um segundo arquivo
    // ".done" marca o fim do script (sucesso OU cancelamento/Esc no slurp) sem depender de
    // casar nome de processo (pgrep) — evita corrida entre o slurp fechar e o grim/magick
    // ainda estarem escrevendo.
    // A janela do lançador é ESCONDIDA antes de disparar (ela é uma layer surface Overlay
    // cobrindo a tela inteira; se ficasse aberta, roubaria o clique do slurp) e reaberta
    // sozinha (show()) quando o poll termina — colorReopenQuery guarda a query pra
    // LauncherWindow restaurar o modo /color-picker (ver onIsOpenChanged lá).
    readonly property string colorResultPath: home + "/.cache/quickshell/colorpicker-result"
    readonly property string colorHistoryPath: home + "/.config/quickshell/color-history.json"
    property bool colorPicking: false
    property int colorPollTries: 0
    property var colorHistory: []          // [{ hex: "#RRGGBB", rgb: "rgb(r, g, b)" }], mais recente primeiro
    property string colorReopenQuery: ""   // consumida por LauncherWindow.onIsOpenChanged

    function pickColor(currentQuery) {
        if (colorPicking) return
        colorReopenQuery = currentQuery
        hide()
        colorPicking = true
        colorPollTries = 0
        const f = colorResultPath
        spawn("mkdir -p ~/.cache/quickshell; rm -f " + shq(f) + " " + shq(f + ".done") + "; "
            + "{ G=$(slurp -p) && grim -g \"$G\" -t png - 2>/dev/null "
            + "| magick png:- -format '%[pixel:p{0,0}]' info: > " + shq(f) + " 2>/dev/null; "
            + "touch " + shq(f + ".done") + "; }")
        colorPollTimer.start()
    }
    Timer {
        id: colorPollTimer
        interval: 200; repeat: true
        onTriggered: {
            svc.colorPollTries++
            if (svc.colorPollTries > 300) { svc.colorPollDone("CANCEL"); return }   // ~60s sem sinal: desiste
            colorPollProc.exec(["sh", "-c",
                "D=" + svc.shq(svc.colorResultPath + ".done") + "; F=" + svc.shq(svc.colorResultPath) + "; "
                + "[ -e \"$D\" ] || exit 0; "
                + "if [ -s \"$F\" ]; then cat \"$F\"; else echo CANCEL; fi; rm -f \"$F\" \"$D\""])
        }
    }
    Process {
        id: colorPollProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out !== "") svc.colorPollDone(out)
            }
        }
    }
    function colorPollDone(raw) {
        colorPollTimer.stop()
        colorPicking = false
        if (raw !== "" && raw !== "CANCEL") {
            const hex = parseMagickPixel(raw)
            if (hex) addColorHistory(hex)
        }
        show()
    }
    // "srgb(170,187,204)"/"srgba(170,187,204,1)" (imagemagick) -> "#AABBCC"
    function parseMagickPixel(raw) {
        const m = ("" + raw).match(/rgba?\((\d+)[,\s]+(\d+)[,\s]+(\d+)/i)
        if (!m) return ""
        const c = [parseInt(m[1]), parseInt(m[2]), parseInt(m[3])]
        return "#" + c.map(n => Math.min(255, n).toString(16).padStart(2, "0").toUpperCase()).join("")
    }
    function addColorHistory(hex) {
        const r = parseInt(hex.substring(1, 3), 16)
        const g = parseInt(hex.substring(3, 5), 16)
        const b = parseInt(hex.substring(5, 7), 16)
        let list = colorHistory.filter(c => c.hex !== hex)   // evita duplicata; recente sobe pro topo
        list.unshift({ hex: hex, rgb: "rgb(" + r + ", " + g + ", " + b + ")" })
        if (list.length > Config.launcherColorHistoryMax) list = list.slice(0, Config.launcherColorHistoryMax)
        colorHistory = list
        colorHistorySaveTimer.restart()
    }
    function removeColorHistory(hex) {
        colorHistory = colorHistory.filter(c => c.hex !== hex)
        colorHistorySaveTimer.restart()
    }
    // copia um valor (hex OU rgb, ver LauncherWindow.activate) pro clipboard. wl-copy é um
    // cliente Wayland de verdade (mantém a seleção viva) -> precisa do ambiente do
    // compositor, daí spawn() (ver CLAUDE.md) em vez de Process direto.
    function copyColor(text) {
        spawn("printf %s " + shq(text) + " | wl-copy")
    }
    FileView {
        id: colorHistoryFile
        path: svc.colorHistoryPath
        blockLoading: true
        printErrors: false             // 1ª execução: arquivo ainda não existe (normal)
        onLoaded: {
            try { svc.colorHistory = JSON.parse(colorHistoryFile.text() || "[]") }
            catch (e) { svc.colorHistory = [] }
        }
        onLoadFailed: svc.colorHistory = []
    }
    Timer { id: colorHistorySaveTimer; interval: 400; onTriggered: colorHistoryFile.setText(JSON.stringify(svc.colorHistory, null, 2)) }

    // ═════════════════════════ /notes — notas de texto + editor embutido ═════════════════════════
    // Uma nota = um .txt em Config.launcherNotesDir; o "nome" exibido é a PRIMEIRA
    // LINHA do arquivo (o nome do arquivo em si é só um timestamp). O editor mora
    // DENTRO do lançador (windows/LauncherWindow.qml lê estas properties):
    //   • Salvar   → grava o .txt e apaga o rascunho
    //   • Voltar   → se mudou e não está vazio, grava um RASCUNHO ("sketch") em
    //                <dir>/.sketches/<arquivo> e volta pra lista sem tocar no .txt
    // Ao reabrir uma nota que tem rascunho, a janela mostra a tela de revisão
    // (manter o rascunho e continuar editando, ou descartá-lo).
    // Escrita: `printf '%s' '<conteúdo>'` num `sh -c` (aspas simples preservam
    // bytes UTF-8 e quebras de linha; `shq` escapa as aspas) — nada de base64
    // (Qt.btoa é Latin-1 e estraga acento). Leitura: `cat` + StdioCollector (UTF-8).
    property var notes: []            // [{ name, path, mtime, saved, hasSketch }] — mais recente 1º
    property int notesSeq: 0          // descarta respostas fora de ordem

    readonly property string sketchDir: Config.launcherNotesDir + "/.sketches"
    function sketchPathFor(notePath) {
        return sketchDir + "/" + notePath.substring(notePath.lastIndexOf("/") + 1)
    }
    function firstLineOf(s) {
        const l = ("" + (s ?? "")).split("\n")[0].trim()
        return l !== "" ? l : "(sem título)"
    }

    function refreshNotes() {
        notesSeq++
        notesProc.seq = notesSeq
        // linha por nota: "<saved>\t<hasSketch>\t<mtime>\t<caminho canônico>\t<1ª linha>"
        //   - varre os .txt da pasta (saved=1) e, à parte, os rascunhos órfãos (saved=0)
        notesProc.exec(["sh", "-c",
            "d=" + shq(Config.launcherNotesDir) + "; s=\"$d/.sketches\"; "
            + "mkdir -p \"$s\" 2>/dev/null; "
            + "for f in \"$d\"/*.txt; do [ -e \"$f\" ] || continue; b=${f##*/}; "
            + "hs=0; [ -e \"$s/$b\" ] && hs=1; "
            + "printf '1\\t%s\\t%s\\t%s\\t' \"$hs\" \"$(stat -c %Y \"$f\" 2>/dev/null)\" \"$f\"; "
            + "head -n 1 \"$f\" 2>/dev/null; echo; done; "
            + "for f in \"$s\"/*.txt; do [ -e \"$f\" ] || continue; b=${f##*/}; "
            + "[ -e \"$d/$b\" ] && continue; "
            + "printf '0\\t1\\t%s\\t%s\\t' \"$(stat -c %Y \"$f\" 2>/dev/null)\" \"$d/$b\"; "
            + "head -n 1 \"$f\" 2>/dev/null; echo; done"])
    }
    Process {
        id: notesProc
        property int seq: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (notesProc.seq !== svc.notesSeq) return   // relido no meio: ignora
                const out = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const ln = lines[i]
                    const p1 = ln.indexOf("\t"); if (p1 < 0) continue
                    const p2 = ln.indexOf("\t", p1 + 1); if (p2 < 0) continue
                    const p3 = ln.indexOf("\t", p2 + 1); if (p3 < 0) continue
                    const p4 = ln.indexOf("\t", p3 + 1); if (p4 < 0) continue
                    const first = ln.substring(p4 + 1).trim()
                    out.push({
                        saved: ln.substring(0, p1) === "1",
                        hasSketch: ln.substring(p1 + 1, p2) === "1",
                        mtime: parseInt(ln.substring(p2 + 1, p3)) || 0,
                        path: ln.substring(p3 + 1, p4),
                        name: first !== "" ? first : "(sem título)"
                    })
                }
                out.sort((x, y) => y.mtime - x.mtime)
                svc.notes = out
            }
        }
    }

    // ── Estado do editor embutido (a LauncherWindow observa) ──
    property bool   editorOpen: false
    property string editorPath: ""       // caminho canônico do .txt
    property string editorLoaded: ""     // texto a colocar no editor ao abrir
    property string editorInitial: ""    // referência p/ detectar alteração
    property bool   editorIsNew: false   // nota que ainda não foi salva nenhuma vez
    property string sketchReviewPath: "" // != "" → janela mostra a tela de revisão
    property string sketchReviewName: ""
    property string sketchReviewText: ""

    function _openEditor(path, content, isNew) {
        editorPath = path
        editorIsNew = isNew
        editorLoaded = content
        editorInitial = content
        sketchReviewPath = ""
        sketchReviewName = ""
        sketchReviewText = ""
        editorOpen = true
    }
    function closeEditor() {
        editorOpen = false
        editorPath = ""
        editorLoaded = ""
        editorInitial = ""
        editorIsNew = false
    }

    // "Criar nota": abre o editor vazio (com a 1ª linha = título digitado, se houver)
    function newNote(title) {
        const t = ("" + (title ?? "")).trim()
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss")
        _openEditor(Config.launcherNotesDir + "/nota-" + stamp + ".txt",
                    t !== "" ? t + "\n" : "", true)
    }
    // abre uma nota salva (lê o .txt)
    function editNote(path) {
        editorPath = path
        noteCat.mode = "note"
        noteCat.exec(["cat", "--", path])
    }
    // tela de revisão: há um rascunho não salvo p/ esta nota
    function reviewSketch(path) {
        const e = (notes || []).find(n => n.path === path)
        sketchReviewName = e ? e.name : firstLineOf(path)
        sketchReviewPath = path
        noteCat.mode = "review"
        noteCat.exec(["cat", "--", sketchPathFor(path)])
    }
    function keepSketch() {          // "Manter rascunho" → edita a partir do rascunho
        editorPath = sketchReviewPath
        noteCat.mode = "sketch"
        noteCat.exec(["cat", "--", sketchPathFor(sketchReviewPath)])
    }
    function discardSketch() {       // "Descartar" → apaga o rascunho
        const p = sketchReviewPath
        _deleteFiles([sketchPathFor(p)])
        const e = (notes || []).find(n => n.path === p)
        sketchReviewPath = ""
        sketchReviewName = ""
        sketchReviewText = ""
        if (e && e.saved) editNote(p)     // abre a versão salva
        else notesRefresh.restart()       // rascunho órfão: some da lista
    }
    function cancelReview() {
        sketchReviewPath = ""
        sketchReviewName = ""
        sketchReviewText = ""
    }
    Process {
        id: noteCat
        property string mode: "note"     // note | sketch | review
        stdout: StdioCollector {
            onStreamFinished: {
                if (noteCat.mode === "review") svc.sketchReviewText = text
                else svc._openEditor(svc.editorPath, text, false)
            }
        }
    }

    // "Salvar": grava o .txt, apaga o rascunho, volta pra lista
    function saveEditor(content) {
        _writeFile(editorPath, content)
        _deleteFiles([sketchPathFor(editorPath)])
        editorInitial = content
        editorIsNew = false
        closeEditor()
        notesRefresh.restart()
    }
    // "Voltar" sem salvar:
    //   • nota nova ou alterada, com conteúdo → grava um RASCUNHO
    //   • nota existente esvaziada → descarta rascunho velho (não mexe no .txt salvo)
    //   • nota nova vazia / inalterada → nada (a nota nem passa a existir)
    function leaveEditor(content) {
        const empty = content.trim() === ""
        const changed = content !== editorInitial
        if (!empty && (editorIsNew || changed))
            _writeFile(sketchPathFor(editorPath), content)
        else if (changed)
            _deleteFiles([sketchPathFor(editorPath)])
        closeEditor()
        notesRefresh.restart()
    }

    function deleteNote(path) {
        _deleteFiles([path, sketchPathFor(path)])
        notesRefresh.restart()
    }

    // grava `content` (UTF-8, com quebras de linha) em `path`, criando a pasta
    function _writeFile(path, content) {
        const dir = path.substring(0, path.lastIndexOf("/"))
        fileWriteProc.exec(["sh", "-c",
            "mkdir -p " + shq(dir) + " && printf '%s' " + shq(content) + " > " + shq(path)])
    }
    function _deleteFiles(paths) {
        fileDelProc.exec(["rm", "-f", "--"].concat(paths))
    }
    Process { id: fileWriteProc }
    Process { id: fileDelProc }
    Timer { id: notesRefresh; interval: 250; onTriggered: svc.refreshNotes() }

    // ═════════════════════════ Ações /reload, /config e /lock ═════════════════════════
    function reloadShell() { hide(); Quickshell.reload(false) }   // false = soft (reusa janelas)
    function openConfig()  { hide(); Settings.open = true }       // mesma pasta: sem import

    // bloqueia a tela na hora com o gtklock — mesmo guard `pidof` do session.sh (evita
    // 2ª instância se já estiver bloqueado). App gráfico Wayland → precisa do spawn()
    // pelo compositor (ver CLAUDE.md).
    function lock() {
        hide()
        spawn("pidof gtklock || gtklock")
    }

    // ═════════════════════════ Ações /reboot e /poweroff ═════════════════════════
    // Roda o comando de mesmo nome dentro do terminal configurado (Config.launcherTerminal -e
    // <cmd>) — mesmo padrão do Terminal=true dos .desktop em launchApp(). Assim, se pedir senha
    // (polkit/PAM) ou falhar, o terminal fica aberto mostrando a saída em vez de falhar em silêncio.
    function runInLauncherTerminal(cmd) {
        hide()
        spawn("exec " + shq(Config.launcherTerminal) + " -e " + cmd)
    }
    function reboot()   { runInLauncherTerminal("reboot") }
    function poweroff() { runInLauncherTerminal("poweroff") }

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
