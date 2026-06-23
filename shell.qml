import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    MangoLayout { id: mangoLayout }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: panelWindow
                property var modelData
                screen: modelData
                anchors { top: true; left: true; right: true }
                implicitHeight: 32
                color: "#1e1e2e"

                // ── Estado do MangoWC para ESTE monitor ──────────
                readonly property var monData: {
                    const byName = mangoLayout.monitorByName(modelData.name)
                    if (byName) return byName
                    // fallback: monitor focado (caso o nome da screen não case com o do mmsg)
                    const list = mangoLayout.monitors ?? []
                    return (list.find(m => m.active) ?? list[0]) ?? null
                }
                readonly property string currentLayoutName: {
                    const sym = monData ? monData.layout_symbol : "?"
                    return mangoLayout.layoutNames[sym] ?? sym
                }
                readonly property var tags: (monData && monData.tags) ? monData.tags : []

                // Janela deslizante de até 3 tags, centrada na focada e clampada nas
                // bordas: tag 1 -> [1,2,3]; tag do meio -> [N-1,N,N+1]; última -> [n-2,n-1,n]
                readonly property var windowTags: {
                    const list = panelWindow.tags
                    const total = list.length
                    if (total === 0) return []
                    let focused = 1
                    for (let i = 0; i < total; i++)
                        if (list[i].is_active) { focused = list[i].index; break }
                    const start = Math.max(1, Math.min(focused - 1, total - 2))
                    const out = []
                    for (let idx = start; idx < start + 3 && idx <= total; idx++) {
                        for (let j = 0; j < total; j++)
                            if (list[j].index === idx) { out.push(list[j]); break }
                    }
                    return out
                }

                // Processo one-shot para comandos `mmsg dispatch` (setlayout, view, …).
                // Mesmo mecanismo da watch: herda o MANGO_INSTANCE_SIGNATURE e acha o mmsg no PATH.
                Process { id: dispatchProc }

                Row {
                    anchors.fill: parent
                    spacing: 8

                    // ── Módulo de layout ──────────────────────────
                    Rectangle {
                        width: layoutLabel.implicitWidth + 24
                        height: parent.height
                        color: "transparent"

                        Text {
                            id: layoutLabel
                            anchors.centerIn: parent
                            text: "⬡ " + panelWindow.currentLayoutName
                            color: "#cba6f7"
                            font.pixelSize: 13
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: layoutPopup.visible = !layoutPopup.visible
                        }
                    }

                    // ── Indicador de áreas de trabalho (até 3 tags) ──
                    Row {
                        height: parent.height
                        spacing: 4

                        Repeater {
                            model: panelWindow.windowTags

                            delegate: Item {
                                id: wsItem
                                required property var modelData
                                width: 26
                                height: parent.height

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 22
                                    radius: 4
                                    color: wsItem.modelData.is_active ? "#cba6f7"
                                         : wsItem.modelData.is_urgent ? "#f38ba8"
                                         : wsArea.containsMouse   ? "#45475a"
                                         : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "" + wsItem.modelData.index
                                        color: wsItem.modelData.is_active ? "#1e1e2e" : "#bac2de"
                                        font.pixelSize: 13
                                        font.bold: wsItem.modelData.is_active
                                    }
                                }

                                MouseArea {
                                    id: wsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        // view,<tag>,0 -> vai para aquela área (no monitor focado)
                                        dispatchProc.exec(["mmsg", "dispatch", "view," + wsItem.modelData.index + ",0"])
                                    }
                                }
                            }
                        }
                    }

                    // ... outros módulos da sua bar aqui
                }

                PopupWindow {
                    id: layoutPopup

                    // Ancorado à janela da barra, logo abaixo dela, alinhado à esquerda
                    anchor.window: panelWindow
                    anchor.rect.x: 0
                    anchor.rect.y: panelWindow.height

                    implicitWidth: 200
                    implicitHeight: popupCol.implicitHeight
                    color: "#1e1e2e"

                    visible: false
                    grabFocus: true  // clicar fora fecha e zera 'visible'

                    Column {
                        id: popupCol
                        width: parent.width

                        Repeater {
                            model: [
                                { label: "Tiling",            name: "tile"              },
                                { label: "Center Tiling",     name: "center_tile"       },
                                { label: "Right Tiling",      name: "right_tile"        },
                                { label: "Vertical Tiling",   name: "vertical_tile"     },
                                { label: "Scrolling",         name: "scroller"          },
                                { label: "Vertical Scrolling",name: "vertical_scroller" },
                                { label: "Monocle",           name: "monocle"           },
                                { label: "Deck",              name: "deck"              },
                                { label: "Vertical Deck",     name: "vertical_deck"     },
                                { label: "Grid",              name: "grid"              },
                                { label: "Vertical Grid",     name: "vertical_grid"     }
                            ]

                            delegate: Rectangle {
                                id: layoutItem
                                required property var modelData
                                width: popupCol.width
                                height: 32
                                color: itemArea.containsMouse ? "#313244" : "transparent"

                                Text {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: layoutItem.modelData.label
                                    color: "#cdd6f4"
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        // mmsg dispatch espera "func,arg" como UM token só
                                        dispatchProc.exec(["mmsg", "dispatch", "setlayout," + layoutItem.modelData.name])
                                        layoutPopup.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
