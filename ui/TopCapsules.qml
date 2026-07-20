import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/services"   // MediaService
import "root:/"           // Config (raiz); Capsule/ClockCapsule/CalendarPopup/TempPopup na mesma pasta (ui)

// Janela do topo: duas cápsulas retráteis, MESMA largura (Config.capsuleW). Esquerda
// (10% da margem esq.) = mídia (MPRIS, texto rolando quando não cabe); direita (10% da
// margem dir.) = data/hora (botão do calendário) + indicador de CPU (botão que abre o
// popup com CPU/GPU/local). Camada Top; só as duas zonas das cápsulas recebem mouse (o
// resto do topo fica click-through).
PanelWindow {
    id: bar
    property var modelData

    screen: modelData
    WlrLayershell.layer: WlrLayer.Top
    color: "transparent"
    anchors { top: true; left: true; right: true }
    exclusiveZone: 0
    implicitHeight: Config.capsuleH

    readonly property int leftX:  Math.round(bar.width * Config.capsuleEdge)
    readonly property int rightX: Math.round(bar.width * (1 - Config.capsuleEdge) - Config.capsuleW)

    // só as zonas das cápsulas são clicáveis; o resto é click-through
    mask: Region {
        Region { x: bar.leftX;  y: 0; width: Config.capsuleW; height: Config.capsuleH }
        Region { x: bar.rightX; y: 0; width: Config.capsuleW; height: Config.capsuleH }
    }

    // ── esquerda: mídia (texto rola quando não cabe) ──
    Capsule {
        x: bar.leftX; y: 0
        icon: Config.iconMedia
        label: MediaService.hasMedia ? MediaService.label : "Nada tocando"
        dim: !MediaService.playing
        marquee: true
        onClicked: MediaService.toggle()    // play/pause
    }

    // ── direita: data/hora (calendário) + CPU (popup de temperatura) ──
    ClockCapsule {
        x: bar.rightX; y: 0
        calendarOpen: calendarPopup.visible
        tempOpen: tempPopup.visible
        calendarProgress: calendarPopup.progress
        onCalendarClicked: (px, py) => { tempPopup.close(); calendarPopup.toggle(px, py) }
        onTempClicked: (px, py) => { calendarPopup.close(); tempPopup.toggle(px, py) }
        onCapsuleClicked: { calendarPopup.close(); tempPopup.close() }
    }
    CalendarPopup { id: calendarPopup; ctx: bar }
    TempPopup { id: tempPopup; ctx: bar }
}
