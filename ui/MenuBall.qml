import QtQuick
import "root:/"   // Config (raiz)

// A bola/menu central: número do workspace ativo e o anel de workspaces.
Rectangle {
    id: ball
    property var ctx

    readonly property real r2: ctx.ballRadius + 2   // ~2px maior que o raio dos filetes (cobre a junção)
    z: 3
    width: r2 * 2
    height: width
    radius: width / 2
    x: ctx.ballCX - r2
    y: ctx.ballCY - r2
    color: Config.ball
    antialiasing: true
    border.width: 0

    // número do workspace ativo
    Text {
        anchors.centerIn: parent
        text: ball.ctx.activeTag > 0 ? ball.ctx.activeTag : ""
        color: Config.ballText
        font.pixelSize: Config.ballNumberSize
        font.bold: true
    }

    // workspaces em anel (ativo destacado)
    Repeater {
        model: ball.ctx.tags
        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property int n: ball.ctx.tags.length
            readonly property real a: (-90 + index * 360 / Math.max(1, n)) * Math.PI / 180
            readonly property bool active: modelData.is_active

            width: active ? Config.dotActiveSize : Config.dotSize
            height: width
            radius: width / 2
            x: ball.width / 2 + ball.ctx.dotRingR * Math.cos(a) - width / 2
            y: ball.height / 2 + ball.ctx.dotRingR * Math.sin(a) - height / 2
            color: active                     ? Config.dotActive
                 : modelData.is_urgent        ? Config.dotUrgent
                 : modelData.client_count > 0 ? Config.dotOccupied
                 : Config.dotEmpty
            Behavior on width { NumberAnimation { duration: Config.dotAnim } }
        }
    }
}
