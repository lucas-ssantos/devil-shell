import Quickshell
import QtQuick

// Ponto de entrada: só liga os serviços, os dados e as janelas por monitor.
// A lógica/visual fica nos componentes (ShellWindow, MenuBall, Petal, LayoutMenu,
// GothicCorners, CavaWindow, CavaBars, CavaRing, CavaService, MangoLayout).
Scope {
    id: root

    // ── Serviços ──
    MangoLayout  { id: mangoSvc }   // estado do MangoWC (monitores, tags, layouts)
    CavaService  { id: cava }    // níveis de áudio do cava

    // ── Dados (data-driven) ──
    //  Pétalas: a 1ª é o seletor de LAYOUT (tratada à parte); as demais são livres.
    //  Item: { icon: "símbolo", label: "nome", command: [argv] }  (command [] = sem ação)
    readonly property var menuItems: [
        { icon: "⬡", label: "Layout", command: [] },
        { icon: "◆", label: "Item 2", command: [] },
        { icon: "●", label: "Item 3", command: [] },
        { icon: "▲", label: "Item 4", command: [] },
        { icon: "📷", label: "Captura", capture: true }, // 5ª = print + gravação (2 seções)
        { icon: "🔊", label: "Áudio", audio: true },      // 6ª = controle de áudio (3 seções)
        { icon: "󰀻", label: "Bandeja", tray: true }       // 7ª = system tray (Discord, Steam…)
    ]

    //  Opções de layout do Mango (symbol = sigla; name = comando do mmsg; label = nome).
    readonly property var layoutItems: [
        { symbol: "T",  name: "tile",              label: "Tiling" },
        { symbol: "CT", name: "center_tile",       label: "Center Tiling" },
        { symbol: "RT", name: "right_tile",        label: "Right Tiling" },
        { symbol: "VT", name: "vertical_tile",     label: "Vertical Tiling" },
        { symbol: "S",  name: "scroller",          label: "Scrolling" },
        { symbol: "VS", name: "vertical_scroller", label: "Vertical Scrolling" },
        { symbol: "M",  name: "monocle",           label: "Monocle" },
        { symbol: "K",  name: "deck",              label: "Deck" },
        { symbol: "VK", name: "vertical_deck",     label: "Vertical Deck" },
        { symbol: "G",  name: "grid",              label: "Grid" },
        { symbol: "VG", name: "vertical_grid",     label: "Vertical Grid" }
    ]

    // ── Uma instância por monitor: janela do cava (camada de baixo) + shell (camada de cima) ──
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: unit
                property var modelData

                CavaWindow {
                    modelData: unit.modelData
                    levels: cava.levels
                }

                ShellWindow {
                    modelData: unit.modelData
                    menuItems: root.menuItems
                    layoutItems: root.layoutItems
                    mango: mangoSvc
                    levels: cava.levels
                }
            }
        }
    }
}
