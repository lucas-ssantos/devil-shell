import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/ui"         // SettingsField
import "root:/themes"     // Theme
import "root:/services"   // Settings, ThemeExport
import "root:/"           // Config

// Janela de configurações do shell (cristal de Sistema). Overlay modal no centro da
// tela focada: TODAS as opções do Config + a escolha de paletas + overrides de cor
// crua, organizadas em SEÇÕES por componente (Bola, Cristais, Lançador…). Cada seção
// é recolhível (clique no cabeçalho) e agrupa os campos em subgrupos de
// Posicionamento / Cores / Animações. Barra de rolagem arrastável à direita.
// Grava tudo via Settings (settings.json). Botões para restaurar o padrão e
// regenerar os temas externos (kitty/rofi/vesktop…).
PanelWindow {
    id: win
    property var niri   // NiriService, p/ achar o monitor focado

    visible: Settings.open

    // monitor focado (fallback: o primeiro)
    screen: {
        const list = niri ? (niri.monitors ?? []) : []
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

    // ── Esquema de TODAS as opções ──
    // Uma seção por componente; dentro dela, subgrupos (name: "" = sem subtítulo).
    readonly property var groups: [
        { title: "Tema e paletas", subs: [
            { name: "", fields: [
                { key: "themeShell", label: "Paleta do shell", ftype: "select", options: Theme.paletteNames },
                { key: "themeCava",  label: "Paleta do CAVA",  ftype: "select", options: Theme.paletteNames }
            ]},
            { name: "Base e superfícies", fields: [
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
            { name: "Acentos", fields: [
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
            { name: "CAVA", fields: [
                { key: "pal_cavaInner", label: "cavaInner", ftype: "color" },
                { key: "pal_cavaMid", label: "cavaMid", ftype: "color" },
                { key: "pal_cavaTip", label: "cavaTip", ftype: "color" }
            ]}
        ]},
        { title: "Geral (janela e barra)", subs: [
            { name: "Posicionamento", fields: [
                { key: "shellHeight", label: "Altura do shell", ftype: "int" },
                { key: "barHeight", label: "Altura da barra", ftype: "int" },
                { key: "gothicR", label: "Cantos góticos", ftype: "real" },
                { key: "hitMargin", label: "Folga do hit-test", ftype: "real" },
                { key: "menuMargin", label: "Folga da máscara", ftype: "real" }
            ]},
            { name: "Cores", fields: [
                { key: "accent", label: "Acento", ftype: "color" }
            ]},
            { name: "Animações e tempos", fields: [
                { key: "hoverCloseMs", label: "Fechar hover (ms)", ftype: "int" },
                { key: "selectMs", label: "Seleção (ms)", ftype: "int" }
            ]}
        ]},
        { title: "Bola", subs: [
            { name: "Posicionamento", fields: [
                { key: "ballRadius", label: "Raio da bola", ftype: "real" },
                { key: "ballPeek", label: "Fatia visível", ftype: "real" },
                { key: "ballSigilFactor", label: "Raio do sigilo", ftype: "real" },
                { key: "ballNumberSize", label: "Nº na bola", ftype: "int" }
            ]},
            { name: "Anel de workspaces", fields: [
                { key: "dotRingFactor", label: "Raio do anel", ftype: "real" },
                { key: "dotArcW", label: "Espessura do arco", ftype: "real" },
                { key: "dotArcActiveW", label: "Arco ativo", ftype: "real" },
                { key: "dotArcGapDeg", label: "Vão entre arcos (°)", ftype: "real" },
                { key: "dotArcGapClosedDeg", label: "Vão recolhida (°)", ftype: "real" },
                { key: "dotClosedScale", label: "Escala arcos recolhida", ftype: "real" },
                { key: "dotOpenScale", label: "Escala arcos aberta", ftype: "real" },
                { key: "dotMinCount", label: "Mínimo de workspaces", ftype: "int" },
                { key: "dotHitR", label: "Clique do anel", ftype: "real" }
            ]},
            { name: "Cores", fields: [
                { key: "ball", label: "Bola", ftype: "color" },
                { key: "ballText", label: "Texto da bola", ftype: "color" },
                { key: "ballSigil", label: "Sigilo da bola", ftype: "color" },
                { key: "dotActive", label: "Workspace ativo", ftype: "color" },
                { key: "dotUrgent", label: "Workspace urgente", ftype: "color" },
                { key: "dotOccupied", label: "Workspace ocupado", ftype: "color" },
                { key: "dotEmpty", label: "Workspace vazio", ftype: "color" }
            ]},
            { name: "Animações", fields: [
                { key: "ballAnim", label: "Abrir/fechar (ms)", ftype: "int" },
                { key: "dotTravelMs", label: "Animação do workspace (ms por arco)", ftype: "int" }
            ]}
        ]},
        { title: "Cristais", subs: [
            { name: "Posicionamento", fields: [
                { key: "crystalW", label: "Largura", ftype: "real" },
                { key: "crystalMaxH", label: "Altura junto à bola", ftype: "real" },
                { key: "crystalStepH", label: "Degrau de altura", ftype: "real" },
                { key: "crystalMinH", label: "Altura mínima", ftype: "real" },
                { key: "crystalGap", label: "Folga bola→cristal", ftype: "real" },
                { key: "crystalSpacing", label: "Folga entre cristais", ftype: "real" },
                { key: "crystalPeek", label: "Fatia visível (fechado)", ftype: "real" },
                { key: "crystalHoverScale", label: "Escala hover", ftype: "real" },
                { key: "crystalIconSize", label: "Tamanho do ícone", ftype: "int" },
                { key: "layoutMenuW", label: "Largura menu energia", ftype: "real" }
            ]},
            { name: "Aparência", fields: [
                { key: "crystalCoreFactor", label: "Núcleo do cristal", ftype: "real" },
                { key: "crystalEdgeDarken", label: "Escurecer borda", ftype: "real" },
                { key: "crystalEngraveOpacity", label: "Opacidade entalhes", ftype: "real" },
                { key: "crystalEngraveWidth", label: "Espessura entalhes", ftype: "real" },
                { key: "crystalGlowBlur", label: "Raio do glow", ftype: "real" },
                { key: "crystalGlowRest", label: "Glow em repouso (0–1)", ftype: "real" },
                { key: "crystalPulseMin", label: "Piso do pulso (0–1)", ftype: "real" }
            ]},
            { name: "Cores", fields: [
                { key: "crystal", label: "Cristal", ftype: "color" },
                { key: "crystalHover", label: "Cristal (hover)", ftype: "color" },
                { key: "crystalIcon", label: "Ícone do cristal", ftype: "color" },
                { key: "crystalEngrave", label: "Entalhes do cristal", ftype: "color" },
                { key: "crystalGlow", label: "Glow do cristal", ftype: "color" }
            ]},
            { name: "Animações", fields: [
                { key: "crystalRiseAnim", label: "Emersão (ms)", ftype: "int" },
                { key: "crystalOpacityAnim", label: "Opacidade (ms)", ftype: "int" },
                { key: "crystalScaleAnim", label: "Escala (ms)", ftype: "int" },
                { key: "crystalFillAnim", label: "Subida do brilho (ms)", ftype: "int" },
                { key: "crystalPulseTime", label: "Pulso do glow (ms)", ftype: "int" }
            ]}
        ]},
        { title: "CAVA", subs: [
            { name: "Posicionamento", fields: [
                { key: "cavaHeight", label: "Altura do CAVA", ftype: "int" },
                { key: "cavaMaxH", label: "Altura barras", ftype: "real" },
                { key: "cavaRadMax", label: "Raio máx círculo", ftype: "real" },
                { key: "cavaBarFactor", label: "Largura da barra", ftype: "real" }
            ]},
            { name: "Comportamento", fields: [
                { key: "cavaVisibility", label: "Mostrar com janelas", ftype: "select", options: ["adaptativo", "sempre", "vazio"] },
                { key: "cavaCoverFrac", label: "Fração p/ ocultar", ftype: "real" }
            ]},
            { name: "Cores e opacidade", fields: [
                { key: "cavaBarsOpacity", label: "Opacidade barras", ftype: "real" },
                { key: "cavaRingOpacity", label: "Opacidade anel", ftype: "real" }
            ]}
        ]},
        { title: "Áudio", subs: [
            { name: "Posicionamento", fields: [
                { key: "audioIconSize", label: "Tamanho dos ícones", ftype: "int" },
                { key: "audioBtnMargin", label: "Recuo dos botões", ftype: "real" },
                { key: "audioSliderW", label: "Largura slider", ftype: "real" },
                { key: "audioSliderH", label: "Altura slider", ftype: "real" },
                { key: "audioDevW", label: "Largura dispositivos", ftype: "real" },
                { key: "layoutTextSize", label: "Texto dos sliders", ftype: "int" }
            ]},
            { name: "Volume", fields: [
                { key: "volStep", label: "Passo do volume", ftype: "real" },
                { key: "sinkVolMax", label: "Volume máx saída", ftype: "real" },
                { key: "sourceVolMax", label: "Volume máx mic", ftype: "real" }
            ]},
            { name: "Cores", fields: [
                { key: "audioMutedColor", label: "Cor mudo", ftype: "color" },
                { key: "audioSliderBg", label: "Slider fundo", ftype: "color" },
                { key: "audioSliderFill", label: "Slider preench.", ftype: "color" },
                { key: "audioSliderText", label: "Slider texto", ftype: "color" },
                { key: "audioBtnDarken", label: "Escurecer botão", ftype: "real" },
                { key: "audioBtnHoverDarken", label: "Escurecer hover", ftype: "real" }
            ]},
            { name: "Animações", fields: [
                { key: "layoutAnim", label: "Sliders de áudio (ms)", ftype: "int" }
            ]}
        ]},
        { title: "Lançador", subs: [
            { name: "Posicionamento", fields: [
                { key: "launcherW", label: "Largura", ftype: "real" },
                { key: "launcherListMaxH", label: "Altura máx da lista", ftype: "real" },
                { key: "launcherRowH", label: "Altura da linha", ftype: "real" },
                { key: "launcherRadius", label: "Raio", ftype: "real" },
                { key: "launcherYFactor", label: "Posição vertical (0–1)", ftype: "real" },
                { key: "launcherFontSize", label: "Texto", ftype: "int" },
                { key: "launcherInputSize", label: "Texto da busca", ftype: "int" },
                { key: "launcherIconSize", label: "Ícone", ftype: "int" }
            ]},
            { name: "Comportamento", fields: [
                { key: "launcherTopUsed", label: "Nº de mais usados", ftype: "int" },
                { key: "launcherTerminal", label: "Terminal (apps de texto)", ftype: "string" }
            ]},
            { name: "Cores", fields: [
                { key: "launcherBg", label: "Fundo", ftype: "color" },
                { key: "launcherBorder", label: "Borda", ftype: "color" },
                { key: "launcherSel", label: "Seleção", ftype: "color" },
                { key: "launcherText", label: "Texto (cor)", ftype: "color" },
                { key: "launcherSub", label: "Texto secundário", ftype: "color" }
            ]},
            { name: "Animações", fields: [
                { key: "launcherAnim", label: "Abrir/fechar (ms)", ftype: "int" },
                { key: "launcherResizeAnim", label: "Tamanho (ms)", ftype: "int" }
            ]}
        ]},
        { title: "Bandeja", subs: [
            { name: "Posicionamento", fields: [
                { key: "trayIconSize", label: "Ícone no cristal", ftype: "int" },
                { key: "trayMenuW", label: "Largura do menu", ftype: "real" },
                { key: "trayMenuRadius", label: "Raio do menu", ftype: "real" },
                { key: "trayMenuPad", label: "Recuo do menu", ftype: "real" },
                { key: "trayMenuRowH", label: "Altura da linha", ftype: "real" },
                { key: "trayMenuRowRadius", label: "Raio da linha", ftype: "real" },
                { key: "trayMenuSepH", label: "Separador", ftype: "real" },
                { key: "trayMenuGap", label: "Folga acima", ftype: "real" },
                { key: "trayMenuTextSize", label: "Texto", ftype: "int" },
                { key: "trayMenuIconSize", label: "Ícone no menu", ftype: "int" }
            ]},
            { name: "Cores", fields: [
                { key: "trayMenuBg", label: "Fundo", ftype: "color" },
                { key: "trayMenuBorder", label: "Borda", ftype: "color" },
                { key: "trayMenuHover", label: "Hover", ftype: "color" },
                { key: "trayMenuText", label: "Texto (cor)", ftype: "color" },
                { key: "trayMenuTextDisabled", label: "Texto desativado", ftype: "color" }
            ]},
            { name: "Animações", fields: [
                { key: "trayMenuAnim", label: "Menu (ms)", ftype: "int" }
            ]}
        ]},
        { title: "Notificações", subs: [
            { name: "Posicionamento", fields: [
                { key: "notifWidth", label: "Largura", ftype: "real" },
                { key: "notifTopMargin", label: "Folga do topo", ftype: "real" },
                { key: "notifSpacing", label: "Espaço entre", ftype: "real" },
                { key: "notifPad", label: "Recuo interno", ftype: "real" },
                { key: "notifRadius", label: "Raio", ftype: "real" },
                { key: "notifIconSize", label: "Ícone", ftype: "real" },
                { key: "notifAppSize", label: "Nome do app", ftype: "int" },
                { key: "notifSummarySize", label: "Título", ftype: "int" },
                { key: "notifBodySize", label: "Corpo", ftype: "int" },
                { key: "notifBodyMaxLines", label: "Máx linhas", ftype: "int" }
            ]},
            { name: "Comportamento", fields: [
                { key: "notifTimeout", label: "Auto-dismiss (ms)", ftype: "int" }
            ]},
            { name: "Cores", fields: [
                { key: "notifBg", label: "Fundo", ftype: "color" },
                { key: "notifBorder", label: "Borda", ftype: "color" },
                { key: "notifAppText", label: "Texto app", ftype: "color" },
                { key: "notifSummary", label: "Título (cor)", ftype: "color" },
                { key: "notifBody", label: "Corpo (cor)", ftype: "color" },
                { key: "notifLow", label: "Urgência baixa", ftype: "color" },
                { key: "notifNormal", label: "Urgência normal", ftype: "color" },
                { key: "notifCritical", label: "Urgência crítica", ftype: "color" }
            ]},
            { name: "Animações", fields: [
                { key: "notifAnim", label: "Entrada/saída (ms)", ftype: "int" }
            ]}
        ]},
        { title: "Cápsulas do topo", subs: [
            { name: "Posicionamento", fields: [
                { key: "capsuleW", label: "Largura", ftype: "real" },
                { key: "capsuleH", label: "Altura", ftype: "real" },
                { key: "capsulePeek", label: "Fatia visível", ftype: "real" },
                { key: "capsuleEdge", label: "Margem (0–1)", ftype: "real" },
                { key: "capsuleRadius", label: "Raio", ftype: "real" },
                { key: "capsuleIconSize", label: "Ícone", ftype: "int" },
                { key: "capsuleTextSize", label: "Texto", ftype: "int" }
            ]},
            { name: "Cores", fields: [
                { key: "capsuleBg", label: "Fundo", ftype: "color" },
                { key: "capsuleText", label: "Texto (cor)", ftype: "color" }
            ]},
            { name: "Animações", fields: [
                { key: "capsuleAnim", label: "Retrair/estender (ms)", ftype: "int" }
            ]}
        ]},
        { title: "Relógio", subs: [
            { name: "Formato", fields: [
                { key: "dateFormat", label: "Formato da data", ftype: "string" },
                { key: "timeFormat", label: "Formato da hora", ftype: "string" }
            ]},
            { name: "Posicionamento", fields: [
                { key: "clockSideGap", label: "Folga do relógio", ftype: "real" },
                { key: "clockSize", label: "Tamanho relógio", ftype: "int" }
            ]},
            { name: "Cores", fields: [
                { key: "clock", label: "Relógio", ftype: "color" }
            ]},
            { name: "Animações", fields: [
                { key: "clockAnim", label: "Relógio (ms)", ftype: "int" }
            ]}
        ]},
        { title: "Gravação", subs: [
            { name: "Cores", fields: [
                { key: "captureRecColor", label: "Cor gravando", ftype: "color" }
            ]}
        ]},
        { title: "Papel de parede", subs: [
            { name: "", fields: [
                { key: "wallpaperDir", label: "Pasta dos wallpapers", ftype: "string" },
                { key: "wallpaperDefault", label: "Wallpaper padrão", ftype: "string" },
                { key: "wallpaperMode", label: "Ajuste (swaybg)", ftype: "select", options: ["fill","fit","stretch","center","tile"] },
                { key: "wallpaperCarousel", label: "Carrossel automático", ftype: "bool" },
                { key: "wallpaperCarouselMin", label: "Intervalo do carrossel (min)", ftype: "int" }
            ]}
        ]},
        { title: "Clima", subs: [
            { name: "", fields: [
                { key: "weatherInterval", label: "Intervalo clima (ms)", ftype: "int" },
                { key: "weatherLocation", label: "Local do clima", ftype: "string" }
            ]}
        ]},
        { title: "Fonte e ícones (glifos)", subs: [
            { name: "", fields: [
                { key: "iconFont", label: "Fonte dos ícones", ftype: "string" },
                { key: "iconOutput", label: "Saída", ftype: "string" },
                { key: "iconOutputMuted", label: "Saída mudo", ftype: "string" },
                { key: "iconInput", label: "Entrada", ftype: "string" },
                { key: "iconInputMuted", label: "Entrada mudo", ftype: "string" },
                { key: "iconConfig", label: "Config", ftype: "string" },
                { key: "iconRecord", label: "Gravar", ftype: "string" },
                { key: "iconRecording", label: "Parar", ftype: "string" },
                { key: "iconTray", label: "Bandeja", ftype: "string" },
                { key: "iconMedia", label: "Mídia", ftype: "string" },
                { key: "iconWeather", label: "Clima", ftype: "string" }
            ]}
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
            anchors.rightMargin: 24     // deixa espaço p/ a barra de rolagem
            clip: true
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            // recolher uma seção pode encolher o conteúdo além do scroll atual
            onContentHeightChanged: returnToBounds()

            Column {
                id: content
                width: flick.width
                spacing: 8

                Repeater {
                    model: win.groups
                    delegate: Column {
                        id: sec
                        required property var modelData
                        property bool expanded: false
                        width: content.width
                        spacing: 0

                        // nº de opções e de overrides ativos (Settings.data p/ reavaliar)
                        readonly property int nOpts: modelData.subs.reduce((n, s) => n + s.fields.length, 0)
                        readonly property int nOver: { Settings.data; return modelData.subs.reduce(
                            (n, s) => n + s.fields.filter(f => Settings.has(f.key)).length, 0) }

                        // cabeçalho da seção (clique abre/recolhe)
                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: 8
                            color: headArea.containsMouse ? Theme.surface0 : Theme.mantle
                            border.color: Theme.surface0
                            border.width: 1

                            Text {
                                id: chev
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                text: "▸"
                                rotation: sec.expanded ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                color: Config.accent
                                font.pixelSize: 12
                            }
                            Text {
                                anchors { left: chev.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                text: sec.modelData.title
                                color: Theme.text
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                text: sec.nOver > 0
                                      ? sec.nOver + " alterada" + (sec.nOver > 1 ? "s" : "") + " · " + sec.nOpts + " opções"
                                      : sec.nOpts + " opções"
                                color: sec.nOver > 0 ? Config.accent : Theme.overlay1
                                font.pixelSize: 11
                            }
                            MouseArea {
                                id: headArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sec.expanded = !sec.expanded
                            }
                        }

                        // corpo recolhível (clip + altura animada)
                        Item {
                            width: parent.width
                            height: sec.expanded ? body.implicitHeight + 14 : 0
                            clip: true
                            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Column {
                                id: body
                                y: 8
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: sec.modelData.subs
                                    delegate: Column {
                                        id: sub
                                        required property var modelData
                                        width: body.width
                                        spacing: 4

                                        Text {
                                            visible: sub.modelData.name !== ""
                                            text: sub.modelData.name
                                            color: Config.accent
                                            font.pixelSize: 11
                                            font.bold: true
                                            topPadding: 8
                                            leftPadding: 4
                                        }
                                        Repeater {
                                            model: sub.modelData.fields
                                            delegate: SettingsField {
                                                required property var modelData
                                                x: 8
                                                width: body.width - 8
                                                key: modelData.key
                                                label: modelData.label
                                                ftype: modelData.ftype
                                                options: modelData.options ?? []
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

        // ── Barra de rolagem (arrastável; clique no trilho salta) ──
        Item {
            id: sbar
            anchors { top: flick.top; bottom: flick.bottom; right: parent.right; rightMargin: 8 }
            width: 8
            visible: flick.contentHeight > flick.height

            Rectangle {   // trilho
                anchors.fill: parent
                radius: 4
                color: Theme.surface0
                opacity: 0.5
            }
            Rectangle {   // pegador
                id: handle
                width: parent.width
                radius: 4
                color: sbarArea.pressed ? Config.accent
                     : sbarArea.containsMouse ? Theme.overlay1 : Theme.surface2
                height: Math.max(30, sbar.height * flick.height / Math.max(1, flick.contentHeight))
                y: flick.contentHeight > flick.height
                   ? (flick.contentY / (flick.contentHeight - flick.height)) * (sbar.height - height)
                   : 0
            }
            MouseArea {
                id: sbarArea
                anchors.fill: parent
                anchors.margins: -4     // alvo de clique um pouco maior que a barra
                hoverEnabled: true
                property real grabOff: 0
                onPressed: (m) => {
                    const my = m.y - 4   // compensa o margins negativo
                    // no pegador: arrasta a partir do ponto agarrado; no trilho: centraliza
                    grabOff = (my >= handle.y && my <= handle.y + handle.height)
                              ? my - handle.y : handle.height / 2
                    drag(my)
                }
                onPositionChanged: (m) => { if (pressed) drag(m.y - 4) }
                function drag(my) {
                    const track = sbar.height - handle.height
                    if (track <= 0) return
                    const frac = Math.max(0, Math.min(1, (my - grabOff) / track))
                    flick.contentY = frac * (flick.contentHeight - flick.height)
                }
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
