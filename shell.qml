//@ pragma UseQApplication
// ↑ habilita modo QApplication (necessário p/ menus de plataforma Qt; mantido por
//   segurança para o acionamento dos itens da bandeja). Mudar isto exige RESTART do
//   quickshell (pkill quickshell; qs) — hot-reload não basta.
import Quickshell
import QtQuick
import "root:/services"   // NiriService, StartupService
import "root:/cava"       // CavaService, CavaWindow
import "root:/windows"    // ShellWindow, NotificationWindow
import "root:/ui"         // TopCapsules

// Ponto de entrada: só liga os serviços, os dados e as janelas por monitor.
// A lógica/visual fica nos componentes (ShellWindow, MenuBall, Crystal,
// GothicCorners, CavaWindow, CavaBars, CavaRing, CavaService, NiriService).
Scope {
    id: root

    // ── Serviços ──
    NiriService  { id: niriSvc }    // estado do Niri (monitores, workspaces)
    CavaService  { id: cava }    // níveis de áudio do cava

    // Sobe os daemons da sessão (blueman, idle/lock) centralizados no qs — ver
    // services/StartupService.qml e services/session.sh. O wallpaper (swaybg) sobe
    // pelo WallpaperService (última escolha persistida; modo /bg do lançador).
    // O ThemeExport.init() só instancia o singleton p/ registrar o IPC.
    Component.onCompleted: {
        StartupService.start()
        WallpaperService.init()
        ThemeExport.init()
    }

    // ── Dados (data-driven) ──
    //  Cristais do menu (a ordem define a posição na escadaria: pares à DIREITA da
    //  bola, ímpares à ESQUERDA; os primeiros ficam colados à bola = mais altos).
    //  Item: { icon: "símbolo", label: "nome", command: [argv] }  (command [] = sem ação)
    //  `spawn: "cmd"` -> lança pelo compositor (niri spawn-sh) c/ ambiente Wayland correto (p/ apps gráficos).
    readonly property var menuItems: [
        { icon: "⚙", label: "Sistema", settings: true },   // configurações (cima) + gravação (meio) + toggle de lock (baixo)
        { icon: "☰", label: "Lançador", launcher: true },               // lançador próprio (LauncherWindow)
        { icon: "🔊", label: "Áudio", audio: true },                    // controle de áudio (3 seções)
        { icon: "󰀻", label: "Bandeja", tray: true }                     // system tray (Discord, Steam…)
    ]

    // ── Notificações: uma única janela no topo-centro do monitor focado ──
    NotificationWindow { niri: niriSvc }

    // ── Autenticação polkit: diálogo modal automático (PolkitService/PolkitWindow) ──
    PolkitWindow { niri: niriSvc }

    // ── Configurações: overlay modal único no centro do monitor focado (cristal de Sistema) ──
    SettingsWindow { niri: niriSvc }

    // ── Lançador próprio (cristal "Lançador" / `qs ipc call launcher toggle`) ──
    LauncherWindow { niri: niriSvc }

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
                    niri: niriSvc   // p/ ocultar a onda conforme as janelas (Config.cavaVisibility)
                }

                ShellWindow {
                    modelData: unit.modelData
                    menuItems: root.menuItems
                    niri: niriSvc
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
