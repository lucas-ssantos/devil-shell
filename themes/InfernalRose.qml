pragma Singleton
import Quickshell
import QtQuick

// Paleta "Infernal Rose" — preto roxo-escuro + vermelho rosado + estética ethereal
// (base Rosé Pine Moon). MESMOS nomes da CrimsonDevil, para ser intercambiável: o
// Theme.qml pode apontar o shell e/ou o CAVA para esta paleta sem mudar o Config.qml.
Singleton {
    id: palette

    // ── Base / superfícies (do mais escuro ao mais claro) ──
    readonly property color crust:     "#100b10"   // preto roxo-escuro
    readonly property color mantle:    "#160d18"
    readonly property color base:      "#1e1220"   // fundo principal
    readonly property color surface0:  "#2e1a2e"   // roxo-escuro (slider, pílula, bordas)
    readonly property color surface1:  "#3d2a3d"   // ponto vazio, hover
    readonly property color surface2:  "#4d384d"

    // ── Overlays / textos ──
    readonly property color overlay0:  "#6e5a6e"
    readonly property color overlay1:  "#86708a"
    readonly property color overlay2:  "#9d869d"
    readonly property color subtext0:  "#b89db0"
    readonly property color subtext1:  "#cabac4"
    readonly property color text:      "#ece0e8"   // branco-rosado (texto)

    // ── Acentos (família rosa/vermelho rosado) ──
    readonly property color rosewater: "#f0e0e8"   // brilho ethereal (mais claro)
    readonly property color flamingo:  "#e8c0d0"
    readonly property color pink:      "#d4a0b5"   // rosa claro
    readonly property color mauve:     "#c9456d"   // ACENTO (rosa principal)
    readonly property color red:       "#e05c7d"   // vermelho rosado vivo (urgente/erro/mute/rec)
    readonly property color maroon:    "#7a2040"   // rosa escuro (pétala, ocupado)
    readonly property color peach:     "#e88ca8"   // rosa-vivo claro (urgente, p/ distinguir)
    readonly property color yellow:    "#d9b08f"
    readonly property color green:     "#c9456d"   // sem verde no tema → rosa (compat. de nome)
    readonly property color teal:      "#b5566d"
    readonly property color sky:       "#c96a8a"
    readonly property color sapphire:  "#b34a6a"
    readonly property color blue:      "#a8456a"
    readonly property color lavender:  "#c4a0d0"   // lilás suave (toque roxo)

    // ── Extras ──
    readonly property color dimGreen:  "#5e2038"   // (antigo "verde apagado" → rosa escuro)

    // ── Espectro do visualizador CAVA (interno → meio → pontas) ──
    readonly property color cavaInner: "#7a2040"   // base interna (rosa escuro)
    readonly property color cavaMid:   "#c9456d"   // meio (rosa)
    readonly property color cavaTip:   "#f0e0e8"   // pontas (brilho ethereal)
}
