pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Serviço de captura (singleton): screenshot e gravação de tela.
//
// IMPORTANTE: os comandos são lançados pelo PRÓPRIO compositor via `mmsg dispatch
// spawn` (igual a um keybind). Lançar pelo Process do quickshell NÃO funciona: o
// processo filho não herda um WAYLAND_DISPLAY válido e o slurp/wayfreeze nunca abrem
// (o mmsg funciona porque usa o socket do mango, não o Wayland). Já o que o mango
// mesmo spawna recebe o ambiente Wayland correto.
//
// Screenshot: script ~/.config/mango/printscreen_edit.sh (wayfreeze + slurp -d + swappy).
// Gravação:   wf-recorder gravando UM monitor inteiro (-o <saída>). Requer também: pgrep.
Singleton {
    id: svc
    property bool recording: false

    readonly property string shotScript: "~/.config/mango/printscreen_edit.sh"

    // pede ao mango para rodar `sh -c '<script>'` no ambiente dele (Wayland OK).
    // O PATH do mango é mínimo (não inclui ~/.cargo/bin nem ~/.local/bin), então
    // ferramentas instaladas ali (ex.: wayfreeze, via cargo) não seriam encontradas
    // e o script travaria. Por isso estendemos o PATH antes de rodar.
    function spawn(script) {
        const full = "export PATH=\"$HOME/.cargo/bin:$HOME/.local/bin:$PATH\"; " + script
        launchProc.exec(["mmsg", "dispatch", "spawn,sh -c '" + full + "'"])
    }

    function screenshot() { spawn(shotScript) }

    // grava UM monitor inteiro (output = nome da saída, ex.: "DP-2"/"HDMI-A-1").
    // A "seleção da tela" é por onde se clica: cada monitor tem sua própria bola.
    function startRecording(output) {
        spawn("mkdir -p ~/Videos/Screencasts; " +
              "exec wf-recorder -o \"" + output + "\" -f ~/Videos/Screencasts/$(date +%Y%m%d)_$(date %H%M%S).mp4")
    }
    function stopRecording() { spawn("pkill -INT -x wf-recorder") }   // SIGINT finaliza e salva
    function toggleRecording(output) { if (recording) stopRecording(); else startRecording(output) }

    Process { id: launchProc }

    // ── sincroniza `recording` com a realidade (wf-recorder roda fora do quickshell) ──
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: pollProc.exec(["sh", "-c", "pgrep -x wf-recorder >/dev/null && echo 1 || echo 0"])
    }
    Process {
        id: pollProc
        stdout: SplitParser { onRead: l => svc.recording = (l.trim() === "1") }
    }
}
