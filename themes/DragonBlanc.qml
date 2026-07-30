pragma Singleton
import Quickshell
import QtQuick

// Paleta "Dragon Blanc" — fundo branco-névoa + borgonha + vermelho vivo + ouro,
// tema CLARO elegante (base Rosé Pine Dawn). MESMOS nomes da CrimsonDevil/InfernalRose,
// para ser intercambiável: o Theme.qml pode apontar o shell e/ou o CAVA para esta paleta
// sem mudar o Config.qml. Diferente das outras duas (temas escuros), aqui `base`/`surface*`
// ficam CLAROS (painéis com texto escuro) enquanto `crust`/`maroon` seguem escuros —
// a bola e os cristais continuam âncoras escuras sobre o fundo claro, como no mockup
// original (cápsula/bar-pill escura sobre painel claro).
Singleton {
    id: palette

    // ── Base / superfícies (do mais escuro ao mais claro) ──
    readonly property color crust:     "#2e1010"   // preto-borgonha profundo (bola)
    readonly property color mantle:    "#3d1518"
    readonly property color base:      "#f5f3f5"   // fundo principal claro (notif/tray/cápsula)
    readonly property color surface0:  "#e8e4e8"   // superfície clara (slider, pílula, bordas)
    readonly property color surface1:  "#ded4d8"   // ponto vazio, hover
    readonly property color surface2:  "#d0c0c8"

    // ── Overlays / textos ──
    readonly property color overlay0:  "#c8b8c0"
    readonly property color overlay1:  "#b09aa4"
    readonly property color overlay2:  "#987e8a"
    readonly property color subtext0:  "#8a7880"
    readonly property color subtext1:  "#5c4850"
    readonly property color text:      "#2e1010"   // borgonha quase preto (texto)

    // ── Acentos (família borgonha/vermelho vivo + ouro) ──
    readonly property color rosewater: "#faf3ef"   // brilho claro (ícones sobre o cristal escuro)
    readonly property color flamingo:  "#eeddd8"
    readonly property color pink:      "#d8aab0"
    readonly property color mauve:     "#c0282e"   // ACENTO (vermelho vivo)
    readonly property color red:       "#dc333a"   // vermelho vivo claro (urgente/erro/mute/rec)
    readonly property color maroon:    "#7a1a24"   // borgonha escura (cristal, ocupado)
    readonly property color peach:     "#c89030"   // ouro (urgente/chama, p/ distinguir do vermelho)
    readonly property color yellow:    "#d9ab52"
    readonly property color green:     "#c0282e"   // sem verde no tema → vermelho (compat. de nome)
    readonly property color teal:      "#a05a58"
    readonly property color sky:       "#b06a62"
    readonly property color sapphire:  "#96444a"
    readonly property color blue:      "#8a3840"
    readonly property color lavender:  "#c49aa0"

    // ── Extras ──
    readonly property color dimGreen:  "#48141a"   // (antigo "verde apagado" → borgonha bem escura)

    // ── Espectro do visualizador CAVA (interno → meio → pontas) ──
    readonly property color cavaInner: "#7a1a24"   // borgonha escura
    readonly property color cavaMid:   "#c0282e"   // vermelho vivo
    readonly property color cavaTip:   "#c89030"   // ouro
}
