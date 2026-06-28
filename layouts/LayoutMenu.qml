import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"   // Config (raiz)

// Menu de seleção de LAYOUT do Mango — popup estilizado (igual ao do tray/áudio).
// Lista os layoutItems; clicar aplica via `mmsg dispatch setlayout,<name>`. O layout
// atual fica destacado. Aberto pela 1ª pétala.
PopupWindow {
    id: root
    property var ctx                 // controlador (ShellWindow) -> anchor.window, layoutItems, currentLayoutSymbol
    property real px: 0
    property real py: 0

    readonly property var items: ctx ? (ctx.layoutItems ?? []) : []

    function openAt(x, y) { px = x; py = y; visible = true }

    // abre ACIMA do clique, centrado (igual ao menu do tray)
    anchor.window: ctx
    anchor.rect.x: px - root.implicitWidth / 2
    anchor.rect.y: py - root.implicitHeight - Config.trayMenuGap
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: Config.layoutMenuW
    // altura direto do modelo (cabeçalho + 1 linha por layout)
    implicitHeight: (root.items.length + 1) * Config.trayMenuRowH + 2 * Config.trayMenuPad
    color: "transparent"
    visible: false

    Process { id: proc }

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
                text: "Layout"
                color: Config.notifAppText
                font.pixelSize: Config.trayMenuTextSize - 1
                font.bold: true
            }

            // opções de layout
            Repeater {
                model: root.items
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool isCurrent: root.ctx && modelData.symbol === root.ctx.currentLayoutSymbol
                    width: parent.width
                    height: Config.trayMenuRowH
                    radius: Config.trayMenuRowRadius
                    color: rowMA.containsMouse ? Config.trayMenuHover : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 10
                        anchors.right: parent.right; anchors.rightMargin: 24
                        text: row.modelData.label
                        color: row.isCurrent ? Config.accent : Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize
                        font.bold: row.isCurrent
                        elide: Text.ElideRight
                    }
                    // marcador do layout atual
                    Text {
                        visible: row.isCurrent
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 10
                        text: "●"
                        color: Config.accent
                        font.pixelSize: Config.trayMenuTextSize - 3
                    }
                    MouseArea {
                        id: rowMA
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            proc.exec(["mmsg", "dispatch", "setlayout," + row.modelData.name])
                            root.visible = false
                        }
                    }
                }
            }
        }
    }
}
