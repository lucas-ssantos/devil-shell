pragma Singleton
import Quickshell
import QtQuick

// Paleta "Crimson Devil" — vermelho intenso + preto profundo + cinza metálico.
// Base Catppuccin Mocha remapeada para os tons do tema, mantendo os MESMOS nomes
// (crust, base, surface0, text, red, mauve…) para o Config.qml mapear semântico → cor.
// Esta é uma das paletas; o Theme.qml escolhe qual fica ativa.
Singleton {
    id: palette

    // ── Base / superfícies (do mais escuro ao mais claro) ──
    readonly property color crust:     "#0d0d0d"   // preto profundo (bola)
    readonly property color mantle:    "#140606"
    readonly property color base:      "#1a0707"   // fundo principal (notif/tray/cápsula)
    readonly property color surface0:  "#2b1718"   // vermelho-grafite (slider, pílula, bordas)
    readonly property color surface1:  "#3d3d3d"   // cinza metálico (ponto vazio, hover)
    readonly property color surface2:  "#4d4848"

    // ── Overlays / textos ──
    readonly property color overlay0:  "#5e5a5a"
    readonly property color overlay1:  "#767070"
    readonly property color overlay2:  "#8e8888"
    readonly property color subtext0:  "#9a9696"
    readonly property color subtext1:  "#bcb8b8"
    readonly property color text:      "#c8c8c8"   // cinza claro (texto)

    // ── Acentos (família vermelha/quente) ──
    readonly property color rosewater: "#f0d8d4"
    readonly property color flamingo:  "#e8b8b0"
    readonly property color pink:      "#d56b7a"
    readonly property color mauve:     "#c0392b"   // ACENTO (vermelho médio)
    readonly property color red:       "#e74c3c"   // vermelho vivo (urgente/erro/mute/rec)
    readonly property color maroon:    "#8b1a1a"   // vermelho escuro (pétala, ocupado)
    readonly property color peach:     "#f0843c"   // laranja-chama (urgente, p/ distinguir do ativo)
    readonly property color yellow:    "#d9a441"
    readonly property color green:     "#c0392b"   // sem verde no tema → vermelho (compat. de nome)
    readonly property color teal:      "#b5564a"
    readonly property color sky:       "#c96a5c"
    readonly property color sapphire:  "#b34a3c"
    readonly property color blue:      "#a8453a"
    readonly property color lavender:  "#d56b6b"

    // ── Extras ──
    readonly property color dimGreen:  "#5e1414"   // (antigo "verde apagado" → vermelho escuro)

    // ── Espectro do visualizador CAVA (interno → meio → pontas) ──
    readonly property color cavaInner: "#8b1a1a"
    readonly property color cavaMid:   "#c0392b"
    readonly property color cavaTip:   "#e74c3c"
}
