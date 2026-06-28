import Quickshell
import Quickshell.Wayland
import QtQuick

// Janela do topo: duas cápsulas retráteis. Esquerda (10% da margem esq.) = mídia (MPRIS);
// direita (10% da margem dir.) = temperatura (wttr.in). Camada Top; só as duas zonas das
// cápsulas recebem mouse (o resto do topo fica click-through).
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

    // ── esquerda: mídia ──
    Capsule {
        x: bar.leftX; y: 0
        icon: Config.iconMedia
        label: MediaService.hasMedia ? MediaService.label : "Nada tocando"
        dim: !MediaService.playing
        onClicked: MediaService.toggle()    // play/pause
    }

    // ── direita: temperatura ──
    Capsule {
        x: bar.rightX; y: 0
        icon: Config.iconWeather
        label: WeatherService.temp
        onClicked: WeatherService.refresh() // força atualizar
    }
}
