import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/"

PanelWindow {
    id: root

    property var ctx
    property real px: 0
    property real py: 0
    property bool below: false
    property bool reversed: false
    property bool revealed: false
    property bool working: false
    property string resultText: ""
    property string errorText: ""

    readonly property string sourceLanguage: reversed ? "Portuguese" : "English"
    readonly property string sourceCode: reversed ? "pt" : "en"
    readonly property string targetLanguage: reversed ? "English" : "Portuguese"
    readonly property string targetCode: reversed ? "en" : "pt"
    readonly property real popupWidth: 500
    readonly property real popupHeight: 454
    readonly property real anchorY: below ? py : (screen ? screen.height : height) - ctx.height + py
    readonly property real popupX: Math.max(12, Math.min(width - popupWidth - 12, px - popupWidth / 2))
    readonly property real popupY: Math.max(12, Math.min(height - popupHeight - 12,
        below ? anchorY + Config.dracoPopupGap
              : anchorY - popupHeight - Config.trayMenuGap))

    function openAt(x, y) {
        hideTimer.stop()
        px = x
        py = y
        revealed = false
        visible = true
        if (backingWindowVisible) showTimer.restart()
    }

    function close() {
        showTimer.stop()
        revealed = false
        hideTimer.restart()
    }

    function promptFor(text) {
        return "You are a professional " + sourceLanguage + " (" + sourceCode + ") to "
            + targetLanguage + " (" + targetCode + ") translator. Your goal is to accurately convey "
            + "the meaning and nuances of the original " + sourceLanguage + " text while adhering to "
            + targetLanguage + " grammar, vocabulary, and cultural sensitivities.\n"
            + "Produce only the " + targetLanguage + " translation, without any additional "
            + "explanations or commentary. Please translate the following " + sourceLanguage
            + " text into " + targetLanguage + ":\n\n" + text
    }

    function translateText() {
        const text = editor.text.trim()
        if (working || text.length === 0) return

        resultText = ""
        errorText = ""
        working = true
        translationProcess.exec(["ollama", "run", "translategemma:4b", promptFor(text)])
    }

    screen: ctx ? (ctx.screen ?? ctx.modelData) : null
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible && revealed
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: false
    implicitWidth: screen ? screen.width : popupWidth
    implicitHeight: screen ? screen.height : popupHeight

    mask: Region {
        x: 0
        y: 0
        width: root.width
        height: root.height
    }

    Timer {
        id: hideTimer
        interval: Config.trayMenuAnim
        onTriggered: root.visible = false
    }

    Timer {
        id: showTimer
        interval: 40
        onTriggered: {
            if (!root.visible) return
            root.revealed = true
            focusTimer.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: if (root.visible && root.revealed) editor.forceActiveFocus()
    }

    onVisibleChanged: if (!visible && revealed) {
        visible = true
        close()
    }

    onBackingWindowVisibleChanged: if (backingWindowVisible && visible && !revealed) showTimer.restart()

    Process {
        id: translationProcess

        stdout: StdioCollector { id: translationOutput }
        stderr: StdioCollector { id: translationError }

        onExited: (exitCode, exitStatus) => {
            root.working = false
            const output = translationOutput.text.trim()
            const error = translationError.text.trim()
            if (exitCode === 0 && output !== "") {
                root.resultText = output
            } else {
                root.errorText = error !== "" ? error
                    : exitCode === 0 ? "Ollama não retornou uma tradução."
                    : "Falha ao executar Ollama (código " + exitCode + "). Verifique se o Ollama está instalado e ativo."
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card
            x: root.popupX
            y: root.popupY + (root.revealed || root.below ? 0 : root.popupHeight)
            width: root.popupWidth
            height: root.revealed ? root.popupHeight : 0
            clip: true
            color: Config.trayMenuBg
            radius: Config.windowRadius(Config.trayMenuRadius)
            topLeftRadius: 0
            topRightRadius: 0
            border.color: Config.trayMenuBorder
            border.width: 1
            Behavior on height {
                NumberAnimation {
                    duration: Config.trayMenuAnim
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Config.trayMenuAnim
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                width: parent.width - 28
                height: implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                spacing: 8

            Text {
                width: parent.width
                height: 24
                text: "Tradutor Ollama"
                color: Config.trayMenuText
                font.pixelSize: Config.trayMenuTextSize + 3
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            Row {
                width: parent.width
                height: 36
                spacing: 8

                Rectangle {
                    width: (parent.width - 52) / 2
                    height: parent.height
                    radius: Config.trayMenuRowRadius
                    color: Config.trayMenuHover
                    Text {
                        anchors.centerIn: parent
                        text: root.sourceLanguage
                        color: Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize
                    }
                }

                Rectangle {
                    width: 36
                    height: parent.height
                    radius: Config.trayMenuRowRadius
                    color: swapMouse.containsMouse ? Config.trayMenuHover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "⇄"
                        color: Config.accent
                        font.pixelSize: 20
                    }
                    MouseArea {
                        id: swapMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.working
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.reversed = !root.reversed
                            root.resultText = ""
                            root.errorText = ""
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 52) / 2
                    height: parent.height
                    radius: Config.trayMenuRowRadius
                    color: Config.trayMenuHover
                    Text {
                        anchors.centerIn: parent
                        text: root.targetLanguage
                        color: Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize
                    }
                }
            }

            Text {
                width: parent.width
                height: 18
                text: "Texto para traduzir"
                color: Config.trayMenuText
                font.pixelSize: Config.trayMenuTextSize - 1
            }

            Rectangle {
                width: parent.width
                height: 112
                radius: Config.trayMenuRowRadius
                color: Config.trayMenuHover

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    contentWidth: width
                    contentHeight: Math.max(height, editor.implicitHeight)
                    TextEdit {
                        id: editor
                        width: parent.width
                        height: Math.max(parent.height, implicitHeight)
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        activeFocusOnPress: true
                        color: Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize
                        focus: root.visible && root.revealed
                        Keys.onReturnPressed: (event) => {
                            if (event.modifiers & Qt.ShiftModifier) return
                            event.accepted = true
                            root.translateText()
                        }
                        Keys.onEnterPressed: (event) => {
                            if (event.modifiers & Qt.ShiftModifier) return
                            event.accepted = true
                            root.translateText()
                        }
                        Keys.onEscapePressed: {
                            event.accepted = true
                            root.close()
                        }
                    }
                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        text: "Digite ou cole o texto…"
                        color: Config.trayMenuTextDisabled
                        font.pixelSize: Config.trayMenuTextSize
                        visible: editor.text.length === 0
                        enabled: false
                    }
                }
            }

            Text {
                width: parent.width
                height: 18
                text: "Tradução"
                color: Config.trayMenuText
                font.pixelSize: Config.trayMenuTextSize - 1
            }

            Rectangle {
                width: parent.width
                height: 112
                radius: Config.trayMenuRowRadius
                color: Config.trayMenuHover
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    contentWidth: width
                    contentHeight: Math.max(height, translated.implicitHeight)
                    TextEdit {
                        id: translated
                        width: parent.width
                        height: Math.max(parent.height, implicitHeight)
                        text: root.resultText
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.Wrap
                        readOnly: true
                        selectByMouse: true
                        color: Config.trayMenuText
                        font.pixelSize: Config.trayMenuTextSize
                    }
                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: parent.width
                        text: root.errorText !== "" ? root.errorText
                            : root.working ? "Carregando translategemma:4b e traduzindo…"
                            : "A tradução aparecerá aqui."
                        color: root.errorText !== "" ? Config.polkitError : Config.trayMenuTextDisabled
                        font.pixelSize: Config.trayMenuTextSize
                        wrapMode: Text.Wrap
                        visible: root.resultText.length === 0
                    }
                }
            }

            Row {
                width: parent.width
                height: 34
                spacing: 10

                Text {
                    width: parent.width - translateButton.width - parent.spacing
                    height: parent.height
                    text: root.working ? "Aguarde o modelo…" : "Enter traduz · Shift+Enter nova linha"
                    color: Config.trayMenuTextDisabled
                    font.pixelSize: Config.trayMenuTextSize - 2
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: translateButton
                    width: 116
                    height: parent.height
                    radius: Config.trayMenuRowRadius
                    color: root.working ? Config.trayMenuHover : Config.accent
                    Text {
                        anchors.centerIn: parent
                        text: root.working ? "Traduzindo…" : "Traduzir"
                        color: Config.trayMenuBg
                        font.pixelSize: Config.trayMenuTextSize
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.working && editor.text.trim().length > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.translateText()
                    }
                }
            }
            }
        }
    }
}
