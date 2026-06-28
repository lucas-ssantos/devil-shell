pragma Singleton
import Quickshell
import QtQuick

// SELETOR DE TEMA. As paletas cruas (hex) ficam em arquivos próprios, cada uma com o
// MESMO conjunto de nomes: CrimsonDevil.qml e InfernalRose.qml. Aqui só se escolhe qual
// paleta vai para cada parte do shell:
//   • shell → tema do shell inteiro (bola, pétalas, menus, notificações, cápsulas…)
//   • cava  → tema do visualizador CAVA (barras/ondas e círculo); pode ser diferente.
// Trocar de tema = trocar a paleta apontada abaixo (uma linha). O Config.qml e os
// componentes seguem usando Theme.<cor> / Theme.cava* sem nenhuma mudança.
Singleton {
    id: theme

    // ── Escolha das paletas ─────────────────────────────
    readonly property var shell: CrimsonDevil    // ← troque por InfernalRose p/ o shell todo
    readonly property var cava:  InfernalRose     // ← tema do CAVA (independente do shell)

    // ── Re-exporta as cores do tema do SHELL como Theme.<cor> ──
    readonly property color crust:     shell.crust
    readonly property color mantle:    shell.mantle
    readonly property color base:      shell.base
    readonly property color surface0:  shell.surface0
    readonly property color surface1:  shell.surface1
    readonly property color surface2:  shell.surface2
    readonly property color overlay0:  shell.overlay0
    readonly property color overlay1:  shell.overlay1
    readonly property color overlay2:  shell.overlay2
    readonly property color subtext0:  shell.subtext0
    readonly property color subtext1:  shell.subtext1
    readonly property color text:      shell.text
    readonly property color rosewater: shell.rosewater
    readonly property color flamingo:  shell.flamingo
    readonly property color pink:      shell.pink
    readonly property color mauve:     shell.mauve
    readonly property color red:       shell.red
    readonly property color maroon:    shell.maroon
    readonly property color peach:     shell.peach
    readonly property color yellow:    shell.yellow
    readonly property color green:     shell.green
    readonly property color teal:      shell.teal
    readonly property color sky:       shell.sky
    readonly property color sapphire:  shell.sapphire
    readonly property color blue:      shell.blue
    readonly property color lavender:  shell.lavender
    readonly property color dimGreen:  shell.dimGreen

    // ── Espectro do CAVA (do tema 'cava', interno → meio → pontas) ──
    readonly property color cavaInner: cava.cavaInner
    readonly property color cavaMid:   cava.cavaMid
    readonly property color cavaTip:   cava.cavaTip
}
