pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"   // Config (raiz)

// Serviço de sensores (singleton): temperatura da CPU e da GPU via /sys/class/hwmon —
// não depende do lm-sensors (pacote não instalado). Nomes de driver confirmados ao vivo
// nesta máquina (`cat /sys/class/hwmon/hwmon*/name`): "k10temp" (CPU, temp1 = Tctl) e
// "amdgpu" (GPU, temp1 = edge). Ajuste o `case` abaixo se trocar de CPU/GPU.
Singleton {
    id: svc
    property string cpuTemp: "—"
    property string gpuTemp: "—"

    function refresh() {
        proc.exec(["sh", "-c",
            "for d in /sys/class/hwmon/*; do n=$(cat $d/name 2>/dev/null); case $n in " +
            "k10temp) t=$(cat $d/temp1_input); echo CPU:$((t/1000));; " +
            "amdgpu) t=$(cat $d/temp1_input); echo GPU:$((t/1000));; esac; done"])
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: l => {
                const m = (l || "").trim().match(/^(CPU|GPU):(-?\d+)$/)
                if (!m) return
                const val = m[2] + "°C"
                if (m[1] === "CPU") svc.cpuTemp = val
                else svc.gpuTemp = val
            }
        }
    }

    Timer {
        interval: Config.sensorsInterval
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: svc.refresh()
    }
}
