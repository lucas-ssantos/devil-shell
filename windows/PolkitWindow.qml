import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/services"   // PolkitService, NiriService (via property)
import "root:/"           // Config

// Diálogo de autenticação polkit. Diferente dos outros cristais/janelas, este NÃO é
// aberto pelo usuário: aparece sozinho quando algum app pede privilégio elevado
// (GParted, instalar firmware do bluetooth, NetworkManager de sistema, etc.) — mesmo
// padrão "automático" da NotificationWindow. Overlay modal no monitor focado, travado
// na ABERTURA (mesma técnica da SettingsWindow/LauncherWindow) para não pular de tela
// se o foco mudar no meio da autenticação.
// A lógica (registro do agente, fila de pedidos, sessão PAM) vive inteira no
// PolkitAgent por trás do PolkitService; aqui só o formulário: mensagem, seletor de
// identidade (quando há mais de uma), campo de senha e erro/retry.
PanelWindow {
    id: win
    property var niri   // NiriService, p/ achar o monitor focado

    readonly property var flow: PolkitService.flow
    visible: PolkitService.isActive

    property var openScreen: null
    onVisibleChanged: {
        if (!visible) return
        const list = niri ? (niri.monitors ?? []) : []
        const a = list.find(m => m.active)
        const s = a ? Quickshell.screens.find(sc => sc.name === a.name) : undefined
        openScreen = s ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    }
    screen: openScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive (não OnDemand como a SettingsWindow): um pedido de privilégio deve travar
    // TODO o teclado até ser resolvido — é o comportamento esperado de um agente polkit.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0

    function submit() {
        if (!flow) return
        flow.submit(passwordInput.text)
        passwordInput.text = ""
    }
    function cancel() {
        if (!flow) return
        flow.cancelAuthenticationRequest()
        passwordInput.text = ""
    }

    // novo pedido de resposta (1ª tentativa, ou próxima etapa de uma conversa
    // multi-fator, ou retry após senha errada): limpa e refoca o campo
    Connections {
        target: flow
        function onIsResponseRequiredChanged() {
            passwordInput.text = ""
            if (flow.isResponseRequired) passwordInput.forceActiveFocus()
        }
    }

    // fundo escurecido — sem clique-fora-fecha (autenticação não se cancela à toa)
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.55 }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, Config.polkitW)
        height: col.implicitHeight + 40
        radius: Config.polkitRadius
        color: Config.polkitBg
        border.color: Config.polkitBorder
        border.width: 1

        // engole clique (não fecha) e devolve o foco ao campo
        MouseArea { anchors.fill: parent; onClicked: passwordInput.forceActiveFocus() }
        Item {
            anchors.fill: parent
            focus: win.visible
            Keys.onEscapePressed: win.cancel()
        }

        Column {
            id: col
            x: 20; y: 20
            width: panel.width - 40
            spacing: 12

            Text {
                width: parent.width
                text: Config.iconPolkitLock
                font.family: Config.iconFont
                font.pixelSize: Config.polkitIconSize
                color: Config.accent
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: flow?.message ?? "Autenticação necessária"
                color: Config.polkitText
                font.pixelSize: 15
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                visible: (flow?.supplementaryMessage ?? "") !== ""
                text: flow?.supplementaryMessage ?? ""
                color: flow?.supplementaryIsError ? Config.polkitError : Config.polkitSub
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            // seletor de identidade — só aparece quando há mais de uma (ex.: grupo com
            // vários usuários habilitados a autorizar a mesma ação)
            Row {
                visible: (flow?.identities?.length ?? 0) > 1
                spacing: 6
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: flow?.identities ?? []
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: flow?.selectedIdentity === modelData
                        width: idTxt.implicitWidth + 20; height: 26; radius: 13
                        color: sel ? Config.accent : Config.polkitBorder
                        border.color: sel ? Config.accent : Config.polkitBorder
                        border.width: 1
                        Text {
                            id: idTxt
                            anchors.centerIn: parent
                            text: modelData.displayName
                            color: sel ? Config.polkitBg : Config.polkitText
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: flow.selectedIdentity = modelData
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: (flow?.inputPrompt ?? "") !== ""
                text: flow?.inputPrompt ?? ""
                color: Config.polkitSub
                font.pixelSize: 12
            }
            Rectangle {
                width: parent.width; height: 36; radius: 8
                visible: flow?.isResponseRequired ?? false
                color: Config.polkitBorder
                border.color: passwordInput.activeFocus ? Config.accent : Config.polkitBorder
                border.width: 1
                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.margins: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: Config.polkitText
                    font.pixelSize: 13
                    echoMode: flow?.responseVisible ? TextInput.Normal : TextInput.Password
                    selectByMouse: true
                    focus: true
                    Keys.onReturnPressed: win.submit()
                    Keys.onEnterPressed: win.submit()
                    Keys.onEscapePressed: win.cancel()
                }
            }

            Text {
                width: parent.width
                visible: flow?.failed ?? false
                text: "Autenticação falhou, tente novamente"
                color: Config.polkitError
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Rectangle {
                    width: cancelTxt.implicitWidth + 28; height: 32; radius: 8
                    color: Config.polkitBorder
                    border.color: Config.polkitBorder; border.width: 1
                    Text { id: cancelTxt; anchors.centerIn: parent; text: "Cancelar"; color: Config.polkitText; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.cancel() }
                }
                Rectangle {
                    width: okTxt.implicitWidth + 28; height: 32; radius: 8
                    color: Config.accent
                    Text { id: okTxt; anchors.centerIn: parent; text: "OK"; color: Config.polkitBg; font.pixelSize: 12; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.submit() }
                }
            }
        }
    }
}
