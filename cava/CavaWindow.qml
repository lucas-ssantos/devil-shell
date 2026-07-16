import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/"   // Config (raiz); CavaBars está na mesma pasta (cava)

// Janela do CAVA na camada de BAIXO (fica atrás das janelas dos apps).
// Totalmente click-through; só desenha as barras lineares.
//
// Exibição conforme as janelas do workspace ativo (Config.cavaVisibility):
//   "sempre"     — comportamento clássico, desenha mesmo tampado (custo à toa)
//   "vazio"      — só desenha com o workspace sem janela nenhuma
//   "adaptativo" — some onde está COMPROVADAMENTE tampado: janela inteira quando as
//                  colunas do layout enchem a tela; recorte parcial só p/ flutuantes
//                  (o IPC do niri não dá a posição em tela dos tiles, ver NiriService)
PanelWindow {
    id: cavaWin
    property var modelData
    property var levels: []
    property var niri: null

    // janelas do workspace ativo DESTE monitor (nome da screen = nome do output no niri)
    readonly property var activeWins: {
        if (!niri || !modelData) return []
        const m = niri.winsByOutput
        return (m && m[modelData.name]) ? m[modelData.name] : []
    }

    // tela cheia? soma das larguras das COLUNAS (tiles empilhados contam 1x) já
    // enche a tela -> o view rolável está 100% tampado (sobram só os gaps).
    // ⚠️ usar a largura da SCREEN, não da janela: esconder a janela desmapeia e zera
    // o width dela -> binding loop
    readonly property bool fullyCovered: {
        const wins = cavaWin.activeWins
        const W = (modelData && modelData.width > 0) ? modelData.width : 1
        const cols = {}
        for (let i = 0; i < wins.length; i++) {
            const wi = wins[i]
            if (wi.floating) continue
            cols[wi.col] = Math.max(cols[wi.col] ?? 0, wi.w)
        }
        let sum = 0
        for (const k in cols) sum += cols[k]
        return sum >= W * Config.cavaCoverFrac
    }

    // intervalos x [ini, fim] tampados por janelas FLUTUANTES (rect exato do niri):
    // só vale se a janela cobre a faixa da onda inteira (do topo da onda ao fundo)
    readonly property var holes: {
        const wins = cavaWin.activeWins
        const out = []
        const screenH = (modelData && modelData.height) ? modelData.height : 0
        const bandTop = screenH - Config.cavaMaxH
        for (let i = 0; i < wins.length; i++) {
            const wi = wins[i]
            if (!wi.floating || wi.x === null) continue
            if (wi.y > bandTop || wi.y + wi.h < screenH - 4) continue
            out.push([wi.x, wi.x + wi.w])
        }
        return out
    }

    visible: {
        const mode = Config.cavaVisibility
        if (mode === "sempre") return true
        if (mode === "vazio") return activeWins.length === 0
        return !fullyCovered                              // "adaptativo"
    }

    screen: modelData
    WlrLayershell.layer: WlrLayer.Bottom
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    exclusiveZone: 0
    implicitHeight: Config.cavaHeight
    mask: Region {}   // sem área de input -> totalmente click-through

    CavaBars {
        visible: cavaWin.visible   // janela oculta -> nem repinta o Canvas
        levels: cavaWin.levels
        holes: cavaWin.holes
        ballCX: cavaWin.width / 2
        ballRadius: Config.ballRadius
        maxH: Config.cavaMaxH
    }
}
