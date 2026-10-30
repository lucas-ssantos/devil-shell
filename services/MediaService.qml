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

    // Player dedicado do popup: a aba do YouTube Music tocando no Zen. O Zen
    // (Firefox) publica a Media Session da aba como MPRIS (Identity "Mozilla zen",
    // URL da faixa em xesam:url). Filtramos pela URL para não pegar um vídeo comum
    // do YouTube que esteja tocando em outra aba do mesmo navegador.
    function isYtmPlayer(p) {
        if (!p) return false
        const identity = (p.identity || "").toLowerCase()
        const dbusName = (p.dbusName || "").toLowerCase()
        const isBrowser = identity.indexOf("zen") >= 0 || identity.indexOf("firefox") >= 0
            || dbusName.indexOf("org.mpris.mediaplayer2.firefox.") === 0
        if (!isBrowser) return false
        const url = p.metadata ? (p.metadata["xesam:url"] || "") : ""
        return String(url).indexOf("music.youtube.com") >= 0
    }
    readonly property var ytmPlayer: {
        const ps = Mpris.players.values
        let fallback = null
        for (let i = 0; i < ps.length; i++) {
            if (!svc.isYtmPlayer(ps[i])) continue
            if (ps[i].isPlaying) return ps[i]
            if (!fallback) fallback = ps[i]
        }
        return fallback
    }

    readonly property bool hasMedia: player !== null
    readonly property bool playing:  player ? player.isPlaying : false
    readonly property string title:  player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    property bool ytmLaunching: false
    property string ytmLaunchError: ""
    property int ytmLaunchAttempts: 0

    // texto exibido na cápsula: "Título — Artista" (ou só o que houver)
    readonly property string label: {
        if (!player) return ""
        if (title && artist) return title + " — " + artist
        return title || artist || "Tocando"
    }

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function ytmToggle() { if (ytmPlayer && ytmPlayer.canTogglePlaying) ytmPlayer.togglePlaying() }
    function ytmPrevious() { if (ytmPlayer && ytmPlayer.canGoPrevious) ytmPlayer.previous() }
    function ytmNext() { if (ytmPlayer && ytmPlayer.canGoNext) ytmPlayer.next() }

    // Abre (ou foca) o YouTube Music no Zen Flatpak. O player MPRIS do navegador
    // só aparece quando a aba tem uma Media Session — em geral depois do play.
    function startYtm() {
        if (ytmPlayer || ytmLaunching) return
        ytmLaunchError = ""
        ytmLaunchAttempts = 0
        ytmLaunching = true
        launchProc.exec([
            "niri", "msg", "action", "spawn-sh", "--",
            "if command -v flatpak >/dev/null 2>&1; then exec flatpak run app.zen_browser.zen 'https://music.youtube.com'; else exec xdg-open 'https://music.youtube.com'; fi"
        ])
        launchTimer.start()
    }

    Process { id: launchProc }
    Timer {
        id: launchTimer
        interval: 500
        repeat: true
        onTriggered: {
            if (svc.ytmPlayer) {
                svc.ytmLaunching = false
                stop()
            } else if (++svc.ytmLaunchAttempts >= 40) {
                svc.ytmLaunching = false
                svc.ytmLaunchError = "YouTube Music não apareceu. Abra o YTM no Zen e dê play."
                console.warn("YouTube Music não disponibilizou MPRIS após 20 segundos.")
                stop()
            }
        }
    }
}
