import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/ui"         // SettingsField
import "root:/themes"     // Theme
import "root:/services"   // Settings, ThemeExport
import "root:/"           // Config

// Janela de configurações do shell (3ª pétala). Overlay modal no centro da tela
// focada: lista TODAS as opções do Config + a escolha de paletas (shell/cava) +
// overrides de cor crua. Grava tudo via Settings (settings.json). Botões para
// restaurar o padrão e regenerar os temas externos (kitty/rofi/mango/vesktop).
PanelWindow {
    id: win
    property var mango   // MangoLayout, p/ achar o monitor focado

    visible: Settings.open

    // monitor focado (fallback: o primeiro)
    screen: {
        const list = mango ? (mango.monitors ?? []) : []
        const a = list.find(m => m.active)
        if (a) {
            const s = Quickshell.screens.find(sc => sc.name === a.name)
            if (s) return s
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0

    // ── Esquema de TODAS as opções, agrupadas ──
    readonly property var groups: [
        { title: "Tema", fields: [
            { key: "themeShell", label: "Paleta do shell", ftype: "select", options: Theme.paletteNames },
            { key: "themeCava",  label: "Paleta do CAVA",  ftype: "select", options: Theme.paletteNames }
        ]},
        { title: "Paleta — base e superfícies", fields: [
            { key: "pal_crust", label: "crust (bola/fundo)", ftype: "color" },
            { key: "pal_mantle", label: "mantle", ftype: "color" },
            { key: "pal_base", label: "base", ftype: "color" },
            { key: "pal_surface0", label: "surface0", ftype: "color" },
            { key: "pal_surface1", label: "surface1", ftype: "color" },
            { key: "pal_surface2", label: "surface2", ftype: "color" },
            { key: "pal_overlay0", label: "overlay0", ftype: "color" },
            { key: "pal_overlay1", label: "overlay1", ftype: "color" },
            { key: "pal_overlay2", label: "overlay2", ftype: "color" },
            { key: "pal_subtext0", label: "subtext0", ftype: "color" },
            { key: "pal_subtext1", label: "subtext1", ftype: "color" },
            { key: "pal_text", label: "text", ftype: "color" }
        ]},
        { title: "Paleta — acentos", fields: [
            { key: "pal_rosewater", label: "rosewater", ftype: "color" },
            { key: "pal_flamingo", label: "flamingo", ftype: "color" },
            { key: "pal_pink", label: "pink", ftype: "color" },
            { key: "pal_mauve", label: "mauve (acento)", ftype: "color" },
            { key: "pal_red", label: "red", ftype: "color" },
            { key: "pal_maroon", label: "maroon", ftype: "color" },
            { key: "pal_peach", label: "peach", ftype: "color" },
            { key: "pal_yellow", label: "yellow", ftype: "color" },
            { key: "pal_green", label: "green", ftype: "color" },
            { key: "pal_teal", label: "teal", ftype: "color" },
            { key: "pal_sky", label: "sky", ftype: "color" },
            { key: "pal_sapphire", label: "sapphire", ftype: "color" },
            { key: "pal_blue", label: "blue", ftype: "color" },
            { key: "pal_lavender", label: "lavender", ftype: "color" },
            { key: "pal_dimGreen", label: "dimGreen", ftype: "color" }
        ]},
        { title: "Paleta — CAVA", fields: [
            { key: "pal_cavaInner", label: "cavaInner", ftype: "color" },
            { key: "pal_cavaMid", label: "cavaMid", ftype: "color" },
            { key: "pal_cavaTip", label: "cavaTip", ftype: "color" }
        ]},
        { title: "Cores dos componentes", fields: [
            { key: "ball", label: "Bola", ftype: "color" },
            { key: "petal", label: "Pétala", ftype: "color" },
            { key: "petalHover", label: "Pétala (hover)", ftype: "color" },
            { key: "petalIcon", label: "Ícone da pétala", ftype: "color" },
            { key: "accent", label: "Acento", ftype: "color" },
            { key: "ballText", label: "Texto da bola", ftype: "color" },
            { key: "clock", label: "Relógio", ftype: "color" },
            { key: "layoutPill", label: "Pílula layout", ftype: "color" },
            { key: "layoutPillHover", label: "Pílula layout (hover)", ftype: "color" },
            { key: "layoutText", label: "Texto layout", ftype: "color" },
            { key: "layoutTextHover", label: "Texto layout (hover)", ftype: "color" },
            { key: "dotActive", label: "Ponto ativo", ftype: "color" },
            { key: "dotUrgent", label: "Ponto urgente", ftype: "color" },
            { key: "dotOccupied", label: "Ponto ocupado", ftype: "color" },
            { key: "dotEmpty", label: "Ponto vazio", ftype: "color" }
        ]},
        { title: "Janela e bola", fields: [
            { key: "shellHeight", label: "Altura do shell", ftype: "int" },
            { key: "cavaHeight", label: "Altura do CAVA", ftype: "int" },
            { key: "barHeight", label: "Altura da barra", ftype: "int" },
            { key: "ballRadius", label: "Raio da bola", ftype: "real" },
            { key: "ballPeek", label: "Fatia visível", ftype: "real" },
            { key: "dotRingFactor", label: "Anel de workspaces", ftype: "real" },
            { key: "dotSize", label: "Tamanho do ponto", ftype: "real" },
            { key: "dotActiveSize", label: "Ponto ativo", ftype: "real" },
            { key: "dotHitR", label: "Clique do ponto", ftype: "real" },
            { key: "gothicR", label: "Cantos góticos", ftype: "real" }
        ]},
        { title: "Pétalas", fields: [
            { key: "petalW", label: "Largura", ftype: "real" },
            { key: "petalH", label: "Altura", ftype: "real" },
            { key: "petalGap", label: "Folga bola→pétala", ftype: "real" },
            { key: "petalShrink", label: "Escala não-hover", ftype: "real" },
            { key: "petalHoverScale", label: "Escala hover", ftype: "real" },
            { key: "petalHoverExtend", label: "Extensão hover", ftype: "real" },
            { key: "petalFlare", label: "Cantos góticos", ftype: "real" },
            { key: "petalStartDeg", label: "Ângulo inicial", ftype: "real" },
            { key: "petalStepDeg", label: "Passo angular", ftype: "real" },
            { key: "petalDir", label: "Sentido (+1/-1)", ftype: "int" },
            { key: "hitMargin", label: "Folga do hit-test", ftype: "real" },
            { key: "menuMargin", label: "Folga da máscara", ftype: "real" },
            { key: "layoutMenuW", label: "Largura menu layout", ftype: "real" },
            { key: "petalIconSize", label: "Tamanho do ícone", ftype: "int" }
        ]},
        { title: "CAVA", fields: [
            { key: "cavaMaxH", label: "Altura barras", ftype: "real" },
            { key: "cavaRadMax", label: "Raio máx círculo", ftype: "real" },
            { key: "cavaBarFactor", label: "Largura da barra", ftype: "real" },
            { key: "cavaBarsOpacity", label: "Opacidade barras", ftype: "real" },
            { key: "cavaRingOpacity", label: "Opacidade anel", ftype: "real" }
        ]},
        { title: "Áudio", fields: [
            { key: "audioIconSize", label: "Tamanho dos ícones", ftype: "int" },
            { key: "audioBtnMargin", label: "Recuo dos botões", ftype: "real" },
            { key: "audioBtnDarken", label: "Escurecer botão", ftype: "real" },
            { key: "audioBtnHoverDarken", label: "Escurecer hover", ftype: "real" },
            { key: "volStep", label: "Passo do volume", ftype: "real" },
            { key: "sinkVolMax", label: "Volume máx saída", ftype: "real" },
            { key: "sourceVolMax", label: "Volume máx mic", ftype: "real" },
            { key: "audioSliderW", label: "Largura slider", ftype: "real" },
            { key: "audioSliderH", label: "Altura slider", ftype: "real" },
            { key: "audioDevW", label: "Largura dispositivos", ftype: "real" },
            { key: "audioMutedColor", label: "Cor mudo", ftype: "color" },
            { key: "audioSliderBg", label: "Slider fundo", ftype: "color" },
            { key: "audioSliderFill", label: "Slider preench.", ftype: "color" },
            { key: "audioSliderText", label: "Slider texto", ftype: "color" }
        ]},
        { title: "Captura", fields: [
            { key: "captureRecColor", label: "Cor gravando", ftype: "color" }
        ]},
        { title: "Atualizações e clima", fields: [
            { key: "updateInterval", label: "Intervalo updates (ms)", ftype: "int" },
            { key: "weatherInterval", label: "Intervalo clima (ms)", ftype: "int" },
            { key: "weatherLocation", label: "Local do clima", ftype: "string" }
        ]},
        { title: "Bandeja", fields: [
            { key: "trayIconSize", label: "Ícone na pétala", ftype: "int" },
            { key: "trayMenuW", label: "Largura do menu", ftype: "real" },
            { key: "trayMenuRadius", label: "Raio do menu", ftype: "real" },
            { key: "trayMenuPad", label: "Recuo do menu", ftype: "real" },
            { key: "trayMenuRowH", label: "Altura da linha", ftype: "real" },
            { key: "trayMenuRowRadius", label: "Raio da linha", ftype: "real" },
            { key: "trayMenuSepH", label: "Separador", ftype: "real" },
            { key: "trayMenuGap", label: "Folga acima", ftype: "real" },
            { key: "trayMenuTextSize", label: "Texto", ftype: "int" },
            { key: "trayMenuIconSize", label: "Ícone no menu", ftype: "int" },
            { key: "trayMenuAnim", label: "Animação (ms)", ftype: "int" },
            { key: "trayMenuBg", label: "Fundo", ftype: "color" },
            { key: "trayMenuBorder", label: "Borda", ftype: "color" },
            { key: "trayMenuHover", label: "Hover", ftype: "color" },
            { key: "trayMenuText", label: "Texto (cor)", ftype: "color" },
            { key: "trayMenuTextDisabled", label: "Texto desativado", ftype: "color" }
        ]},
        { title: "Notificações", fields: [
            { key: "notifWidth", label: "Largura", ftype: "real" },
            { key: "notifTopMargin", label: "Folga do topo", ftype: "real" },
            { key: "notifSpacing", label: "Espaço entre", ftype: "real" },
            { key: "notifPad", label: "Recuo interno", ftype: "real" },
            { key: "notifRadius", label: "Raio", ftype: "real" },
            { key: "notifTimeout", label: "Auto-dismiss (ms)", ftype: "int" },
            { key: "notifAnim", label: "Animação (ms)", ftype: "int" },
            { key: "notifIconSize", label: "Ícone", ftype: "real" },
            { key: "notifAppSize", label: "Nome do app", ftype: "int" },
            { key: "notifSummarySize", label: "Título", ftype: "int" },
            { key: "notifBodySize", label: "Corpo", ftype: "int" },
            { key: "notifBodyMaxLines", label: "Máx linhas", ftype: "int" },
            { key: "notifBg", label: "Fundo", ftype: "color" },
            { key: "notifBorder", label: "Borda", ftype: "color" },
            { key: "notifAppText", label: "Texto app", ftype: "color" },
            { key: "notifSummary", label: "Título (cor)", ftype: "color" },
            { key: "notifBody", label: "Corpo (cor)", ftype: "color" },
            { key: "notifLow", label: "Urgência baixa", ftype: "color" },
            { key: "notifNormal", label: "Urgência normal", ftype: "color" },
            { key: "notifCritical", label: "Urgência crítica", ftype: "color" }
        ]},
        { title: "Cápsulas do topo", fields: [
            { key: "capsuleW", label: "Largura", ftype: "real" },
            { key: "capsuleH", label: "Altura", ftype: "real" },
            { key: "capsulePeek", label: "Fatia visível", ftype: "real" },
            { key: "capsuleEdge", label: "Margem (0–1)", ftype: "real" },
            { key: "capsuleRadius", label: "Raio", ftype: "real" },
            { key: "capsuleAnim", label: "Animação (ms)", ftype: "int" },
            { key: "capsuleIconSize", label: "Ícone", ftype: "int" },
            { key: "capsuleTextSize", label: "Texto", ftype: "int" },
            { key: "capsuleBg", label: "Fundo", ftype: "color" },
            { key: "capsuleText", label: "Texto (cor)", ftype: "color" }
        ]},
        { title: "Relógio e fontes", fields: [
            { key: "dateFormat", label: "Formato da data", ftype: "string" },
            { key: "timeFormat", label: "Formato da hora", ftype: "string" },
            { key: "clockSideGap", label: "Folga do relógio", ftype: "real" },
            { key: "clockSize", label: "Tamanho relógio", ftype: "int" },
            { key: "ballNumberSize", label: "Nº na bola", ftype: "int" },
            { key: "ballLayoutSize", label: "Layout na bola", ftype: "int" },
            { key: "layoutTextSize", label: "Texto do layout", ftype: "int" }
        ]},
        { title: "Tempos (ms)", fields: [
            { key: "ballAnim", label: "Bola", ftype: "int" },
            { key: "petalRotAnim", label: "Rotação pétalas", ftype: "int" },
            { key: "petalDistAnim", label: "Distância pétalas", ftype: "int" },
            { key: "petalOpacityAnim", label: "Opacidade pétalas", ftype: "int" },
            { key: "petalScaleAnim", label: "Escala pétalas", ftype: "int" },
            { key: "petalRadiusAnim", label: "Raio pétalas", ftype: "int" },
            { key: "petalFlareAnim", label: "Flare pétalas", ftype: "int" },
            { key: "layoutAnim", label: "Layout", ftype: "int" },
            { key: "layoutColorAnim", label: "Cor do layout", ftype: "int" },
            { key: "dotAnim", label: "Pontos", ftype: "int" },
            { key: "clockAnim", label: "Relógio", ftype: "int" },
            { key: "hoverCloseMs", label: "Fechar hover", ftype: "int" },
            { key: "selectMs", label: "Seleção", ftype: "int" }
        ]},
        { title: "Fonte e ícones (glifos)", fields: [
            { key: "iconFont", label: "Fonte dos ícones", ftype: "string" },
            { key: "iconOutput", label: "Saída", ftype: "string" },
            { key: "iconOutputMuted", label: "Saída mudo", ftype: "string" },
            { key: "iconInput", label: "Entrada", ftype: "string" },
            { key: "iconInputMuted", label: "Entrada mudo", ftype: "string" },
            { key: "iconConfig", label: "Config", ftype: "string" },
            { key: "iconScreenshot", label: "Print", ftype: "string" },
            { key: "iconRecord", label: "Gravar", ftype: "string" },
            { key: "iconRecording", label: "Parar", ftype: "string" },
            { key: "iconUpdate", label: "Update", ftype: "string" },
            { key: "iconMango", label: "MangoWC", ftype: "string" },
            { key: "iconTray", label: "Bandeja", ftype: "string" },
            { key: "iconMedia", label: "Mídia", ftype: "string" },
            { key: "iconWeather", label: "Clima", ftype: "string" }
        ]},
        { title: "Comandos (avançado)", fields: [
            { key: "updateCheckCmd", label: "Checar updates", ftype: "string" },
            { key: "updateUpgradeSpawn", label: "Aplicar updates", ftype: "string" },
            { key: "updateMangoSpawn", label: "Atualizar Mango", ftype: "string" }
        ]}
    ]

    // ESC fecha
    Item {
        anchors.fill: parent
        focus: win.visible
        Keys.onEscapePressed: Settings.open = false
    }

    // fundo escurecido (clicar fora fecha)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5
        MouseArea { anchors.fill: parent; onClicked: Settings.open = false }
    }

    // painel central
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 740)
        height: Math.min(parent.height - 80, 720)
        radius: 16
        color: Theme.base
        border.color: Theme.surface0
        border.width: 1
        // engole cliques (não fecha ao clicar dentro)
        MouseArea { anchors.fill: parent }

        // ── Cabeçalho ──
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 52
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: "Configurações do shell"
                color: Theme.text
                font.pixelSize: 17
                font.bold: true
            }
            Text {
                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                text: "✕"
                color: Theme.subtext0
                font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.open = false
                }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.surface0 }
        }

        // ── Conteúdo rolável ──
        Flickable {
            id: flick
            anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: footer.top }
            anchors.margins: 18
            clip: true
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: flick.width
                spacing: 14

                Repeater {
                    model: win.groups
                    delegate: Column {
                        required property var modelData
                        width: content.width
                        spacing: 4

                        Text {
                            text: parent.modelData.title
                            color: Config.accent
                            font.pixelSize: 13
                            font.bold: true
                            bottomPadding: 4
                        }
                        Repeater {
                            model: parent.modelData.fields
                            delegate: SettingsField {
                                required property var modelData
                                width: content.width
                                key: modelData.key
                                label: modelData.label
                                ftype: modelData.ftype
                                options: modelData.options ?? []
                            }
                        }
                    }
                }
            }

            // barra de rolagem fina
            Rectangle {
                visible: flick.contentHeight > flick.height
                anchors { right: parent.right; rightMargin: 2 }
                width: 4; radius: 2
                color: Theme.surface2
                height: flick.height * (flick.height / flick.contentHeight)
                y: (flick.contentHeight > flick.height)
                   ? (flick.contentY / (flick.contentHeight - flick.height)) * (flick.height - height)
                   : 0
            }
        }

        // ── Rodapé (botões) ──
        Item {
            id: footer
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 56
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.surface0 }

            Row {
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                spacing: 10

                // Restaurar padrão
                Rectangle {
                    width: restoreTxt.implicitWidth + 28; height: 32; radius: 8
                    color: Theme.surface0
                    border.color: Theme.surface2; border.width: 1
                    Text { id: restoreTxt; anchors.centerIn: parent; text: "Restaurar padrão"; color: Theme.text; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.reset() }
                }
                // Regenerar temas externos
                Rectangle {
                    width: exportTxt.implicitWidth + 28; height: 32; radius: 8
                    color: Theme.surface0
                    border.color: Theme.surface2; border.width: 1
                    Text { id: exportTxt; anchors.centerIn: parent; text: "Exportar temas"; color: Theme.text; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ThemeExport.exportAll() }
                }
            }

            // Fechar
            Rectangle {
                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                width: closeTxt.implicitWidth + 28; height: 32; radius: 8
                color: Config.accent
                Text { id: closeTxt; anchors.centerIn: parent; text: "Fechar"; color: Theme.crust; font.pixelSize: 12; font.bold: true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.open = false }
            }
        }
    }
}
