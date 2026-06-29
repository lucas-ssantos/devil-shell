pragma Singleton
import Quickshell
import QtQuick
import "root:/services"   // Settings (escolha de paleta + overrides de cor crua)

// SELETOR DE TEMA. As paletas cruas (hex) ficam em arquivos próprios, cada uma com o
// MESMO conjunto de nomes: CrimsonDevil.qml e InfernalRose.qml. Aqui se escolhe qual
// paleta vai para cada parte do shell:
//   • shell → tema do shell inteiro (bola, pétalas, menus, notificações, cápsulas…)
//   • cava  → tema do visualizador CAVA (barras/ondas e círculo); pode ser diferente.
//
// A escolha agora vem do Settings (janela de configurações): Settings.themeShell /
// themeCava. Cada cor crua pode ainda ser sobrescrita individualmente por um override
// "pal_<nome>" (ex.: pal_crust). Sem override, vale a cor da paleta escolhida. O
// Config.qml e os componentes seguem usando Theme.<cor> / Theme.cava* sem mudança.
Singleton {
    id: theme

    // ── Registro de paletas disponíveis (nome -> singleton) ──
    readonly property var palettes: ({ "CrimsonDevil": CrimsonDevil, "InfernalRose": InfernalRose })
    readonly property var paletteNames: ["CrimsonDevil", "InfernalRose"]

    // ── Escolha das paletas (persistida pelo Settings; padrão = visual atual) ──
    readonly property string shellName: Settings.get("themeShell", "CrimsonDevil")
    readonly property string cavaName:  Settings.get("themeCava",  "InfernalRose")
    readonly property var shell: palettes[shellName] ?? CrimsonDevil
    readonly property var cava:  palettes[cavaName]  ?? InfernalRose

    // helper: cor crua da paleta do shell, com override individual "pal_<nome>"
    function pal(name, fallback) { return Settings.get("pal_" + name, fallback) }

    // ── Re-exporta as cores do tema do SHELL como Theme.<cor> ──
    readonly property color crust:     pal("crust",     shell.crust)
    readonly property color mantle:    pal("mantle",    shell.mantle)
    readonly property color base:      pal("base",      shell.base)
    readonly property color surface0:  pal("surface0",  shell.surface0)
    readonly property color surface1:  pal("surface1",  shell.surface1)
    readonly property color surface2:  pal("surface2",  shell.surface2)
    readonly property color overlay0:  pal("overlay0",  shell.overlay0)
    readonly property color overlay1:  pal("overlay1",  shell.overlay1)
    readonly property color overlay2:  pal("overlay2",  shell.overlay2)
    readonly property color subtext0:  pal("subtext0",  shell.subtext0)
    readonly property color subtext1:  pal("subtext1",  shell.subtext1)
    readonly property color text:      pal("text",      shell.text)
    readonly property color rosewater: pal("rosewater", shell.rosewater)
    readonly property color flamingo:  pal("flamingo",  shell.flamingo)
    readonly property color pink:      pal("pink",      shell.pink)
    readonly property color mauve:     pal("mauve",     shell.mauve)
    readonly property color red:       pal("red",       shell.red)
    readonly property color maroon:    pal("maroon",    shell.maroon)
    readonly property color peach:     pal("peach",     shell.peach)
    readonly property color yellow:    pal("yellow",    shell.yellow)
    readonly property color green:     pal("green",     shell.green)
    readonly property color teal:      pal("teal",      shell.teal)
    readonly property color sky:       pal("sky",       shell.sky)
    readonly property color sapphire:  pal("sapphire",  shell.sapphire)
    readonly property color blue:      pal("blue",      shell.blue)
    readonly property color lavender:  pal("lavender",  shell.lavender)
    readonly property color dimGreen:  pal("dimGreen",  shell.dimGreen)

    // ── Espectro do CAVA (do tema 'cava', interno → meio → pontas) ──
    readonly property color cavaInner: pal("cavaInner", cava.cavaInner)
    readonly property color cavaMid:   pal("cavaMid",   cava.cavaMid)
    readonly property color cavaTip:   pal("cavaTip",   cava.cavaTip)
}
