import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"   // Config (raiz)

// Menu de AÇÕES de energia (popup estilizado, igual ao de layout/tray). Aberto pelo
// botão esquerdo na seção de energia da pétala de Sistema. As ações gráficas
// (bloquear) vão pelo compositor (mmsg dispatch spawn) p/ ter ambiente Wayland;
// as demais são comandos diretos. O botão DIREITO da pétala abre o wlogout (grade).
PopupWindow {
    id: root
    property var ctx                 // controlador (ShellWindow) -> anchor.window
    property real px: 0
    property real py: 0

    // ação: { label, spawn?: "linha p/ mmsg spawn", cmd?: [argv] }
    readonly property var items: [
        { label: "Bloquear",  spawn: "sh -c 'pidof swaylock || swaylock'" },
        { label: "Sair",      cmd: ["mmsg", "dispatch", "quit"] },
        { label: "Suspender", cmd: ["systemctl", "suspend"] },
        { label: "Hibernar",  cmd: ["systemctl", "hibernate"] },
        { label: "Reiniciar", cmd: ["systemctl", "reboot"] },
        { label: "Desligar",  cmd: ["systemctl", "poweroff"] }
    ]

    function openAt(x, y) { px = x; py = y; visible = true }

    // abre ACIMA do clique, centrado (igual aos outros popups)
    anchor.window: ctx
    anchor.rect.x: px - root.implicitWidth / 2
    anchor.rect.y: py - root.implicitHeight - Config.trayMenuGap
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: Config.layoutMenuW
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
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.9
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: Config.trayMenuAnim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Config.trayMenuAnim; easing.type: Easing.OutCubic } }

        Column {
            anchors.fill: parent
            anchors.margins: Config.trayMenuPad
            spacing: 0

            Text {
                width: parent.width
                height: Config.trayMenuRowH
                leftPadding: 10
                verticalAlignment: Text.AlignVCenter
                text: "Energia"
                color: Config.notifAppText
                font.pixelSize: Config.trayMenuTextSize - 1
                font.bold: true
            }

            Repeater {
                model: root.items
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: parent.width
                    height: Config.trayMenuRowH
                    radius: Config.trayMenuRowRadius
                    color: rowMA.containsMouse ? Config.trayMenuHover : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 10
                        anchors.right: parent.right; anchors.rightMargin: 10
                        text: row.modelData.label
                        color: Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: rowMA
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (row.modelData.spawn)
                                proc.exec(["mmsg", "dispatch", "spawn," + row.modelData.spawn])
                            else if (row.modelData.cmd)
                                proc.exec(row.modelData.cmd)
                            root.visible = false
                        }
                    }
                }
            }
        }
    }
}
