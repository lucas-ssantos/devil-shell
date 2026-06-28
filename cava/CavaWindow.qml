import Quickshell
import Quickshell.Wayland
import QtQuick

// Janela do CAVA na camada de BAIXO (fica atrás das janelas dos apps).
// Totalmente click-through; só desenha as barras lineares.
PanelWindow {
    id: cavaWin
    property var modelData
    property var levels: []

    screen: modelData
    WlrLayershell.layer: WlrLayer.Bottom
    color: "transparent"
    anchors { bottom: true; left: true; right: true }
    exclusiveZone: 0
    implicitHeight: Config.cavaHeight
    mask: Region {}   // sem área de input -> totalmente click-through

    CavaBars {
        levels: cavaWin.levels
        ballCX: cavaWin.width / 2
        ballRadius: Config.ballRadius
        maxH: Config.cavaMaxH
    }
}
