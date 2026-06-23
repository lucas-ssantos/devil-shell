import Quickshell
import Quickshell.Io
import QtQuick

// Serviço singleton: monitora o estado do MangoWC via `mmsg watch all-monitors`.
// Expõe a lista crua de monitores (cada um com layout_symbol e tags) para a barra
// montar o indicador de layout e de áreas de trabalho por monitor.
Scope {
    id: root

    // Lista de monitores do último evento do mmsg. Cada item:
    // { name, active, layout_symbol, tags: [{ index, is_active, is_urgent, layout, client_count }] }
    property var monitors: []

    // Mapeia siglas de layout → nomes legíveis
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

    // Procura os dados de um monitor pelo nome (ex: "DP-2"); retorna null se não achar.
    // Ler root.monitors aqui faz os bindings que chamam esta função re-avaliarem
    // quando a lista muda.
    function monitorByName(name) {
        const list = root.monitors ?? []
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name) return list[i]
        return null
    }

    // Fica assistindo mudanças em tempo real. Cada evento é um JSON por linha:
    // {"monitors":[{"name":"...","active":true,...,"layout_symbol":"T","tags":[...]}, ...]}
    Process {
        id: watchProc
        command: ["mmsg", "watch", "all-monitors"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    root.monitors = data.monitors ?? []
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
