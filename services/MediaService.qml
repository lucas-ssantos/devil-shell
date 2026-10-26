pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Serviço de mídia (singleton) via MPRIS. Expõe o player "ativo" (o que está tocando,
// senão o primeiro) e seus dados, para a cápsula do topo mostrar o que toca.
Singleton {
    id: svc

    readonly property var player: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }
    readonly property var harvPlayer: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++)
            if ((ps[i].identity || "").toLowerCase() === "harv") return ps[i]
        return null
    }
    readonly property bool hasMedia: player !== null
    readonly property bool playing:  player ? player.isPlaying : false
    readonly property string title:  player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    property bool harvLaunching: false
    property string harvLaunchError: ""
    property int harvLaunchAttempts: 0

    // texto exibido na cápsula: "Título — Artista" (ou só o que houver)
    readonly property string label: {
        if (!player) return ""
        if (title && artist) return title + " — " + artist
        return title || artist || "Tocando"
    }

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function harvToggle() { if (harvPlayer && harvPlayer.canTogglePlaying) harvPlayer.togglePlaying() }
    function harvPrevious() { if (harvPlayer && harvPlayer.canGoPrevious) harvPlayer.previous() }
    function harvNext() { if (harvPlayer && harvPlayer.canGoNext) harvPlayer.next() }
    function startHarv() {
        if (harvPlayer || harvLaunching) return
        harvLaunchError = ""
        harvLaunchAttempts = 0
        harvLaunching = true
        launchProc.exec([
            "niri", "msg", "action", "spawn-sh", "--",
            "export PATH=\"$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$PATH\"; harv --background"
        ])
        launchTimer.start()
    }

    Process { id: launchProc }
    Timer {
        id: launchTimer
        interval: 500
        repeat: true
        onTriggered: {
            if (svc.harvPlayer) {
                svc.harvLaunching = false
                stop()
            } else if (++svc.harvLaunchAttempts >= 30) {
                svc.harvLaunching = false
                svc.harvLaunchError = "Harv não iniciou. Verifique se está instalado."
                console.warn("Harv não disponibilizou o MPRIS após 15 segundos.")
                stop()
            }
        }
    }
}
