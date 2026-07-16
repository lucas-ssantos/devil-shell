import Quickshell
import Quickshell.Io
import QtQuick

// Serviço do CAVA: roda o `cava` e expõe os níveis de áudio (0..1).
// Um só para todos os monitores.
Scope {
    id: svc
    property var levels: []
    // último frame recebido: frames idênticos (silêncio = zeros a 60fps) são descartados
    // ANTES do parse/reatribuição, senão todos os Canvas repintam à toa o tempo todo
    property string lastLine: ""

    Process {
        id: proc
        command: ["cava", "-p", "/home/luke/.config/quickshell/cava/cava.conf"]
        running: true
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

    // se o processo morrer, reinicia
    Timer { interval: 2000; running: !proc.running; onTriggered: proc.running = true }
}
