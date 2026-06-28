pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"   // Config (raiz)

// Serviço de clima (singleton): pega a temperatura do wttr.in periodicamente.
// O local vem de Config.weatherLocation (vazio = auto por IP). Requer `curl` e rede.
Singleton {
    id: svc
    property string temp: "—"

    function refresh() {
        proc.exec(["sh", "-c",
            "curl -s --max-time 10 \"https://wttr.in/" + Config.weatherLocation + "?format=%t\""])
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: l => {
                const t = (l || "").trim()
                // ignora respostas de erro (ex.: "Unknown location")
                if (t.length > 0 && t.length < 12 && t.toLowerCase().indexOf("unknown") < 0)
                    svc.temp = t
            }
        }
    }

    Timer {
        interval: Config.weatherInterval
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: svc.refresh()
    }
}
