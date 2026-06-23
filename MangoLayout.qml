import Quickshell
import Quickshell.Io
import QtQuick

// Serviço singleton: monitora o layout do monitor focado via `mmsg watch all-monitors`
Scope {
    id: root

    property string currentLayout: "..."

    // Mapeia siglas → nomes legíveis
    readonly property var layoutNames: ({
        "T":  "Tiling",
        "CT": "Center Tiling",
        "RT": "Right Tiling",
        "VT": "Vertical Tiling",
        "S":  "Scrolling",
        "VS": "Vertical Scrolling",
        "M":  "Monocle",
        "K":  "Deck",
        "VK": "Vertical Deck",
        "G":  "Grid",
        "VG": "Vertical Grid",
        "DW": "Dwindle",
        "F":  "Fair",
        "VF": "Vertical Fair"
    })

    readonly property string displayName: layoutNames[currentLayout] ?? currentLayout

    // Fica assistindo mudanças em tempo real. Cada evento é um JSON por linha:
    // {"monitors":[{"name":"...","active":true,...,"layout_symbol":"T",...}, ...]}
    Process {
        id: watchProc
        command: ["mmsg", "watch", "all-monitors"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    const mons = data.monitors ?? []
                    // O monitor focado (active) define o layout exibido
                    const mon = mons.find(m => m.active) ?? mons[0]
                    if (mon && mon.layout_symbol)
                        root.currentLayout = mon.layout_symbol
                } catch (e) {
                    // linha parcial / não-JSON: ignora
                }
            }
        }
    }

    // Se o processo morrer, reinicia após 2s
    Timer {
        interval: 2000
        running: !watchProc.running
        onTriggered: watchProc.running = true
    }
}
