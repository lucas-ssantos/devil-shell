pragma Singleton
import Quickshell
import Quickshell.Services.Mpris

// Serviço de mídia (singleton) via MPRIS. Expõe o player "ativo" (o que está tocando,
// senão o primeiro) e seus dados, para a cápsula do topo mostrar o que toca.
Singleton {
    id: svc

    readonly property var player: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }
    readonly property bool hasMedia: player !== null
    readonly property bool playing:  player ? player.isPlaying : false
    readonly property string title:  player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""

    // texto exibido na cápsula: "Título — Artista" (ou só o que houver)
    readonly property string label: {
        if (!player) return ""
        if (title && artist) return title + " — " + artist
        return title || artist || "Tocando"
    }

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
}
