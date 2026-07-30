pragma Singleton
import Quickshell
import QtQuick

// Paleta "Dragon Blanc" — fundo branco-névoa + borgonha + vermelho vivo + ouro,
// tema CLARO elegante (base Rosé Pine Dawn). MESMOS nomes da CrimsonDevil/InfernalRose,
// para ser intercambiável: o Theme.qml pode apontar o shell e/ou o CAVA para esta paleta
// sem mudar o Config.qml. ⚠️ Diferente das outras duas (temas ESCUROS, onde crust→surface2
// vai do mais escuro ao mais claro e overlay→text vai do mais claro ao mais escuro), aqui a
// escala é INVERTIDA: crust→surface2 vai do mais claro ao menos claro, overlay→text vai do
// meio-tom ao mais escuro. Isso importa pq crust/mantle/base não alimentam só a "bola" —
// o ThemeExport usa mantle/crust como fundo de painel (view/headerbar/sidebar/dialog do
// GTK, background do kitty…). Se crust/mantle ficassem escuros aqui (achando que "crust é
// sempre a cor da bola, então deve ser escura"), o texto escuro (`text`) sobreposto a esses
// painéis ficaria ilegível (texto escuro sobre fundo escuro) e o kitty ficaria com
// foreground == background — foi exatamente o bug reportado (diálogo do xdg-desktop-portal
// com fundo vermelho-escuro e texto quase invisível). `isLight` sinaliza o ThemeExport pra
// usar `prefer-dark-theme=0`/`color-scheme=prefer-light` em vez do padrão escuro.
Singleton {
    id: palette

    readonly property bool isLight: true

    // ── Base / superfícies (do mais claro ao menos claro — bola/painéis/kitty bg) ──
    readonly property color crust:     "#faf8fa"   // quase branco (bola, fundo do kitty)
    readonly property color mantle:    "#f5f3f5"   // branco-névoa (view/headerbar/sidebar)
    readonly property color base:      "#eeeaee"   // fundo principal (notif/tray/cápsula)
    readonly property color surface0:  "#e8e4e8"   // superfície (slider, pílula, bordas)
    readonly property color surface1:  "#ded4d8"   // ponto vazio, hover
    readonly property color surface2:  "#d0c0c8"

    // ── Overlays / textos (do meio-tom ao mais escuro) ──
    readonly property color overlay0:  "#c8b8c0"
    readonly property color overlay1:  "#b09aa4"
    readonly property color overlay2:  "#987e8a"
    readonly property color subtext0:  "#8a7880"
    readonly property color subtext1:  "#5c4850"
    readonly property color text:      "#2e1010"   // borgonha quase preto (texto principal)

    // ── Acentos (família borgonha/vermelho vivo + ouro) ──
    readonly property color rosewater: "#faf3ef"   // brilho claro (ícones sobre o cristal escuro)
    readonly property color flamingo:  "#eeddd8"
    readonly property color pink:      "#d8aab0"
    readonly property color mauve:     "#c0282e"   // ACENTO (vermelho vivo)
    readonly property color red:       "#dc333a"   // vermelho vivo claro (urgente/erro/mute/rec)
    readonly property color maroon:    "#7a1a24"   // borgonha escura (cristal, ocupado)
    readonly property color peach:     "#c89030"   // ouro (urgente/chama, p/ distinguir do vermelho)
    readonly property color yellow:    "#b8822e"   // ouro mais escuro (contraste c/ texto claro em cima)
    readonly property color green:     "#c0282e"   // sem verde no tema → vermelho (compat. de nome)
    readonly property color teal:      "#a05a58"
    readonly property color sky:       "#b06a62"
    readonly property color sapphire:  "#96444a"
    readonly property color blue:      "#8a3840"
    readonly property color lavender:  "#c49aa0"

    // ── Extras ──
    readonly property color dimGreen:  "#e8dcd8"   // (antigo "verde apagado" → sigilo sutil, quase a cor da bola)

    // ── Espectro do visualizador CAVA (interno → meio → pontas) ──
    readonly property color cavaInner: "#7a1a24"   // borgonha escura
    readonly property color cavaMid:   "#c0282e"   // vermelho vivo
    readonly property color cavaTip:   "#c89030"   // ouro
}
