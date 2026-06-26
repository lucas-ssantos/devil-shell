import Quickshell
import QtQuick

// Menu estilizado do item da bandeja (system tray), aberto no clique direito.
// Lê as entradas do menu do app via QsMenuOpener e as desenha no tema do shell
// (cores/tamanhos em Config). Suporta submenus por navegação no lugar (linha "Voltar").
PopupWindow {
    id: root
    property var ctx                 // controlador (ShellWindow) -> anchor.window
    property var trayItem            // SystemTrayItem (tem .menu)
    property real px: 0
    property real py: 0

    // pilha de navegação de submenus; currentMenu alimenta o QsMenuOpener
    property var menuStack: []
    property var currentMenu: null
    property bool pendingOpen: false   // aguardando as entradas carregarem p/ mostrar

    // As entradas do menu chegam por D-Bus de forma ASSÍNCRONA. Mostrar o popup antes
    // disso o deixa com altura errada (12px) e não redimensiona -> menu "distorcido".
    // Então só tornamos visível quando as entradas carregarem (childrenChanged), ou
    // imediatamente se já estiverem em cache (mesmo menu reaberto).
    function openAt(item, x, y) {
        trayItem = item
        px = x; py = y
        menuStack = []
        const m = item ? item.menu : null
        if (m === currentMenu && opener.children && opener.children.values.length > 0) {
            visible = true                       // mesmo menu, já carregado
        } else {
            visible = false
            currentMenu = m
            pendingOpen = true
            showFallback.restart()               // segurança: mostra mesmo se nada chegar
        }
    }
    function openSubmenu(entry) {
        menuStack = menuStack.concat([currentMenu])
        visible = false                          // recarrega no tamanho certo (ver openAt)
        currentMenu = entry
        pendingOpen = true
        showFallback.restart()
    }
    function goBack() {
        if (menuStack.length === 0) return
        visible = false
        currentMenu = menuStack[menuStack.length - 1]
        menuStack = menuStack.slice(0, -1)
        pendingOpen = true
        showFallback.restart()
    }

    // abre ACIMA do clique (não sobre a pétala): centrado no x do clique e com a
    // base do menu logo acima do ponto clicado.
    anchor.window: ctx
    anchor.rect.x: px - root.implicitWidth / 2
    anchor.rect.y: py - root.implicitHeight - Config.trayMenuGap
    anchor.rect.width: 1
    anchor.rect.height: 1

    // Altura calculada DIRETO do modelo: o implicitHeight do Column+Repeater
    // dessincroniza quando o menu troca (abria com altura errada/zerada).
    readonly property real contentHeight: {
        const c = opener.children ? opener.children.values : []
        let h = (menuStack.length > 0) ? Config.trayMenuRowH : 0   // linha "Voltar"
        for (let i = 0; i < c.length; i++)
            h += c[i].isSeparator ? Config.trayMenuSepH : Config.trayMenuRowH
        return h
    }
    implicitWidth: Config.trayMenuW
    implicitHeight: contentHeight + 2 * Config.trayMenuPad
    color: "transparent"
    visible: false
    // sem grabFocus: o fechamento é explícito (clique na bola, ou direito no tray de novo),
    // assim a bola não recolhe sozinha enquanto o menu está aberto.

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }

    // mostra o popup assim que as entradas do menu chegarem (D-Bus assíncrono)
    Connections {
        target: opener
        function onChildrenChanged() {
            if (root.pendingOpen && opener.children.values.length > 0) {
                root.pendingOpen = false
                showFallback.stop()
                root.visible = true
            }
        }
    }
    // se o menu não devolver nada a tempo, mostra mesmo assim
    Timer {
        id: showFallback
        interval: 600
        onTriggered: if (root.pendingOpen) { root.pendingOpen = false; root.visible = true }
    }

    Rectangle {
        anchors.fill: parent
        color: Config.trayMenuBg
        radius: Config.trayMenuRadius
        border.color: Config.trayMenuBorder
        border.width: 1

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: Config.trayMenuPad
            spacing: 0

            // ── linha "Voltar" (só dentro de submenu) ──
            Rectangle {
                width: col.width
                height: Config.trayMenuRowH
                visible: root.menuStack.length > 0
                radius: Config.trayMenuRowRadius
                color: backMA.containsMouse ? Config.trayMenuHover : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 10
                    text: "‹  Voltar"
                    color: Config.trayMenuText
                    font.pixelSize: Config.trayMenuTextSize
                }
                MouseArea {
                    id: backMA
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.goBack()
                }
            }

            // ── entradas do menu ──
            Repeater {
                model: opener.children
                delegate: Item {
                    id: row
                    required property var modelData
                    width: col.width
                    height: modelData.isSeparator ? Config.trayMenuSepH : Config.trayMenuRowH

                    // separador
                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Config.trayMenuBorder
                    }

                    // entrada normal
                    Rectangle {
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent
                        radius: Config.trayMenuRowRadius
                        color: (rowMA.containsMouse && row.modelData.enabled) ? Config.trayMenuHover : "transparent"

                        Image {
                            id: ico
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 10
                            visible: row.modelData.icon !== ""
                            source: row.modelData.icon
                            sourceSize.width: Config.trayMenuIconSize
                            sourceSize.height: Config.trayMenuIconSize
                            width: visible ? Config.trayMenuIconSize : 0
                            height: Config.trayMenuIconSize
                            fillMode: Image.PreserveAspectFit
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: ico.right
                            anchors.leftMargin: row.modelData.icon !== "" ? 8 : 0
                            anchors.right: parent.right
                            anchors.rightMargin: row.modelData.hasChildren ? 20 : 10
                            text: row.modelData.text
                            color: row.modelData.enabled ? Config.trayMenuText : Config.trayMenuTextDisabled
                            font.pixelSize: Config.trayMenuTextSize
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        // seta de submenu
                        Text {
                            visible: row.modelData.hasChildren
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right; anchors.rightMargin: 8
                            text: "›"
                            color: Config.trayMenuText
                            font.pixelSize: Config.trayMenuTextSize + 2
                        }

                        MouseArea {
                            id: rowMA
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: row.modelData.enabled
                            onClicked: {
                                if (row.modelData.hasChildren) root.openSubmenu(row.modelData)
                                else { row.modelData.triggered(); root.visible = false }
                            }
                        }
                    }
                }
            }
        }
    }
}
