import Quickshell
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

                Row {
                    anchors.fill: parent
                    spacing: 0

                    // ── Módulo de layout ──────────────────────────
                    Rectangle {
                        width: layoutLabel.implicitWidth + 24
                        height: parent.height
                        color: "transparent"

                        Text {
                            id: layoutLabel
                            anchors.centerIn: parent
                            text: "⬡ " + mangoLayout.displayName
                            color: "#cba6f7"
                            font.pixelSize: 13
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: layoutPopup.visible = !layoutPopup.visible
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
                                        Quickshell.execDetached(["mmsg", "dispatch", "setlayout," + layoutItem.modelData.name])
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
