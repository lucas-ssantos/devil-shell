pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"           // Config (wallpaperDir, wallpaperMode, carrossel…)

// Papel de parede via awww/awww-daemon (singleton). Lógica NÃO-visual do modo /bg do lançador:
//   • lista as imagens da pasta Config.wallpaperDir (recursivo);
//   • aplica com `awww img` — em TODOS os monitores (sem -o) ou um wallpaper por monitor
//     (-o <output>), sempre reconciliando com o awww-daemon (que sobe pelo compositor,
//     ver CLAUDE.md — daemon é layer-shell, precisa de ambiente Wayland; já o cliente
//     `awww img`/`awww query` só fala com o socket do daemon e roda direto por Process);
//   • persiste a escolha no Settings ("wallpaperAll" / "wallpaperByOutput");
//   • carrossel opcional: troca aleatória periódica em TODOS os monitores (Config.wallpaperCarousel/…Min).
// O awww-daemon da sessão sobe daqui (init() no shell.qml) — um único daemon persistente
// (diferente do swaybg: aqui NÃO se relança processo a cada troca, só se manda um comando).
Singleton {
    id: svc

    // imagens encontradas na pasta (name = caminho relativo à pasta, path = absoluto)
    property var wallpapers: []

    // formatos que o awww desenha (raster + svg/gif estáticos; ver `man awww-img`)
    readonly property var exts: ["jpg","jpeg","png","gif","webp","bmp","tif","tiff","avif","jxl"]

    // escapa UMA string p/ dentro de aspas simples de shell (igual ao LauncherService)
    function shq(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'" }

    // mapeia o modo semântico persistido (herdado do swaybg -m) pro --resize do awww.
    // awww não tem "tile" (nem um equivalente) — cai em "no" (sem redimensionar/centralizado).
    function resizeMode(m) {
        switch (m) {
            case "fill": return "crop"
            case "fit": return "fit"
            case "stretch": return "stretch"
            case "center": return "no"
            default: return "crop"
        }
    }

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
        apply()
    }

    // ═════════════════════════ awww ═════════════════════════
    // "grow"/"outer" são radiais (círculo crescendo/encolhendo a partir de um ponto,
    // --transition-pos). Ancora esse ponto no centro-inferior da tela — onde a bola
    // do menu fica escondida (só o ballPeek some do chão) — pra a transição parecer
    // que nasce/volta pra ela. Os demais tipos (fade, wipe, wave…) não usam posição.
    function imgCmd(path, output) {
        const mode = resizeMode(Config.wallpaperMode)
        const type = Config.wallpaperTransition
        const out = output ? ("-o " + shq(output) + " ") : ""
        const pos = (type === "grow" || type === "outer") ? " --transition-pos bottom" : ""
        return "awww img " + out + "--resize " + mode + " --transition-type " + shq(type) + pos + " -- " + shq(path)
    }

    // um comando por override + um pra base (SEM -o = todos os outputs) aplicado ANTES,
    // senão sobrescreveria os overrides já postos
    function awwwScript() {
        const all = Settings.get("wallpaperAll", Config.wallpaperDefault)
        const by = Settings.get("wallpaperByOutput", ({}))
        const lines = [imgCmd(all, null)]
        for (const out in by) lines.push(imgCmd(by[out], out))
        return lines.join(" && ")
    }

    function apply() { runAwww(awwwScript()) }
    function runAwww(script) {
        spawnProc.exec(["sh", "-c", script])
    }
    Process { id: spawnProc }

    // garante que o awww-daemon da sessão está de pé. É um app gráfico Wayland
    // (layer-shell) então sobe pelo COMPOSITOR (niri spawn-sh, ver CLAUDE.md); a guarda
    // `pgrep` evita duplicar a cada (re)carga do quickshell.
    function ensureDaemon() {
        daemonProc.exec(["niri", "msg", "action", "spawn-sh", "--",
            "pgrep -x awww-daemon >/dev/null || { setsid awww-daemon >/dev/null 2>&1 & }"])
    }
    Process { id: daemonProc }

    // chamado pelo shell.qml (Component.onCompleted — roda no boot E a cada reload):
    // sobe o daemon se preciso e confere se o que o awww-daemon está exibindo em cada
    // output bate com a seleção persistida; só reaplica (awwwScript) se algo divergir
    // (evita reacender a transição do awww toda vez que um .qml é salvo em dev).
    // Com carrossel ligado a checagem é dispensada: o 1º tique já aplica uma imagem.
    function init() {
        ensureDaemon()
        refresh()
        if (!carouselOn) verify()
    }
    function verify() {
        // espera o socket do daemon ficar pronto (recém-spawnado) antes de consultar
        checkProc.exec(["sh", "-c",
            "for i in $(seq 1 50); do R=$(awww query --json 2>/dev/null) && [ -n \"$R\" ] && { printf '%s' \"$R\"; exit 0; }; sleep 0.1; done"])
    }
    Process {
        id: checkProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") return   // daemon nunca respondeu (ainda subindo / não instalado)
                let outs
                try { outs = JSON.parse(text)[""] } catch (e) { return }
                if (!outs) return
                for (const o of outs) {
                    const wanted = svc.currentFor(o.name)
                    if (!o.displaying || o.displaying.image !== wanted) { svc.apply(); return }
                }
            }
        }
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
            apply()                                  // restaura a seleção manual persistida
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
        runAwww(imgCmd(carouselCurrent, null))
    }
}
