import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

Scope {
    id: root

    // Instancia o serviço de layout
    MangoLayout { id: mangoLayout }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
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

                        // Clique esquerdo/direito para trocar layout
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                // Abre um menu de seleção ao clicar
                                layoutMenu.popup()
                            }
                        }

                        Menu {
                            id: layoutMenu

                            Repeater {
                                model: [
                                    { label: "Tiling",            code: "T"  },
                                    { label: "Center Tiling",     code: "CT" },
                                    { label: "Right Tiling",      code: "RT" },
                                    { label: "Vertical Tiling",   code: "VT" },
                                    { label: "Scrolling",         code: "S"  },
                                    { label: "Vertical Scrolling",code: "VS" },
                                    { label: "Monocle",           code: "M"  },
                                    { label: "Deck",              code: "K"  },
                                    { label: "Vertical Deck",     code: "VK" },
                                    { label: "Grid",              code: "G"  },
                                    { label: "Vertical Grid",     code: "VG" }
                                ]

                                MenuItem {
                                    text: modelData.label
                                    onTriggered: {
                                        const proc = Qt.createQmlObject(
                                            `import Quickshell.Io; Process {
                                                command: ["mmsg", "-s", "-l", "${modelData.code}"]
                                                running: true
                                            }`, layoutMenu
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // ... outros módulos da sua bar aqui
                }
            }
        }
    }
}
