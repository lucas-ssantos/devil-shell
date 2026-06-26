pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire

// Serviço de áudio (singleton) via Pipewire. Expõe volume/mudo da saída (sink =
// headphone) e da entrada (source = microfone) e funções pra alterar.
Singleton {
    id: svc

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // mantém os nós "vivos" (necessário p/ ler/alterar audio.volume / muted)
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    // mantém todos os nós vivos p/ o seletor de dispositivos ler description/name/isSink
    PwObjectTracker { objects: Pipewire.nodes.values }

    readonly property real sinkVolume:   (sink && sink.audio)     ? sink.audio.volume   : 0
    readonly property bool sinkMuted:     (sink && sink.audio)     ? sink.audio.muted    : true
    readonly property real sourceVolume: (source && source.audio) ? source.audio.volume : 0
    readonly property bool sourceMuted:   (source && source.audio) ? source.audio.muted  : true

    function toggleSinkMute()   { if (sink && sink.audio)     sink.audio.muted   = !sink.audio.muted }
    function toggleSourceMute() { if (source && source.audio) source.audio.muted = !source.audio.muted }
    function addSinkVolume(d) {
        if (sink && sink.audio)
            sink.audio.volume = Math.max(0, Math.min(Config.sinkVolMax, sink.audio.volume + d))
    }
    function addSourceVolume(d) {
        if (source && source.audio)
            source.audio.volume = Math.max(0, Math.min(Config.sourceVolMax, source.audio.volume + d))
    }
}
