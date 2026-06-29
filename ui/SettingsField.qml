import QtQuick
import "root:/"           // Config
import "root:/themes"     // Theme
import "root:/services"   // Settings

// Uma linha editável da janela de configurações. Burra: recebe a descrição do campo
// (key/label/ftype/options) e lê/grava o valor efetivo via Settings. A reatividade
// vem de referenciar Settings.data nos bindings (qualquer set() reatribui o mapa).
//
// ftype: "color" | "int" | "real" | "string" | "select" | "bool"
Item {
    id: field

    required property string key
    required property string label
    property string ftype: "string"
    property var options: []        // para "select"

    implicitHeight: 30
    width: parent ? parent.width : 360

    // valor efetivo atual (override OU padrão). Referencia Settings.data p/ reavaliar.
    readonly property var cur: { Settings.data; return field.current() }
    readonly property bool overridden: { Settings.data; return Settings.has(key) }

    function current() {
        if (key.indexOf("pal_") === 0) return Theme[key.substr(4)]
        if (key === "themeShell") return Theme.shellName
        if (key === "themeCava")  return Theme.cavaName
        return Config[key]
    }

    // rótulo
    Text {
        id: lbl
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: parent.width * 0.42
        text: field.label
        color: field.overridden ? Config.accent : Theme.subtext1
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    // botão de reverter (só quando há override)
    Text {
        id: revert
        visible: field.overridden
        anchors { right: editor.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
        text: "↺"
        color: Theme.overlay1
        font.pixelSize: 13
        MouseArea {
            anchors.fill: parent; anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: Settings.unset(field.key)
        }
    }

    // área do editor (direita)
    Item {
        id: editor
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: parent.width * 0.50
        height: 24

        // ── COR: swatch + hex ──
        Row {
            visible: field.ftype === "color"
            anchors.fill: parent
            spacing: 8
            Rectangle {
                width: 24; height: 24; radius: 5
                color: ("" + field.cur)
                border.color: Theme.surface2; border.width: 1
            }
            Rectangle {
                width: parent.width - 32; height: 24; radius: 5
                color: Theme.surface0
                border.color: hexIn.activeFocus ? Config.accent : Theme.surface2
                border.width: 1
                TextInput {
                    id: hexIn
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.pixelSize: 12
                    font.family: "monospace"
                    selectByMouse: true
                    text: ("" + field.cur)
                    onEditingFinished: {
                        let v = text.trim()
                        if (v.length === 6 && v[0] !== "#") v = "#" + v
                        v = v.toLowerCase()
                        if (!/^#[0-9a-fA-F]{6}$/.test(v)) { text = ("" + field.cur); return }   // inválido -> volta
                        if (v !== ("" + field.cur).toLowerCase()) Settings.set(field.key, v)    // só grava se mudou
                    }
                }
            }
        }

        // ── NÚMERO (int/real): TextInput com scroll p/ ajustar ──
        Rectangle {
            visible: field.ftype === "int" || field.ftype === "real"
            anchors.fill: parent
            radius: 5
            color: Theme.surface0
            border.color: numIn.activeFocus ? Config.accent : Theme.surface2
            border.width: 1
            TextInput {
                id: numIn
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.pixelSize: 12
                selectByMouse: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                text: "" + field.cur
                function commit(v) {
                    let n = Number(v)
                    if (isNaN(n)) { text = "" + field.cur; return }
                    if (field.ftype === "int") n = Math.round(n)
                    if (n !== Number(field.cur)) Settings.set(field.key, n)   // só grava se mudou
                }
                onEditingFinished: commit(text)
            }
            WheelHandler {
                onWheel: (e) => {
                    const dir = e.angleDelta.y > 0 ? 1 : -1
                    const step = field.ftype === "int" ? 1 : 0.05
                    let n = Number(field.cur) + dir * step
                    if (field.ftype === "real") n = Math.round(n * 100) / 100
                    Settings.set(field.key, n)
                }
            }
        }

        // ── STRING ──
        Rectangle {
            visible: field.ftype === "string"
            anchors.fill: parent
            radius: 5
            color: Theme.surface0
            border.color: strIn.activeFocus ? Config.accent : Theme.surface2
            border.width: 1
            TextInput {
                id: strIn
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.pixelSize: 12
                selectByMouse: true
                clip: true
                text: "" + field.cur
                onEditingFinished: if (text !== ("" + field.cur)) Settings.set(field.key, text)   // só grava se mudou
            }
        }

        // ── BOOL: toggle ──
        Rectangle {
            visible: field.ftype === "bool"
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 22; radius: 11
            color: field.cur ? Config.accent : Theme.surface1
            Rectangle {
                width: 18; height: 18; radius: 9
                anchors.verticalCenter: parent.verticalCenter
                x: field.cur ? parent.width - width - 2 : 2
                color: Theme.text
                Behavior on x { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Settings.set(field.key, !field.cur)
            }
        }

        // ── SELECT: botões ──
        Row {
            visible: field.ftype === "select"
            anchors.fill: parent
            spacing: 6
            Repeater {
                model: field.options
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: ("" + field.cur) === ("" + modelData)
                    height: 24
                    width: Math.max(60, optTxt.implicitWidth + 18)
                    radius: 5
                    color: sel ? Config.accent : Theme.surface0
                    border.color: sel ? Config.accent : Theme.surface2
                    border.width: 1
                    Text {
                        id: optTxt
                        anchors.centerIn: parent
                        text: "" + parent.modelData
                        color: parent.sel ? Theme.crust : Theme.subtext1
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set(field.key, parent.modelData)
                    }
                }
            }
        }
    }
}
