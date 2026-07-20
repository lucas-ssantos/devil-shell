import Quickshell
import QtQuick
import "root:/services"   // SensorsService, WeatherService
import "root:/"           // Config (raiz)

// Popup-apêndice do botão de temperatura (ClockCapsule): CPU, GPU e a temperatura do
// local (mesmo clima que já era mostrado na cápsula antiga). Abre ABAIXO do botão.
PopupWindow {
    id: root
    property var ctx        // janela-âncora (TopCapsules -> bar)
    property real px: 0
    property real py: 0

    function openAt(x, y) { px = x; py = y; visible = true; SensorsService.refresh() }
    function close() { visible = false }
    function toggle(x, y) { if (visible) close(); else openAt(x, y) }

    anchor.window: ctx
    anchor.rect.x: px - root.implicitWidth / 2
    anchor.rect.y: py + Config.trayMenuGap
    anchor.rect.width: 1
    anchor.rect.height: 1

    readonly property var rows: [
        { label: "Processador", value: SensorsService.cpuTemp },
        { label: "Placa de vídeo", value: SensorsService.gpuTemp },
        { label: "Local", value: WeatherService.temp }
    ]

    implicitWidth: Config.tempPopupW
    implicitHeight: root.rows.length * Config.trayMenuRowH + 2 * Config.trayMenuPad
    color: "transparent"
    visible: false

    Rectangle {
        anchors.fill: parent
        color: Config.trayMenuBg
        radius: Config.trayMenuRadius
        border.color: Config.trayMenuBorder
        border.width: 1
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.9
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Config.trayMenuAnim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Config.trayMenuAnim; easing.type: Easing.OutCubic } }

        Column {
            anchors.fill: parent
            anchors.margins: Config.trayMenuPad
            spacing: 0

            Repeater {
                model: root.rows
                delegate: Item {
                    required property var modelData
                    width: parent.width
                    height: Config.trayMenuRowH
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.value
                        color: Config.accent
                        font.pixelSize: Config.trayMenuTextSize
                        font.bold: true
                    }
                }
            }
        }
    }
}
