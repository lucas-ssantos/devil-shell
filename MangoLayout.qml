import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

// Serviço singleton: monitora o layout atual do MangoWM via mmsg -w -l
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
        "VG": "Vertical Grid"
    })

    readonly property string displayName: layoutNames[currentLayout] ?? currentLayout

    // Fica assistindo mudanças de layout em tempo real
    Process {
        id: watchProc
        command: ["mmsg", "-w", "-l"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                // mmsg -w -l emite linhas como: "layout T" ou só "T"
                const trimmed = data.trim()
                const parts = trimmed.split(/\s+/)
                const code = parts[parts.length - 1]
                if (code !== "") root.currentLayout = code
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
