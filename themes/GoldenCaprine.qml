pragma Singleton
import Quickshell
import QtQuick

// Paleta "Golden Caprine" — fundo ardósia-violeta (#424153) + cinzas neutros + dourado-creme
// (#e7d8b1) de acento, tema ESCURO. MESMOS nomes da CrimsonDevil/InfernalRose/DragonBlanc,
// para ser intercambiável: o Theme.qml pode apontar o shell e/ou o CAVA para esta paleta
// sem mudar o Config.qml.
// Escala (tema escuro, como CrimsonDevil/InfernalRose): crust→surface2 vai do mais escuro ao
// mais claro; overlay0→text vai do meio-tom ao mais claro (text = branco).
// Cores-base fornecidas:
//   #424153 fundo  ·  #999999 base  ·  #e7d8b1 acento/destaques  ·  #cccccc base2  ·  #ffffff base3/highlights
// As demais (superfícies intermediárias, vermelho de erro, tons frios) são derivadas para
// harmonizar com essas cinco.
Singleton {
    id: palette

    readonly property bool isLight: false

    // ── Base / superfícies (do mais escuro ao mais claro — bola/painéis/kitty bg) ──
    readonly property color crust:     "#2b2a38"   // mais escuro (bola, fundo do kitty)
    readonly property color mantle:    "#363545"   // view/headerbar/sidebar
    readonly property color base:      "#424153"   // FUNDO principal (notif/tray/cápsula)
    readonly property color surface0:  "#4e4d61"   // superfície (slider, pílula, bordas)
    readonly property color surface1:  "#5a596f"   // ponto vazio, hover
    readonly property color surface2:  "#686780"

    // ── Overlays / textos (do meio-tom ao mais claro) ──
    readonly property color overlay0:  "#7d7c8e"
    readonly property color overlay1:  "#8c8b9a"
    readonly property color overlay2:  "#999999"   // BASE cinza
    readonly property color subtext0:  "#b3b3b3"
    readonly property color subtext1:  "#cccccc"   // BASE2
    readonly property color text:      "#ffffff"   // BASE3 (texto principal)

    // ── Acentos (família dourado-creme + tons suaves harmonizados) ──
    readonly property color rosewater: "#f6efe0"   // brilho claro (ícones sobre o cristal escuro)
    readonly property color flamingo:  "#eadcc8"
    readonly property color pink:      "#d9b8bc"
    readonly property color mauve:     "#e7d8b1"   // ACENTO (dourado-creme)
    readonly property color red:       "#e7d8b1"   // vermelho suave (urgente/erro/mute/rec)
    readonly property color maroon:    "#a8956a"   // dourado queimado (cristal, ocupado)
    readonly property color peach:     "#e3b974"   // âmbar (urgente/chama, distinto do acento)
    readonly property color yellow:    "#d4bc6e"   // ouro mais vivo
    readonly property color green:     "#e7d8b1"   // sem verde no tema → acento (compat. de nome)
    readonly property color teal:      "#a9b8a4"
    readonly property color sky:       "#a8b4c4"
    readonly property color sapphire:  "#919cba"
    readonly property color blue:      "#8b90b8"
    readonly property color lavender:  "#b6b2d2"

    // ── Extras ──
    readonly property color dimGreen:  "#4a495c"   // (antigo "verde apagado" → sigilo sutil, quase a cor da bola)
    readonly property color shadow:    "#1a1923"   // sombra (barra Draco)

    // ── Espectro do visualizador CAVA (interno → meio → pontas) ──
    readonly property color cavaInner: "#a8956a"   // dourado queimado
    readonly property color cavaMid:   "#e7d8b1"   // dourado-creme (acento)
    readonly property color cavaTip:   "#ffffff"   // branco
}
