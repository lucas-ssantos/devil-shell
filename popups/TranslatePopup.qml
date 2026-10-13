import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/services"   // LauncherService.copyColor (wl-copy via o compositor)
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
    property bool processStarted: false
    property bool copied: false
    property string resultText: ""
    property string errorText: ""

    readonly property string sourceLanguage: reversed ? "Portuguese" : "English"
    readonly property string targetLanguage: reversed ? "English" : "Portuguese"
    readonly property string sourceCode: reversed ? "PT-BR" : "EN"
    readonly property string targetCode: reversed ? "EN-US" : "PT-BR"
    readonly property string envPath: decodeURIComponent(
        Qt.resolvedUrl("../.env").toString().replace(/^file:\/\//, ""))
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

    function translateText() {
        const text = editor.text.trim()
        if (working || text.length === 0) return

        resultText = ""
        errorText = ""
        working = true
        processStarted = false
        translationProcess.exec(["python3", "-c", deeplRequestScript,
                                 envPath, sourceCode, targetCode, text])
    }

    readonly property string deeplRequestScript: `
import json
import sys
import urllib.error
import urllib.request

env_path, source_lang, target_lang, text = sys.argv[1:]
api_key = ""
try:
    with open(env_path, encoding="utf-8") as env_file:
        for line in env_file:
            entry = line.strip()
            if entry.startswith("export "):
                entry = entry[7:].lstrip()
            name, separator, value = entry.partition("=")
            if not separator or name.strip() != "DeepLAPI":
                continue
            api_key = value.strip()
            if len(api_key) >= 2 and api_key[0] == api_key[-1] and api_key[0] in (chr(34), chr(39)):
                api_key = api_key[1:-1]
            break
except OSError as error:
    print("Não foi possível ler o arquivo .env: " + str(error), file=sys.stderr)
    sys.exit(1)

if not api_key:
    print("A chave DeepLAPI não foi encontrada no arquivo .env.", file=sys.stderr)
    sys.exit(1)

payload = json.dumps({
    "text": [text],
    "source_lang": source_lang,
    "target_lang": target_lang
}, ensure_ascii=False).encode("utf-8")
request = urllib.request.Request(
    "https://api-free.deepl.com/v2/translate",
    data=payload,
    headers={
        "Authorization": "DeepL-Auth-Key " + api_key,
        "Content-Type": "application/json",
        "User-Agent": "Devil-Shell"
    },
    method="POST"
)
try:
    with urllib.request.urlopen(request, timeout=30) as response:
        sys.stdout.write(response.read().decode("utf-8"))
except urllib.error.HTTPError as error:
    try:
        response_body = json.loads(error.read().decode("utf-8"))
        message = response_body.get("message", "erro sem detalhes")
    except (UnicodeDecodeError, json.JSONDecodeError):
        message = "resposta de erro sem detalhes"
    print("DeepL API HTTP " + str(error.code) + ": " + message, file=sys.stderr)
    sys.exit(1)
except (urllib.error.URLError, TimeoutError, OSError) as error:
    print("Falha de conexão com a API DeepL: " + str(error), file=sys.stderr)
    sys.exit(1)
`

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

    Timer {
        id: copiedTimer
        interval: 1800
        onTriggered: root.copied = false
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

        onStarted: {
            root.processStarted = true
            console.log("TranslatePopup: solicitação enviada ao DeepL")
        }

        onExited: (exitCode, exitStatus) => {
            root.working = false
            const output = translationOutput.text.trim()
            const error = translationError.text.trim()
            if (exitCode !== 0) {
                root.errorText = error.indexOf("HTTP 456") >= 0
                    ? "A cota mensal gratuita do DeepL foi esgotada."
                    : error !== "" ? error
                    : "Falha ao consultar a API DeepL (código " + exitCode + ")."
                console.warn("TranslatePopup: falha na API DeepL (código " + exitCode + "): " + error)
                return
            }

            try {
                const response = JSON.parse(output)
                const translatedText = response.translations?.[0]?.text ?? ""
                if (translatedText.trim() === "")
                    throw new Error("A resposta não continha texto traduzido.")
                root.resultText = translatedText
                console.log("TranslatePopup: tradução concluída pelo DeepL")
            } catch (e) {
                root.errorText = "Não foi possível interpretar a resposta do DeepL: " + e
                console.warn("TranslatePopup: resposta inválida da API: " + e)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: {
                const insideCard = mouse.x >= root.popupX && mouse.x <= root.popupX + root.popupWidth
                    && mouse.y >= root.popupY && mouse.y <= root.popupY + root.popupHeight
                if (!insideCard) root.close()
            }
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
                text: "DeepL"
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
                height: 14
                text: "DeepL API Free · texto enviado ao DeepL"
                color: Config.trayMenuTextDisabled
                font.pixelSize: Config.trayMenuTextSize - 3
                verticalAlignment: Text.AlignVCenter
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

            Row {
                width: parent.width
                height: 18
                spacing: 8

                Text {
                    width: parent.width - copyButton.width - parent.spacing
                    height: parent.height
                    text: "Tradução"
                    color: Config.trayMenuText
                    font.pixelSize: Config.trayMenuTextSize - 1
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    id: copyButton
                    width: 72
                    height: parent.height
                    radius: Config.trayMenuRowRadius
                    color: copyMouse.containsMouse ? Config.trayMenuHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: root.copied ? "Copiado!" : "Copiar"
                        color: root.copied ? Config.accent
                            : root.resultText.length > 0 ? Config.accent : Config.trayMenuTextDisabled
                        font.pixelSize: Config.trayMenuTextSize - 2
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        enabled: root.resultText.length > 0
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            LauncherService.copyColor(root.resultText)
                            root.copied = true
                            copiedTimer.restart()
                        }
                    }
                }
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
                            : root.working
                                ? (root.processStarted ? "Consultando o DeepL…"
                                    : "Iniciando solicitação…")
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
                    text: root.working
                        ? (root.processStarted ? "Tradução online em andamento…" : "Iniciando solicitação…")
                        : "Enter traduz · Shift+Enter nova linha"
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
