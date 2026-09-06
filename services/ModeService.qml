pragma Singleton
import Quickshell
import Quickshell.Io
import "root:/"   // Config (shellMode/isDraco efetivos)

// Modo do shell (singleton): "devil" (bola + escadaria de cristais no rodapé, o visual
// clássico) ou "draco" (só uma barra flutuante no topo, estilo Noctalia — ver
// windows/draco/DracoBar.qml). O modo fica persistido no Settings ("shellMode") — sobrevive a
// reload/reboot — e cada janela decide sozinha se aparece lendo Config.isDraco
// (ShellWindow/TopCapsules somem no draco; a DracoBar só existe nele).
//
// Troca pelo teclado: keybind do niri → `qs ipc call mode toggle`
//   Mod+Ctrl+Return { spawn "qs" "ipc" "call" "mode" "toggle"; }   (config.kdl)
// Também pela janela de configurações (grupo "Modo do shell / Barra Draco").
// ⚠️ nomes das funções IPC evitam subcomandos do CLI (`show`, `set`… — ver LauncherService).
Singleton {
    id: svc

    readonly property string mode: Config.shellMode
    readonly property bool draco: Config.isDraco

    function setMode(m) {
        if (m !== "devil" && m !== "draco") return
        Settings.set("shellMode", m)   // mesma pasta (services): sem import
    }
    function toggle() { setMode(draco ? "devil" : "draco") }

    // No-op: o shell.qml chama isto no boot só p/ instanciar o singleton (lazy) —
    // sem isso o IpcHandler abaixo não existe até alguém tocar em ModeService.
    function init() {}

    IpcHandler {
        target: "mode"
        function toggle(): void { svc.toggle() }
        function devil(): void  { svc.setMode("devil") }
        function draco(): void  { svc.setMode("draco") }
        function current(): string { return svc.mode }
    }
}
