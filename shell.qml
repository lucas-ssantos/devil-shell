//@ pragma UseQApplication
// ↑ habilita modo QApplication (necessário p/ menus de plataforma Qt; mantido por
//   segurança para o acionamento dos itens da bandeja). Mudar isto exige RESTART do
//   quickshell (pkill quickshell; qs) — hot-reload não basta.
import Quickshell
import QtQuick
import "root:/services"   // MangoLayout, StartupService
import "root:/cava"       // CavaService, CavaWindow
import "root:/windows"    // ShellWindow, NotificationWindow
import "root:/ui"         // TopCapsules

// Ponto de entrada: só liga os serviços, os dados e as janelas por monitor.
// A lógica/visual fica nos componentes (ShellWindow, MenuBall, Petal, LayoutMenu,
// GothicCorners, CavaWindow, CavaBars, CavaRing, CavaService, MangoLayout).
Scope {
    id: root

    // ── Serviços ──
    MangoLayout  { id: mangoSvc }   // estado do MangoWC (monitores, tags, layouts)
    CavaService  { id: cava }    // níveis de áudio do cava

    // Sobe os daemons da sessão (wallpaper, blueman, idle/lock) centralizados no qs.
    // Ver services/StartupService.qml e services/session.sh.
    Component.onCompleted: StartupService.start()

    // ── Dados (data-driven) ──
    //  Pétalas: a 1ª é o seletor de LAYOUT (tratada à parte); as demais são livres.
    //  Item: { icon: "símbolo", label: "nome", command: [argv] }  (command [] = sem ação)
    //  `spawn: "cmd"` -> lança pelo compositor (mango) c/ ambiente Wayland correto (p/ apps gráficos).
    readonly property var menuItems: [
        { icon: "⬡", label: "Layout", command: [] },                    // 1ª = mudar layout do mango
        { icon: "", label: "Atualizações", update: true },             // 2ª = updates do sistema + MangoWC
        { icon: "⚙", label: "Sistema", settings: true, power: true },   // 3ª = configurações (cima) + energia/wlogout (baixo, 2 seções)
        { icon: "☰", label: "Lançador", spawn: "rofi -show drun" },     // 4ª = abre o launcher
        { icon: "📷", label: "Captura", capture: true },                // 5ª = print + gravação (2 seções)
        { icon: "🔊", label: "Áudio", audio: true },                    // 6ª = controle de áudio (3 seções)
        { icon: "󰀻", label: "Bandeja", tray: true }                     // 7ª = system tray (Discord, Steam…)
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

    // ── Notificações: uma única janela no topo-centro do monitor focado ──
    NotificationWindow { mango: mangoSvc }

    // ── Configurações: overlay modal único no centro do monitor focado (3ª pétala) ──
    SettingsWindow { mango: mangoSvc }

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

                // cápsulas retráteis no topo (mídia / temperatura)
                TopCapsules {
                    modelData: unit.modelData
                }
            }
        }
    }
}
