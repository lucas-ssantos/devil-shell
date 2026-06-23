import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    MangoLayout { id: mango }

    // ──────────────────────────────────────────────────────────────
    //  Itens das pétalas (submenus). 100% data-driven: adicione/remova
    //  itens aqui e as pétalas se reorganizam sozinhas no semicírculo.
    //  Cada item: { icon: "símbolo", label: "nome", command: [argv] }
    //  command vazio ([]) = sem ação (placeholder).
    // ──────────────────────────────────────────────────────────────
    readonly property var menuItems: [
        { icon: "★", label: "Item 1", command: [] },
        { icon: "◆", label: "Item 2", command: [] },
        { icon: "●", label: "Item 3", command: [] },
        { icon: "▲", label: "Item 4", command: [] },
        { icon: "■", label: "Item 5", command: [] }
    ]

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                property var modelData
                screen: modelData

                color: "transparent"
                anchors { bottom: true }   // ancorada só embaixo -> centralizada na horizontal
                exclusiveZone: 0           // não reserva espaço na tela
                implicitWidth: 320
                implicitHeight: 220

                // ── Geometria do menu ──────────────────────────────
                readonly property real ballRadius: 46
                readonly property real ballCX: width / 2
                readonly property real ballCY: height - ballRadius - 4
                readonly property real petalW: 26
                readonly property real petalH: 84
                readonly property real petalDist: ballRadius + 10 + petalH / 2  // dist. centro-bola → centro-pétala

                property bool open: false

                // ── Estado do MangoWC p/ ESTE monitor ───────────────
                readonly property var monData: {
                    const byName = mango.monitorByName(modelData.name)
                    if (byName) return byName
                    const list = mango.monitors ?? []
                    return (list.find(m => m.active) ?? list[0]) ?? null
                }
                readonly property var tags: (monData && monData.tags) ? monData.tags : []
                readonly property int activeTag: {
                    for (let i = 0; i < tags.length; i++)
                        if (tags[i].is_active) return tags[i].index
                    return 0
                }

                // Processo p/ comandos one-shot (mmsg view, ações das pétalas)
                Process { id: proc }

                // Fecha com debounce: suaviza a transição entre bola/pétalas
                Timer { id: closeTimer; interval: 140; onTriggered: win.open = false }

                // ── Máscara de input ────────────────────────────────
                //  Fechado: só a bola é clicável (o resto da janela é click-through).
                //  Aberto: a janela toda fica ativa (mover entre pétalas / clicar fora).
                mask: Region {
                    shape: win.open ? RegionShape.Rect : RegionShape.Ellipse
                    x: win.open ? 0 : Math.round(win.ballCX - win.ballRadius)
                    y: win.open ? 0 : Math.round(win.ballCY - win.ballRadius)
                    width: win.open ? win.width : Math.round(win.ballRadius * 2)
                    height: win.open ? win.height : Math.round(win.ballRadius * 2)
                }

                // ── Fundo: clicar fora das pétalas (dentro da janela) fecha ──
                MouseArea {
                    anchors.fill: parent
                    z: 0
                    enabled: win.open
                    hoverEnabled: true
                    onEntered: closeTimer.stop()
                    onExited: closeTimer.restart()
                    onClicked: win.open = false
                }

                // ── Pétalas (auto-organizadas no semicírculo superior) ──
                Repeater {
                    model: root.menuItems

                    delegate: Item {
                        id: petal
                        required property var modelData
                        required property int index

                        readonly property int count: root.menuItems.length
                        // i=0 à esquerda (158°) … último à direita (22°); centro = 90° (pra cima)
                        readonly property real angleDeg: count <= 1 ? 90
                            : 158 - index * (158 - 22) / (count - 1)
                        readonly property real angleRad: angleDeg * Math.PI / 180
                        readonly property bool hovered: petalArea.containsMouse

                        width: win.petalW
                        height: win.petalH
                        transformOrigin: Item.Center
                        rotation: 90 - angleDeg

                        // distância animada: nasce dentro da bola e cresce pra fora
                        property real dist: win.open ? win.petalDist : 0
                        x: win.ballCX + dist * Math.cos(angleRad) - width / 2
                        y: win.ballCY - dist * Math.sin(angleRad) - height / 2

                        scale: win.open ? (hovered ? 1.18 : 1.0) : 0.0
                        opacity: win.open ? 1.0 : 0.0
                        z: hovered ? 2 : 1

                        Behavior on dist { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 130 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2   // cápsula vertical (≈ elipse)
                            color: petal.hovered ? "#f38ba8" : "#eba0ac"
                        }

                        // ícone mantido na vertical (contra-rotação da pétala)
                        Text {
                            anchors.centerIn: parent
                            rotation: -petal.rotation
                            text: petal.modelData.icon ?? ""
                            font.pixelSize: 16
                            color: "#1e1e2e"
                        }

                        MouseArea {
                            id: petalArea
                            anchors.fill: parent
                            enabled: win.open
                            hoverEnabled: true
                            onEntered: closeTimer.stop()
                            onExited: closeTimer.restart()
                            onClicked: {
                                const cmd = petal.modelData.command ?? []
                                if (cmd.length > 0) proc.exec(cmd)
                                win.open = false   // demais pétalas somem (menu fecha)
                            }
                        }
                    }
                }

                // ── A bola (o "menu") ───────────────────────────────
                Rectangle {
                    id: ball
                    z: 3
                    width: win.ballRadius * 2
                    height: width
                    radius: width / 2
                    x: win.ballCX - win.ballRadius
                    y: win.ballCY - win.ballRadius
                    color: "#11111b"
                    border.color: win.open ? "#cba6f7" : "#313244"
                    border.width: 2

                    // número do workspace ativo no centro (o "contador")
                    Text {
                        anchors.centerIn: parent
                        text: win.activeTag > 0 ? win.activeTag : ""
                        color: "#a6e3a1"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    // workspaces em anel (todos; ativo destacado; clicáveis)
                    Repeater {
                        model: win.tags

                        delegate: Rectangle {
                            id: dot
                            required property var modelData
                            required property int index

                            readonly property int n: win.tags.length
                            readonly property real ringR: win.ballRadius * 0.62
                            readonly property real a: (-90 + index * 360 / Math.max(1, n)) * Math.PI / 180
                            readonly property bool active: modelData.is_active

                            width: active ? 11 : 8
                            height: width
                            radius: width / 2
                            x: ball.width / 2 + ringR * Math.cos(a) - width / 2
                            y: ball.height / 2 + ringR * Math.sin(a) - height / 2
                            color: active            ? "#a6e3a1"
                                 : modelData.is_urgent ? "#f38ba8"
                                 : modelData.client_count > 0 ? "#5c7a52"
                                 : "#45475a"

                            Behavior on width { NumberAnimation { duration: 120 } }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: proc.exec(["mmsg", "dispatch", "view," + dot.modelData.index + ",0"])
                            }
                        }
                    }

                    // hover/clique na bola abre/fecha (abaixo dos dots, que recebem clique primeiro)
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        onEntered: { closeTimer.stop(); win.open = true }
                        onExited: closeTimer.restart()
                        onClicked: win.open = !win.open
                    }
                }
            }
        }
    }
}
