pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// Serviço de mídia (singleton) via MPRIS. Expõe o player "ativo" (o que está tocando,
// senão o primeiro) e seus dados, para a cápsula do topo mostrar o que toca.
//
// O popup do YouTube Music usa a ponte local (YtmBridgeService) quando o userscript
// está conectado; sem ela, cai no MPRIS do Zen (que só expõe a Media Session ativa).
Singleton {
    id: svc

    readonly property var player: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }

    // Player MPRIS do YouTube Music no Zen. O navegador publica UMA Media Session
    // por instância (Identity "Mozilla zen", URL da faixa em xesam:url); filtramos
    // pela URL para não pegar um vídeo comum do YouTube na mesma aba/navegador.
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
    readonly property var ytmMprisPlayer: {
        const ps = Mpris.players.values
        let fallback = null
        for (let i = 0; i < ps.length; i++) {
            if (!svc.isYtmPlayer(ps[i])) continue
            if (ps[i].isPlaying) return ps[i]
            if (!fallback) fallback = ps[i]
        }
        return fallback
    }

    // Player sintético da ponte: mesmas propriedades que o popup usa no MprisPlayer,
    // mas alimentado pelo estado que o userscript publica em /state.
    readonly property QtObject ytmBridgePlayer: QtObject {
        readonly property bool isPlaying: YtmBridgeService.connected && !YtmBridgeService.paused
        readonly property bool canTogglePlaying: YtmBridgeService.available
        readonly property bool canGoNext: YtmBridgeService.connected && YtmBridgeService.hasTrack
        readonly property bool canGoPrevious: YtmBridgeService.connected && YtmBridgeService.hasTrack
        readonly property bool canSeek: YtmBridgeService.connected && YtmBridgeService.duration > 0
        readonly property bool volumeSupported: YtmBridgeService.connected
        readonly property real length: YtmBridgeService.duration
        readonly property real position: YtmBridgeService.position
        readonly property real volume: YtmBridgeService.volume
        readonly property string trackTitle: YtmBridgeService.connected ? YtmBridgeService.title : ""
        readonly property string trackArtist: YtmBridgeService.connected ? YtmBridgeService.artist : ""
        readonly property string trackArtUrl: YtmBridgeService.connected ? YtmBridgeService.artUrl : ""
        readonly property string identity: "YouTube Music (ponte)"
    }

    // Preferimos a ponte (controla a aba mesmo em segundo plano). Sem ela, o MPRIS.
    readonly property var ytmPlayer: {
        if (YtmBridgeService.connected) return ytmBridgePlayer
        if (ytmMprisPlayer) return ytmMprisPlayer
        if (YtmBridgeService.available) return ytmBridgePlayer
        return null
    }

    readonly property bool ytmBridgeConnected: YtmBridgeService.connected
    readonly property bool ytmBridgeAvailable: YtmBridgeService.available
    readonly property bool ytmHasTab: YtmBridgeService.hasYtmTab
    readonly property bool ytmNeedsUserscript: YtmBridgeService.available && YtmBridgeService.hasYtmTab
        && !YtmBridgeService.connected && !ytmMprisPlayer

    readonly property bool ytmCanToggle: ytmBridgeConnected
        || (ytmMprisPlayer && ytmMprisPlayer.canTogglePlaying)
        || YtmBridgeService.available || ytmHasTab
    readonly property bool ytmCanPrevious: !!((ytmBridgeConnected && YtmBridgeService.hasTrack)
        || (ytmMprisPlayer && ytmMprisPlayer.canGoPrevious))
    readonly property bool ytmCanNext: !!((ytmBridgeConnected && YtmBridgeService.hasTrack)
        || (ytmMprisPlayer && ytmMprisPlayer.canGoNext))
    readonly property bool ytmCanSeek: !!((ytmBridgeConnected && YtmBridgeService.duration > 0)
        || (ytmMprisPlayer && ytmMprisPlayer.canSeek))
    readonly property bool ytmVolumeSupported: !!(ytmBridgeConnected
        || (ytmMprisPlayer && ytmMprisPlayer.volumeSupported))

    readonly property string ytmStatusHint: {
        if (ytmBridgeConnected && !YtmBridgeService.hasTrack) return "Clique em play para iniciar"
        if (ytmNeedsUserscript) return "Instale o userscript — clique aqui"
        if (ytmLaunching) return "Abrindo YouTube Music…"
        if (ytmLaunchError) return ytmLaunchError
        return ""
    }

    readonly property bool hasMedia: player !== null
    readonly property bool playing:  player ? player.isPlaying : false
    readonly property string title:  player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    property bool ytmLaunching: false
    property string ytmLaunchError: ""
    property int ytmLaunchAttempts: 0
    property bool ytmPendingPlay: false
    property bool ytmStartWhenReady: false

    // texto exibido na cápsula: "Título — Artista" (ou só o que houver)
    readonly property string label: {
        if (!player) return ""
        if (title && artist) return title + " — " + artist
        return title || artist || "Tocando"
    }

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }

    // ── YouTube Music ────────────────────────────────────────────────────────

    function ytmTabKnown() {
        return YtmBridgeService.connected || YtmBridgeService.hasYtmTab || ytmMprisPlayer !== null
    }

    // Abre uma aba SÓ se não houver nenhuma do YTM. A detecção vem do session
    // store do Zen (servidor Python), então uma aba já aberta não é duplicada.
    function startYtmIfNeeded() {
        if (ytmTabKnown() || ytmLaunching) return
        if (!YtmBridgeService.ready) {
            ytmStartWhenReady = true
            return
        }
        startYtm()
    }

    function startYtm() {
        if (ytmTabKnown() || ytmLaunching) return
        ytmLaunchError = ""
        ytmLaunchAttempts = 0
        ytmLaunching = true
        launchProc.exec([
            "niri", "msg", "action", "spawn-sh", "--",
            "if command -v flatpak >/dev/null 2>&1; then exec flatpak run app.zen_browser.zen 'https://music.youtube.com'; else exec xdg-open 'https://music.youtube.com'; fi"
        ])
        launchTimer.start()
    }

    function finishPendingPlay() {
        if (!ytmPendingPlay) return
        if (YtmBridgeService.connected) {
            ytmPendingPlay = false
            YtmBridgeService.sendCommand("play")
        } else if (ytmMprisPlayer) {
            ytmPendingPlay = false
            if (ytmMprisPlayer.canTogglePlaying && !ytmMprisPlayer.isPlaying)
                ytmMprisPlayer.togglePlaying()
        }
    }

    function ytmToggle() {
        if (YtmBridgeService.connected) {
            YtmBridgeService.sendCommand("toggle")
            ytmLaunchError = ""
            return
        }
        if (ytmMprisPlayer) {
            if (ytmMprisPlayer.canTogglePlaying) ytmMprisPlayer.togglePlaying()
            return
        }
        if (YtmBridgeService.hasYtmTab) {
            // A aba existe, mas nem a ponte nem o MPRIS estão disponíveis: NÃO
            // abre outra aba; pede a instalação do userscript.
            ytmLaunchError = "Instale o userscript para controlar a aba do YouTube Music."
            return
        }
        ytmPendingPlay = true
        startYtmIfNeeded()
    }

    function ytmPrevious() {
        if (YtmBridgeService.connected) {
            YtmBridgeService.sendCommand("previous")
            return
        }
        if (ytmMprisPlayer && ytmMprisPlayer.canGoPrevious) ytmMprisPlayer.previous()
    }

    function ytmNext() {
        if (YtmBridgeService.connected) {
            YtmBridgeService.sendCommand("next")
            return
        }
        if (ytmMprisPlayer && ytmMprisPlayer.canGoNext) ytmMprisPlayer.next()
    }

    function ytmSeek(seconds) {
        if (YtmBridgeService.connected) {
            YtmBridgeService.sendCommand("seek", { position: seconds })
            return
        }
        if (ytmMprisPlayer && ytmMprisPlayer.canSeek) ytmMprisPlayer.position = seconds
    }

    function ytmSetVolume(value) {
        if (YtmBridgeService.connected) {
            YtmBridgeService.sendCommand("volume", { volume: value })
            return
        }
        if (ytmMprisPlayer && ytmMprisPlayer.volumeSupported) ytmMprisPlayer.volume = value
    }

    // Abre a página de instalação do userscript no Zen (Tampermonkey intercepta).
    function openYtmBridgeScript() {
        if (!YtmBridgeService.available) return
        const url = YtmBridgeService.baseUrl + "/ytm_bridge.user.js"
        scriptProc.exec([
            "niri", "msg", "action", "spawn-sh", "--",
            "if command -v flatpak >/dev/null 2>&1; then exec flatpak run app.zen_browser.zen '" + url + "'; else exec xdg-open '" + url + "'; fi"
        ])
    }

    Process { id: launchProc }
    Process { id: scriptProc }

    Timer {
        id: launchTimer
        interval: 500
        repeat: true
        onTriggered: {
            if (YtmBridgeService.connected || YtmBridgeService.hasYtmTab || ytmMprisPlayer) {
                svc.ytmLaunching = false
                stop()
                svc.finishPendingPlay()
            } else if (++svc.ytmLaunchAttempts >= 40) {
                svc.ytmLaunching = false
                svc.ytmLaunchError = "YouTube Music não conectou. Instale o userscript para controlar a aba."
                console.warn("YouTube Music não disponibilizou a ponte/MPRIS após 20 segundos.")
                stop()
            }
        }
    }

    Connections {
        target: YtmBridgeService
        function onConnectedChanged() {
            if (YtmBridgeService.connected) {
                svc.ytmLaunchError = ""
                svc.finishPendingPlay()
            }
        }
        function onReadyChanged() {
            if (YtmBridgeService.ready && svc.ytmStartWhenReady) {
                svc.ytmStartWhenReady = false
                svc.startYtmIfNeeded()
            }
        }
    }

    onYtmMprisPlayerChanged: {
        if (ytmMprisPlayer) {
            ytmLaunchError = ""
            finishPendingPlay()
        }
    }
}
