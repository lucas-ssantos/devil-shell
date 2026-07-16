pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Serviço de captura (singleton): gravação de tela.
//
// Gravação: gpu-screen-recorder gravando UM monitor inteiro (-w <saída>). Requer também: pgrep.
// Setup ÚNICO (o gsr-kms-server precisa de CAP_SYS_ADMIN; sem isso, e sem pkexec, a captura
// KMS falha na hora): `sudo setcap cap_sys_admin+ep /usr/bin/gsr-kms-server`.
// O gpu-screen-recorder é lançado pelo PRÓPRIO compositor via `niri msg action spawn-sh`
// (igual a um keybind), garantindo um ambiente Wayland correto p/ o processo filho.
//
// ⚠️ pgrep/pkill -x casam com o comm do kernel, truncado em 15 chars: "gpu-screen-reco"
// (o nome completo dá zero matches; -f é pior — casa com qualquer cmdline contendo o texto).
Singleton {
    id: svc
    property bool recording: false

    // pede ao niri para rodar `<script>` pela shell, no ambiente dele (Wayland OK).
    // Estende o PATH antes: ferramentas instaladas em ~/.cargo/bin / ~/.local/bin
    // podem não estar no PATH mínimo do compositor.
    function spawn(script) {
        const full = "export PATH=\"$HOME/.cargo/bin:$HOME/.local/bin:$PATH\"; " + script
        launchProc.exec(["niri", "msg", "action", "spawn-sh", "--", full])
    }

    // grava UM monitor inteiro (output = nome da saída, ex.: "DP-2"/"HDMI-A-1").
    // A "seleção da tela" é por onde se clica: cada monitor tem sua própria bola.
    function startRecording(output) {
        spawn("mkdir -p ~/Vídeos/Screencasts; " +
              "exec gpu-screen-recorder -w \"" + output + "\" -o ~/Vídeos/Screencasts/$(date +%Y%m%d)_$(date +%H%M%S).mp4")
    }
    function stopRecording() { spawn("pkill -INT -x gpu-screen-reco") }   // SIGINT finaliza e salva
    function toggleRecording(output) { if (recording) stopRecording(); else startRecording(output) }

    Process { id: launchProc }

    // ── sincroniza `recording` com a realidade (o recorder roda fora do quickshell) ──
    // fora da gravação basta um poll lento (cada tique lança sh+pgrep; 1s constante pesava)
    Timer {
        interval: svc.recording ? 1000 : 5000; running: true; repeat: true
        onTriggered: pollProc.exec(["sh", "-c", "pgrep -x gpu-screen-reco >/dev/null && echo 1 || echo 0"])
    }
    Process {
        id: pollProc
        stdout: SplitParser { onRead: l => svc.recording = (l.trim() === "1") }
    }
}
