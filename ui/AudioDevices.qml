import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "root:/"   // Config (raiz)

// Seletor de dispositivo de áudio (popup), aberto pelo clique DIREITO nas seções
// headphone (saídas) / microfone (entradas) da pétala de áudio. Lista os dispositivos
// (não-streams) e, ao clicar, define o padrão via Pipewire.preferredDefaultAudioSink/Source.
PopupWindow {
    id: root
    property var ctx
    property string kind: "sink"     // "sink" = saídas | "source" = entradas
    property real px: 0
    property real py: 0

    // dispositivos do tipo atual (exclui streams de apps; e monitores nas entradas)
    readonly property var devices: {
        const all = Pipewire.nodes.values
        const out = []
        for (let i = 0; i < all.length; i++) {
            const n = all[i]
            if (n.isStream) continue
            if (kind === "sink") { if (n.isSink) out.push(n) }
            else if (!n.isSink && (n.name || "").toLowerCase().indexOf("monitor") < 0) out.push(n)
        }
        return out
    }
    readonly property var current: kind === "sink" ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource

    function openAt(k, x, y) { kind = k; px = x; py = y; visible = true }
    function devLabel(n) { return n.description || n.nickname || n.name || "?" }

    // abre ACIMA do clique, centrado (igual ao menu do tray)
    anchor.window: ctx
    anchor.rect.x: px - root.implicitWidth / 2
    anchor.rect.y: py - root.implicitHeight - Config.trayMenuGap
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: Config.audioDevW
    // altura direto do modelo (cabeçalho + 1 linha por dispositivo)
    implicitHeight: (root.devices.length + 1) * Config.trayMenuRowH + 2 * Config.trayMenuPad
    color: "transparent"
    visible: false

    Rectangle {
        anchors.fill: parent
        color: Config.trayMenuBg
        radius: Config.trayMenuRadius
        border.color: Config.trayMenuBorder
        border.width: 1
        // animação de entrada (cresce da base)
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.9
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Config.trayMenuAnim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Config.trayMenuAnim; easing.type: Easing.OutCubic } }

        Column {
            anchors.fill: parent
            anchors.margins: Config.trayMenuPad
            spacing: 0

            // cabeçalho
            Text {
                width: parent.width
                height: Config.trayMenuRowH
                leftPadding: 10
                verticalAlignment: Text.AlignVCenter
                text: root.kind === "sink" ? "Saída de áudio" : "Entrada de áudio"
                color: Config.notifAppText
                font.pixelSize: Config.trayMenuTextSize - 1
                font.bold: true
            }

            // dispositivos
            Repeater {
                model: root.devices
                delegate: Rectangle {
                    id: devRow
                    required property var modelData
                    readonly property bool isCurrent: modelData === root.current
                    width: parent.width
                    height: Config.trayMenuRowH
                    radius: Config.trayMenuRowRadius
                    color: devMA.containsMouse ? Config.trayMenuHover : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 10
                        anchors.right: parent.right; anchors.rightMargin: 24
                        text: root.devLabel(devRow.modelData)
                        color: devRow.isCurrent ? Config.accent : Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize
                        font.bold: devRow.isCurrent
                        elide: Text.ElideRight
                    }
                    // marcador do dispositivo atual
                    Text {
                        visible: devRow.isCurrent
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 10
                        text: "●"
                        color: Config.accent
                        font.pixelSize: Config.trayMenuTextSize - 3
                    }
                    MouseArea {
                        id: devMA
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.kind === "sink") Pipewire.preferredDefaultAudioSink = devRow.modelData
                            else Pipewire.preferredDefaultAudioSource = devRow.modelData
                            root.visible = false
                        }
                    }
                }
            }
        }
    }
}
