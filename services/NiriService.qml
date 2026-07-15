import Quickshell
import Quickshell.Io
import QtQuick

// Serviço singleton: monitora o estado do Niri via `niri msg --json event-stream`.
// Reconstrói a lista de monitores (cada um com seus workspaces como "tags") no
// formato que a bola/anel de pontos consome:
//   { name, active, tags: [{ index, id, is_active, is_urgent, client_count }] }
// `active` = monitor focado; `index` = idx do workspace (1-based, por monitor).
Scope {
    id: root

    // ── Estado cru vindo do event-stream ──
    // workspaces: [{ id, idx, name, output, is_active, is_focused, is_urgent, ... }]
    property var workspaces: []
    // janela id -> workspace_id (p/ contar janelas por workspace = client_count)
    property var windowWs: ({})

    // Lista derivada por monitor (ver formato no topo). Reatribuída inteira a cada
    // evento p/ os bindings que a leem reavaliarem.
    property var monitors: []

    // Procura os dados de um monitor pelo nome (ex: "DP-2"); retorna null se não achar.
    function monitorByName(name) {
        const list = root.monitors ?? []
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name) return list[i]
        return null
    }

    // Reconstrói `monitors` a partir de workspaces + windowWs.
    function rebuild() {
        const counts = {}
        for (const wid in windowWs) {
            const ws = windowWs[wid]
            counts[ws] = (counts[ws] ?? 0) + 1
        }
        const byOut = {}
        const list = workspaces ?? []
        for (let i = 0; i < list.length; i++) {
            const w = list[i]
            const out = w.output ?? "?"
            if (!byOut[out]) byOut[out] = { name: out, active: false, tags: [] }
            byOut[out].tags.push({
                index: w.idx,
                id: w.id,
                is_active: w.is_active === true,
                is_urgent: w.is_urgent === true,
                client_count: counts[w.id] ?? 0
            })
            if (w.is_focused) byOut[out].active = true
        }
        const mons = []
        for (const k in byOut) {
            byOut[k].tags.sort((a, b) => a.index - b.index)
            mons.push(byOut[k])
        }
        mons.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0))
        root.monitors = mons
    }

    // workspace `id` virou o ativo do seu monitor; se `focused`, o foco global foi p/ ele
    function onWorkspaceActivated(id, focused) {
        const list = workspaces ?? []
        let out = null
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id) { out = list[i].output; break }
        if (out === null) return
        for (let i = 0; i < list.length; i++) {
            const w = list[i]
            if (w.output === out) w.is_active = (w.id === id)
            if (focused) w.is_focused = (w.id === id)
        }
        rebuild()
    }

    // Fica assistindo mudanças em tempo real. Cada evento é um JSON por linha, com
    // UMA chave = o tipo (ex.: {"WorkspacesChanged":{"workspaces":[...]}}).
    Process {
        id: watchProc
        command: ["niri", "msg", "--json", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                let ev
                try { ev = JSON.parse(line) } catch (e) { return }   // linha parcial: ignora

                if (ev.WorkspacesChanged) {
                    root.workspaces = ev.WorkspacesChanged.workspaces ?? []
                    root.rebuild()
                } else if (ev.WorkspaceActivated) {
                    root.onWorkspaceActivated(ev.WorkspaceActivated.id, ev.WorkspaceActivated.focused === true)
                } else if (ev.WorkspaceUrgencyChanged) {
                    const list = root.workspaces ?? []
                    for (let i = 0; i < list.length; i++)
                        if (list[i].id === ev.WorkspaceUrgencyChanged.id)
                            list[i].is_urgent = ev.WorkspaceUrgencyChanged.urgent === true
                    root.rebuild()
                } else if (ev.WindowsChanged) {
                    const m = {}
                    const wins = ev.WindowsChanged.windows ?? []
                    for (let i = 0; i < wins.length; i++) m[wins[i].id] = wins[i].workspace_id
                    root.windowWs = m
                    root.rebuild()
                } else if (ev.WindowOpenedOrChanged) {
                    const w = ev.WindowOpenedOrChanged.window
                    if (w) { root.windowWs[w.id] = w.workspace_id; root.rebuild() }
                } else if (ev.WindowClosed) {
                    delete root.windowWs[ev.WindowClosed.id]
                    root.rebuild()
                }
                // demais eventos (foco de janela, teclado, overview…) não afetam a bola
            }
        }
    }

    // Se o processo morrer, reinicia após 2s (o stream manda o estado completo ao conectar)
    Timer {
        interval: 2000
        running: !watchProc.running
        onTriggered: watchProc.running = true
    }
}
