import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"   // Config

// Serviço do CAVA: monta o "mix" de áudio, roda o `cava` e expõe os níveis (0..1).
// Um só para todos os monitores.
//
// MIX de várias saídas: o `cava` (libpulse) só escuta UM monitor. Para o visualizador
// reagir a TODOS os dispositivos de saída (não só ao sink padrão), criamos um null-sink
// `cava_mix` e um `pw-loopback` ligando o monitor de cada sink de Config.cavaMixSinks
// nele; o cava lê `cava_mix.monitor` (ver [input] em cava/cava.conf). Idempotente:
// guardas (`grep`/`pgrep`) evitam duplicar módulo/loopbacks a cada reload; `setsid`
// destaca os loopbacks p/ sobreviverem ao fim do processo / a um reload.
Scope {
    id: svc
    property var levels: []
    // último frame recebido: frames idênticos (silêncio = zeros a 60fps) são descartados
    // ANTES do parse/reatribuição, senão todos os Canvas repintam à toa o tempo todo
    property string lastLine: ""

    // 1) monta o null-sink `cava_mix` + um loopback por saída; só então libera o cava
    // (evita erro de "source inexistente" na 1ª carga). Nas recargas vira no-op.
    Process {
        id: mix
        running: true
        command: ["sh", "-c", svc.mixScript()]
        onExited: cavaGate.start()
    }

    function mixScript() {
        // nomes de sink do PipeWire: [A-Za-z0-9._-], sem espaços -> junta com espaço
        const sinks = (Config.cavaMixSinks || []).map(s => String(s)).join(" ")
        return [
            "pactl list short modules | grep -q sink_name=cava_mix || " +
                "pactl load-module module-null-sink sink_name=cava_mix " +
                "sink_properties=node.description=CAVA-Mix media.class=Audio/Sink >/dev/null",
            "SINKS=\"" + sinks + "\"",
            "[ -n \"$SINKS\" ] || SINKS=\"$(pactl get-default-sink)\"",
            "i=0",
            "for S in $SINKS; do",
            // só liga se o sink existir agora (evita o loopback grudar num fallback qualquer)
            "  pactl list short sinks | awk '{print $2}' | grep -qx \"$S\" || { i=$((i+1)); continue; }",
            "  pgrep -f \"pw-loopback -n cava-loop-$i \" >/dev/null || " +
                "setsid pw-loopback -n \"cava-loop-$i\" -P cava_mix -C \"$S\" " +
                "-i stream.capture.sink=true >/dev/null 2>&1 &",
            "  i=$((i+1))",
            "done"
        ].join("\n")
    }

    Timer { id: cavaGate; interval: 500; onTriggered: proc.running = true }

    Process {
        id: proc
        command: ["cava", "-p", "/home/luke/.config/quickshell/cava/cava.conf"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                if (line === svc.lastLine) return
                svc.lastLine = line
                const parts = line.split(";")
                const arr = []
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue
                    arr.push(parseInt(parts[i]) / 1000)
                }
                if (arr.length > 0) svc.levels = arr
            }
        }
    }

    // se o cava morrer (ou não achar o cava_mix na 1ª tentativa), reinicia
    Timer { interval: 2000; running: mix.exited && !proc.running; onTriggered: proc.running = true }
}
