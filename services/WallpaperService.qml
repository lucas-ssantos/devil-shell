pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"           // Config (wallpaperDir, wallpaperMode, carrossel…)

// Papel de parede via swaybg (singleton). Lógica NÃO-visual do modo /bg do lançador:
//   • lista as imagens da pasta Config.wallpaperDir (recursivo);
//   • aplica com swaybg — em TODOS os monitores ('*') ou um wallpaper por monitor
//     (-o <output>), sempre relançando pelo compositor (niri spawn-sh, ver CLAUDE.md);
//   • persiste a escolha no Settings ("wallpaperAll" / "wallpaperByOutput");
//   • carrossel opcional: troca aleatória periódica (Config.wallpaperCarousel/…Min).
// O swaybg da sessão sobe daqui (init() no shell.qml) — saiu do session.sh.
Singleton {
    id: svc

    // imagens encontradas na pasta (name = caminho relativo à pasta, path = absoluto)
    property var wallpapers: []

    // formatos que o swaybg desenha (raster; sem svg/ico)
    readonly property var exts: ["jpg","jpeg","png","gif","webp","bmp","tif","tiff","avif","jxl"]

    // escapa UMA string p/ dentro de aspas simples de shell (igual ao LauncherService)
    function shq(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'" }

    // ═════════════════════════ Seleção persistida ═════════════════════════
    // "wallpaperAll" = imagem de todos os monitores; "wallpaperByOutput" = overrides
    // por monitor ({ "DP-2": caminho }). Efetivo por monitor: override ?? all ?? padrão.
    function currentFor(target) {
        if (target !== "*") {
            const by = Settings.get("wallpaperByOutput", ({}))
            if (by[target] !== undefined) return by[target]
        }
        return Settings.get("wallpaperAll", Config.wallpaperDefault)
    }

    // aplica e persiste: target "*" (todos — limpa os por-monitor) ou o nome do output
    function setFor(target, path) {
        if (target === "*") {
            Settings.set("wallpaperAll", path)
            Settings.set("wallpaperByOutput", ({}))
        } else {
            const old = Settings.get("wallpaperByOutput", ({}))
            var by = {}
            for (var k in old) by[k] = old[k]
            by[target] = path
            Settings.set("wallpaperByOutput", by)
        }
        apply(false)
    }

    // ═════════════════════════ swaybg ═════════════════════════
    // linha completa: -i sem -o vale p/ todos; depois um -o por monitor com override
    function swaybgLine() {
        const m = Config.wallpaperMode
        let line = "swaybg -i " + shq(Settings.get("wallpaperAll", Config.wallpaperDefault)) + " -m " + shq(m)
        const by = Settings.get("wallpaperByOutput", ({}))
        for (const out in by)
            line += " -o " + shq(out) + " -i " + shq(by[out]) + " -m " + shq(m)
        return line
    }

    // relança o swaybg pelo compositor. guarded=true (boot/reload): só sobe se não
    // houver um rodando; guarded=false (troca): sobe o novo e SÓ DEPOIS mata o velho
    // (sem frame preto entre um e outro).
    function apply(guarded) { runSwaybg(swaybgLine(), guarded) }
    function runSwaybg(line, guarded) {
        const script = guarded
            ? "pgrep -x swaybg >/dev/null || { setsid " + line + " >/dev/null 2>&1 & }"
            : "OLD=$(pgrep -x swaybg); setsid " + line + " >/dev/null 2>&1 & sleep 0.3; [ -n \"$OLD\" ] && kill $OLD 2>/dev/null"
        spawnProc.exec(["niri", "msg", "action", "spawn-sh", "--", script])
    }
    Process { id: spawnProc }

    // chamado uma vez pelo shell.qml (Component.onCompleted): sobe o swaybg da sessão
    // com a última escolha persistida (guarda pgrep → reload não pisca o wallpaper)
    function init() {
        refresh()
        apply(true)
    }

    // ═════════════════════════ Lista de imagens ═════════════════════════
    readonly property string dir: Config.wallpaperDir
    onDirChanged: refresh()

    function refresh() {
        const clauses = exts.map(e => "-iname " + shq("*." + e)).join(" -o ")
        listProc.exec(["sh", "-c",
            "cd -- " + shq(dir) + " 2>/dev/null && find -L . -type f \\( " + clauses + " \\) -printf '%P\\n' 2>/dev/null | sort"])
    }
    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const rel = lines[i]
                    if (rel === "") continue
                    out.push({ name: rel, path: svc.dir + "/" + rel })
                }
                svc.wallpapers = out
                // carrossel ligado e ainda sem imagem sorteada -> troca já
                if (svc.carouselOn && svc.carouselCurrent === "") svc.carouselTick()
            }
        }
    }

    // ═════════════════════════ Carrossel ═════════════════════════
    // Troca aleatória periódica em TODOS os monitores. Não persiste cada troca (senão
    // o settings.json seria reescrito a cada tique); a seleção manual fica guardada
    // e volta quando o carrossel é desligado (próximo apply).
    readonly property bool carouselOn: Config.wallpaperCarousel
    property string carouselCurrent: ""
    onCarouselOnChanged: {
        if (carouselOn) {
            if (wallpapers.length === 0) refresh()   // onStreamFinished dispara o 1º tique
            else carouselTick()
        } else {
            carouselCurrent = ""
            apply(false)                             // restaura a seleção manual persistida
        }
    }
    Timer {
        running: svc.carouselOn && svc.wallpapers.length > 0
        interval: Math.max(1, Config.wallpaperCarouselMin) * 60000
        repeat: true
        onTriggered: svc.carouselTick()
    }
    function carouselTick() {
        const n = wallpapers.length
        if (n === 0) return
        let i = Math.floor(Math.random() * n)
        if (n > 1 && wallpapers[i].path === carouselCurrent) i = (i + 1) % n   // evita repetir
        carouselCurrent = wallpapers[i].path
        runSwaybg("swaybg -i " + shq(carouselCurrent) + " -m " + shq(Config.wallpaperMode), false)
    }
}
