pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"   // Config (raiz)

// Serviço de sensores (singleton): temperatura da CPU e da GPU via /sys/class/hwmon —
// não depende do lm-sensors (pacote não instalado). Nomes de driver confirmados ao vivo
// nesta máquina (`cat /sys/class/hwmon/hwmon*/name`): "k10temp" (CPU, temp1 = Tctl) e
// "amdgpu" (GPU, temp1 = edge). Ajuste o `case` abaixo se trocar de CPU/GPU. Também lê
// uso de RAM (/proc/meminfo), uso de CPU (amostra dupla de /proc/stat, mesma técnica do
// `top`) e uso de VRAM da GPU (/sys/class/drm/card0/device/mem_info_vram_*, exclusivo
// do driver amdgpu — arquivo ausente é ignorado, vramUsage fica em "—").
Singleton {
    id: svc
    property string cpuTemp: "—"
    property string gpuTemp: "—"
    property string ramUsage: "—"
    property string cpuUsage: "—"
    property string vramUsage: "—"

    property real _cpuStatTotal: 0
    property real _cpuStatIdle: 0

    function refresh() {
        proc.exec(["sh", "-c",
            "for d in /sys/class/hwmon/*; do n=$(cat $d/name 2>/dev/null); case $n in " +
            "k10temp) t=$(cat $d/temp1_input); echo CPU:$((t/1000));; " +
            "amdgpu) t=$(cat $d/temp1_input); echo GPU:$((t/1000));; esac; done; " +
            "awk '/^cpu /{print \"CSTAT1:\" $2+$3+$4+$5+$6+$7+$8, $5+$6}' /proc/stat; " +
            "sleep 0.2; " +
            "awk '/^cpu /{print \"CSTAT2:\" $2+$3+$4+$5+$6+$7+$8, $5+$6}' /proc/stat; " +
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print \"MEM:\" t-a, t}' /proc/meminfo; " +
            "v=/sys/class/drm/card0/device/mem_info_vram_used; " +
            "vt=/sys/class/drm/card0/device/mem_info_vram_total; " +
            "[ -f \"$v\" ] && echo VRAM:$(cat $v) $(cat $vt)"])
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: l => {
                const s = (l || "").trim()
                let m
                if ((m = s.match(/^(CPU|GPU):(-?\d+)$/))) {
                    const val = m[2] + "°C"
                    if (m[1] === "CPU") svc.cpuTemp = val
                    else svc.gpuTemp = val
                } else if ((m = s.match(/^MEM:(\d+) (\d+)$/))) {
                    const total = parseInt(m[2])
                    if (total > 0) svc.ramUsage = Math.round(parseInt(m[1]) / total * 100) + "%"
                } else if ((m = s.match(/^VRAM:(\d+) (\d+)$/))) {
                    const total = parseInt(m[2])
                    if (total > 0) svc.vramUsage = Math.round(parseInt(m[1]) / total * 100) + "%"
                } else if ((m = s.match(/^CSTAT1:(\d+) (\d+)$/))) {
                    svc._cpuStatTotal = parseInt(m[1])
                    svc._cpuStatIdle = parseInt(m[2])
                } else if ((m = s.match(/^CSTAT2:(\d+) (\d+)$/))) {
                    const dt = parseInt(m[1]) - svc._cpuStatTotal
                    const di = parseInt(m[2]) - svc._cpuStatIdle
                    if (dt > 0) svc.cpuUsage = Math.round((dt - di) * 100 / dt) + "%"
                }
            }
        }
    }

    Timer {
        interval: Config.sensorsInterval
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: svc.refresh()
    }
}
