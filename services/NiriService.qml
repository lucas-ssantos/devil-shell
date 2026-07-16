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
    // janela id -> { ws, floating, col, w, h, x, y }. `col` = coluna no layout rolável;
    // x/y = posição no view do workspace, que o IPC do niri (26.04) SÓ informa para
    // janelas FLUTUANTES — nas janelas em tile vem null (limitação do compositor).
    property var windowInfo: ({})

    // Lista derivada por monitor (ver formato no topo). Reatribuída inteira a cada
    // evento p/ os bindings que a leem reavaliarem.
    property var monitors: []

    // Janelas do WORKSPACE ATIVO de cada output: { "DP-2": [{floating,col,w,h,x,y}], … }.
    // Separado de `monitors` de propósito: WindowLayoutsChanged dispara em rajada durante
    // redimensionamentos, e só o cava (cobertura da onda) precisa reavaliar nesses casos.
    property var winsByOutput: ({})

    // converte a janela do IPC p/ o registro interno (ver formato em windowInfo)
    function winFromIpc(w) {
        const ly = w.layout ?? {}
        const size = ly.tile_size ?? [0, 0]
        const pos = ly.tile_pos_in_workspace_view
        const col = ly.pos_in_scrolling_layout
        return {
            ws: w.workspace_id,
            floating: w.is_floating === true,
            col: col ? col[0] : 0,
            w: size[0], h: size[1],
            x: pos ? pos[0] : null,
            y: pos ? pos[1] : null
        }
    }

    // Reconstrói `winsByOutput` a partir de windowInfo + workspaces ativos.
    function rebuildWins() {
        const activeOut = {}   // workspace id -> output (só os ativos)
        const list = workspaces ?? []
        for (let i = 0; i < list.length; i++)
            if (list[i].is_active) activeOut[list[i].id] = list[i].output
        const m = {}
        for (const wid in windowInfo) {
            const wi = windowInfo[wid]
            const out = activeOut[wi.ws]
            if (out === undefined) continue
            if (!m[out]) m[out] = []
            m[out].push(wi)
        }
        root.winsByOutput = m
    }

    // Procura os dados de um monitor pelo nome (ex: "DP-2"); retorna null se não achar.
    function monitorByName(name) {
        const list = root.monitors ?? []
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name) return list[i]
        return null
    }

    // Reconstrói `monitors` (e `winsByOutput`) a partir de workspaces + windowInfo.
    function rebuild() {
        const counts = {}
        for (const wid in windowInfo) {
            const ws = windowInfo[wid].ws
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
        rebuildWins()   // o workspace ativo pode ter mudado -> as janelas visíveis também
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
                    for (let i = 0; i < wins.length; i++) m[wins[i].id] = root.winFromIpc(wins[i])
                    root.windowInfo = m
                    root.rebuild()
                } else if (ev.WindowOpenedOrChanged) {
                    const w = ev.WindowOpenedOrChanged.window
                    if (w) { root.windowInfo[w.id] = root.winFromIpc(w); root.rebuild() }
                } else if (ev.WindowClosed) {
                    delete root.windowInfo[ev.WindowClosed.id]
                    root.rebuild()
                } else if (ev.WindowLayoutsChanged) {
                    // rajadas durante resize/scroll: atualiza SÓ winsByOutput (não `monitors`,
                    // senão a bola/anel repintam à toa a cada frame de animação)
                    const chs = ev.WindowLayoutsChanged.changes ?? []
                    let dirty = false
                    for (let i = 0; i < chs.length; i++) {
                        const cur = root.windowInfo[chs[i][0]]
                        if (!cur) continue
                        const ly = chs[i][1] ?? {}
                        const size = ly.tile_size ?? [cur.w, cur.h]
                        const pos = ly.tile_pos_in_workspace_view
                        const col = ly.pos_in_scrolling_layout
                        cur.w = size[0]; cur.h = size[1]
                        cur.col = col ? col[0] : cur.col
                        cur.x = pos ? pos[0] : null
                        cur.y = pos ? pos[1] : null
                        dirty = true
                    }
                    if (dirty) root.rebuildWins()
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
