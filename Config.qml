pragma Singleton
import Quickshell
import QtQuick
import "root:/themes"     // Theme (paleta ativa); subpasta -> precisa de import explícito
import "root:/services"   // Settings (overrides do usuário, da janela de configurações)

// Configuração central (singleton). Os valores literais abaixo são os PADRÕES; cada
// um pode ser sobrescrito em runtime pela janela de configurações (3º cristal), que
// grava em ~/.config/quickshell/settings.json via Settings. A regra é sempre:
//   readonly property <t> nome: Settings.get("nome", <padrão>)
// Assim, sem override, vale o padrão; "Restaurar padrão" só apaga os overrides.
// As cores semânticas caem em Theme.<cor> (a paleta escolhida + overrides pal_*).
Singleton {
    id: cfg

    // ── Janela ──────────────────────────────────────────
    readonly property int  shellHeight: Settings.get("shellHeight", 360)   // altura da janela do shell (espaço p/ submenu)
    readonly property int  cavaHeight: Settings.get("cavaHeight", 260)     // altura da janela do cava
    readonly property int  barHeight: Settings.get("barHeight", 1)         // espessura da barra de fundo

    // ── Bola / menu ─────────────────────────────────────
    readonly property real ballRadius: Settings.get("ballRadius", 46)
    readonly property real ballPeek: Settings.get("ballPeek", 28)               // fatia visível quando recolhida
    readonly property real dotRingFactor: Settings.get("dotRingFactor", 0.74)   // raio do anel tracejado de workspaces (× ballRadius)
    readonly property real dotArcW: Settings.get("dotArcW", 3)                  // espessura do arco de workspace
    readonly property real dotArcActiveW: Settings.get("dotArcActiveW", 5)      // espessura do arco do workspace ativo
    readonly property real dotArcGapDeg: Settings.get("dotArcGapDeg", 14)       // vão entre os arcos do anel (graus)
    readonly property real dotHitR: Settings.get("dotHitR", 9)                  // meia-banda radial de clique do anel
    readonly property real ballSigilFactor: Settings.get("ballSigilFactor", 0.52) // raio do sigilo gravado na bola (× ballRadius)
    readonly property real gothicR: Settings.get("gothicR", 32)                 // raio dos cantos góticos (bola ↔ barra)

    // ── Cristais (runa) ─────────────────────────────────
    readonly property real crystalW: Settings.get("crystalW", 32)
    readonly property real crystalH: Settings.get("crystalH", 96)
    readonly property real crystalGap: Settings.get("crystalGap", -2)                  // folga bola → cristal (negativa = base enfiada sob a bola, cristal "anexado")
    readonly property real crystalCoreFactor: Settings.get("crystalCoreFactor", 0.6)   // largura do núcleo do cristal (× crystalW)
    readonly property real crystalEdgeDarken: Settings.get("crystalEdgeDarken", 1.5)   // borda do cristal (× mais escura que o corpo)
    readonly property real crystalEngraveOpacity: Settings.get("crystalEngraveOpacity", 0.55) // opacidade dos entalhes rúnicos
    readonly property real crystalEngraveWidth: Settings.get("crystalEngraveWidth", 1) // espessura dos entalhes (px)
    readonly property real crystalGlowBlur: Settings.get("crystalGlowBlur", 12)        // raio do glow do cristal (px; hover = cheio)
    readonly property real crystalGlowRest: Settings.get("crystalGlowRest", 0.25)      // intensidade do glow em repouso (0–1)
    readonly property real crystalPulseMin: Settings.get("crystalPulseMin", 0.72)      // piso do pulso do glow no hover (0–1; 1 = sem pulso)
    readonly property real crystalShrink: Settings.get("crystalShrink", 0.8)           // escala dos não-hover
    readonly property real crystalHoverScale: Settings.get("crystalHoverScale", 1.2)
    readonly property real crystalHoverExtend: Settings.get("crystalHoverExtend", 0)   // quanto o cristal em hover estende p/ a bola (px; c/ base já sob a bola, 0 evita afundar os botões)
    readonly property real crystalStartDeg: Settings.get("crystalStartDeg", 90)        // CENTRO do leque (90=topo); os cristais abrem simétricos a partir daqui
    readonly property real crystalStepDeg: Settings.get("crystalStepDeg", 30)          // passo entre cristais (e do scroll)
    readonly property int  crystalDir: Settings.get("crystalDir", -1)                  // sentido do leque (+1 / -1)
    readonly property real hitMargin: Settings.get("hitMargin", 8)                 // folga radial do hit-test
    readonly property real menuMargin: Settings.get("menuMargin", 16)              // folga lateral da máscara quando aberto

    // ── Popup de energia (cristal de Sistema) ───────────
    readonly property real layoutMenuW: Settings.get("layoutMenuW", 200)   // largura do popup de energia

    // ── Cava ────────────────────────────────────────────
    readonly property real cavaMaxH: Settings.get("cavaMaxH", 180)              // altura máx das barras lineares
    readonly property real cavaRadMax: Settings.get("cavaRadMax", 70)           // comprimento máx dos espetos radiais (círculo)
    readonly property real cavaBarFactor: Settings.get("cavaBarFactor", 0.6)    // largura da barra (× slot)
    readonly property real cavaBarsOpacity: Settings.get("cavaBarsOpacity", 0.5)
    readonly property real cavaRingOpacity: Settings.get("cavaRingOpacity", 0.85)
    // Visualizador CAVA usa o tema 'cava' do Theme.qml, de propósito diferente do resto
    // do shell. O espectro vem de Theme.cava* (interno → meio → pontas).
    readonly property color cavaColor1: Theme.cavaInner   // interno (base do espectro)
    readonly property color cavaColor2: Theme.cavaMid     // meio
    readonly property color cavaColor3: Theme.cavaTip     // pontas (picos altos, ethereal)
    readonly property color cavaWave:   Theme.cavaMid     // área das ondas lineares (CavaBars)

    // ── Áudio (cristal de áudio) ─────────────────────────
    readonly property string iconFont: Settings.get("iconFont", "JetBrainsMono Nerd Font")   // fonte dos ícones (tem os glifos + logos de distro)
    readonly property string iconOutput: Settings.get("iconOutput", "")            // volume (headphone/saída)
    readonly property string iconOutputMuted: Settings.get("iconOutputMuted", "")  // volume mudo
    readonly property string iconInput: Settings.get("iconInput", "")              // microfone (entrada)
    readonly property string iconInputMuted: Settings.get("iconInputMuted", "")    // microfone mudo
    readonly property string iconConfig: Settings.get("iconConfig", "")            // engrenagem (config)
    readonly property string iconIdle: Settings.get("iconIdle", "")     // lâmpada (nf-fa-lightbulb_o) — toggle de inibir lock/idle
    readonly property color  idleOnColor: Settings.get("idleOnColor", Theme.peach)   // lâmpada "acesa" (idle inibido = tela fica acordada)
    readonly property int    audioIconSize: Settings.get("audioIconSize", 17)            // tamanho dos ícones
    readonly property real   audioBtnMargin: Settings.get("audioBtnMargin", 3)           // recuo do painel de botões
    readonly property real   audioBtnDarken: Settings.get("audioBtnDarken", 1.22)        // fundo do botão (× mais escuro)
    readonly property real   audioBtnHoverDarken: Settings.get("audioBtnHoverDarken", 1.5)  // botão sob o cursor
    readonly property color  audioMutedColor: Settings.get("audioMutedColor", Theme.red)
    readonly property real   volStep: Settings.get("volStep", 0.05)        // passo do scroll (5%)
    readonly property real   sinkVolMax: Settings.get("sinkVolMax", 1.5)   // headphone até 150%
    readonly property real   sourceVolMax: Settings.get("sourceVolMax", 1.0)  // microfone até 100%
    readonly property real   audioSliderW: Settings.get("audioSliderW", 150)
    readonly property real   audioSliderH: Settings.get("audioSliderH", 22)
    readonly property real   audioDevW: Settings.get("audioDevW", 280)     // largura do seletor de dispositivos
    readonly property color  audioSliderBg: Settings.get("audioSliderBg", Theme.surface0)
    readonly property color  audioSliderFill: Settings.get("audioSliderFill", Theme.mauve)
    readonly property color  audioSliderText: Settings.get("audioSliderText", Theme.text)

    // ── Gravação de tela (cristal de Sistema) ────────
    readonly property string iconRecord: Settings.get("iconRecord", "")           // filmadora (gravar)
    readonly property string iconRecording: Settings.get("iconRecording", "")     // parar (enquanto grava)
    readonly property color  captureRecColor: Settings.get("captureRecColor", Theme.red)  // vermelho enquanto grava (cristal de Sistema)

    // ── Bandeja / system tray (cristal da bandeja) ───────
    readonly property string iconTray: Settings.get("iconTray", "󰀻")       // ícone genérico quando a bandeja está vazia
    readonly property int    trayIconSize: Settings.get("trayIconSize", 16)     // tamanho dos ícones dos apps no cristal

    // menu estilizado do clique direito (TrayMenu.qml)
    readonly property color  trayMenuBg: Settings.get("trayMenuBg", Theme.base)
    readonly property color  trayMenuBorder: Settings.get("trayMenuBorder", Theme.surface0)
    readonly property color  trayMenuHover: Settings.get("trayMenuHover", Theme.surface1)
    readonly property color  trayMenuText: Settings.get("trayMenuText", Theme.text)
    readonly property color  trayMenuTextDisabled: Settings.get("trayMenuTextDisabled", Theme.overlay0)
    readonly property real   trayMenuW: Settings.get("trayMenuW", 220)       // largura fixa do menu
    readonly property real   trayMenuRadius: Settings.get("trayMenuRadius", 10)
    readonly property real   trayMenuPad: Settings.get("trayMenuPad", 6)       // recuo interno do painel
    readonly property real   trayMenuRowH: Settings.get("trayMenuRowH", 28)
    readonly property real   trayMenuRowRadius: Settings.get("trayMenuRowRadius", 6)
    readonly property real   trayMenuSepH: Settings.get("trayMenuSepH", 9)      // altura da faixa do separador
    readonly property int    trayMenuTextSize: Settings.get("trayMenuTextSize", 13)
    readonly property int    trayMenuIconSize: Settings.get("trayMenuIconSize", 16) // ícone dentro do menu
    readonly property real   trayMenuGap: Settings.get("trayMenuGap", 21)      // folga acima do cristal (o menu abre pra cima)
    readonly property int    trayMenuAnim: Settings.get("trayMenuAnim", 140)    // duração da animação de entrada do menu (ms)

    // ── Lançador (janela própria; substitui o rofi) ─────
    readonly property real   launcherW: Settings.get("launcherW", 640)              // largura do painel
    readonly property real   launcherListMaxH: Settings.get("launcherListMaxH", 420) // teto da lista (rola além disso)
    readonly property real   launcherRowH: Settings.get("launcherRowH", 44)         // altura de cada resultado
    readonly property real   launcherRadius: Settings.get("launcherRadius", 16)
    readonly property real   launcherYFactor: Settings.get("launcherYFactor", 0.16) // posição vertical (fração da tela)
    readonly property int    launcherAnim: Settings.get("launcherAnim", 170)        // animação de abrir/fechar (ms)
    readonly property int    launcherResizeAnim: Settings.get("launcherResizeAnim", 150) // animação de crescer/encolher da lista (ms)
    readonly property int    launcherFontSize: Settings.get("launcherFontSize", 13)
    readonly property int    launcherInputSize: Settings.get("launcherInputSize", 16) // texto do campo de busca
    readonly property int    launcherIconSize: Settings.get("launcherIconSize", 24)  // ícone/miniatura das linhas
    readonly property int    launcherTopUsed: Settings.get("launcherTopUsed", 6)     // nº de "mais usados" no topo
    readonly property string launcherTerminal: Settings.get("launcherTerminal", "kitty") // p/ .desktop Terminal=true
    readonly property color  launcherBg: Settings.get("launcherBg", Theme.base)
    readonly property color  launcherBorder: Settings.get("launcherBorder", Theme.surface0)
    readonly property color  launcherSel: Settings.get("launcherSel", Theme.surface1)   // linha selecionada
    readonly property color  launcherText: Settings.get("launcherText", Theme.text)
    readonly property color  launcherSub: Settings.get("launcherSub", Theme.subtext0)   // texto secundário/dicas

    // ── Papel de parede (modo /bg do lançador; swaybg) ──
    readonly property string wallpaperDir: Settings.get("wallpaperDir", Quickshell.env("HOME") + "/Pictures/Wallpapers")  // pasta varrida pelo /bg
    readonly property string wallpaperDefault: Settings.get("wallpaperDefault", Quickshell.env("HOME") + "/Pictures/Wallpapers/vigna/vigna.jpg")  // sem escolha salva
    readonly property string wallpaperMode: Settings.get("wallpaperMode", "fill")   // ajuste do swaybg (-m): fill|fit|stretch|center|tile
    readonly property bool   wallpaperCarousel: Settings.get("wallpaperCarousel", false)   // troca automática periódica
    readonly property int    wallpaperCarouselMin: Settings.get("wallpaperCarouselMin", 10)  // intervalo do carrossel (minutos)

    // ── Notificações (topo-centro da tela) ──────────────
    readonly property real   notifWidth: Settings.get("notifWidth", 360)       // largura do toast
    readonly property real   notifTopMargin: Settings.get("notifTopMargin", 12)    // folga do topo da tela
    readonly property real   notifSpacing: Settings.get("notifSpacing", 8)       // espaço entre toasts
    readonly property real   notifPad: Settings.get("notifPad", 12)          // recuo interno do card
    readonly property real   notifRadius: Settings.get("notifRadius", 14)
    readonly property int    notifTimeout: Settings.get("notifTimeout", 5000)    // auto-dismiss (ms); urgência crítica não some
    readonly property int    notifAnim: Settings.get("notifAnim", 160)       // animação de entrada do toast (ms)
    readonly property real   notifIconSize: Settings.get("notifIconSize", 38)     // ícone do app no toast
    readonly property int    notifAppSize: Settings.get("notifAppSize", 11)      // tamanho do nome do app
    readonly property int    notifSummarySize: Settings.get("notifSummarySize", 13)  // título (negrito)
    readonly property int    notifBodySize: Settings.get("notifBodySize", 12)     // corpo
    readonly property int    notifBodyMaxLines: Settings.get("notifBodyMaxLines", 6)  // limite de linhas do corpo
    readonly property color  notifBg: Settings.get("notifBg", Theme.base)
    readonly property color  notifBorder: Settings.get("notifBorder", Theme.surface0)
    readonly property color  notifAppText: Settings.get("notifAppText", Theme.subtext0)
    readonly property color  notifSummary: Settings.get("notifSummary", Theme.text)
    readonly property color  notifBody: Settings.get("notifBody", Theme.subtext1)
    readonly property color  notifLow: Settings.get("notifLow", Theme.overlay0)      // faixa de urgência baixa
    readonly property color  notifNormal: Settings.get("notifNormal", Theme.mauve)      // normal (acento)
    readonly property color  notifCritical: Settings.get("notifCritical", Theme.red)      // crítica (vermelho)

    // ── Cápsulas do topo (mídia à esquerda, clima à direita) ──
    readonly property real   capsuleW: Settings.get("capsuleW", 200)         // largura da cápsula
    readonly property real   capsuleH: Settings.get("capsuleH", 32)          // altura (quando estendida)
    readonly property real   capsulePeek: Settings.get("capsulePeek", 6)        // fatia visível quando retraída
    readonly property real   capsuleEdge: Settings.get("capsuleEdge", 0.10)     // distância das margens (10%)
    readonly property real   capsuleRadius: Settings.get("capsuleRadius", 12)     // cantos inferiores
    readonly property int    capsuleAnim: Settings.get("capsuleAnim", 200)      // animação de descida (ms)
    readonly property int    capsuleIconSize: Settings.get("capsuleIconSize", 14)
    readonly property int    capsuleTextSize: Settings.get("capsuleTextSize", 12)
    readonly property color  capsuleBg: Settings.get("capsuleBg", Theme.base)
    readonly property color  capsuleText: Settings.get("capsuleText", Theme.text)
    readonly property string iconMedia: Settings.get("iconMedia", "")   // nota musical (nf-fa-music)
    readonly property string iconWeather: Settings.get("iconWeather", "") // termômetro (nf-weather-thermometer)

    // ── Clima (cápsula direita) ─────────────────────────
    readonly property string weatherLocation: Settings.get("weatherLocation", "")   // local p/ wttr.in; VAZIO = auto por IP
    readonly property int    weatherInterval: Settings.get("weatherInterval", 1800000)  // atualiza a cada 30 min (ms)

    // ── Relógio (data à esquerda da bola, hora à direita) ──
    readonly property string dateFormat: Settings.get("dateFormat", "d/M")
    readonly property string timeFormat: Settings.get("timeFormat", "HH:mm")
    readonly property real   clockSideGap: Settings.get("clockSideGap", 40)   // distância do centro da bola até a borda interna de cada texto

    // ── Fontes (px) ─────────────────────────────────────
    readonly property int  crystalIconSize: Settings.get("crystalIconSize", 13)
    readonly property int  ballNumberSize: Settings.get("ballNumberSize", 18)
    readonly property int  layoutTextSize: Settings.get("layoutTextSize", 12)   // texto dos sliders de áudio
    readonly property int  clockSize: Settings.get("clockSize", 13)

    // ── Cores (semânticas → paleta em Theme.qml; override por nome do componente) ──
    readonly property color ball: Settings.get("ball", Theme.crust)
    readonly property color crystal: Settings.get("crystal", Theme.maroon)
    readonly property color crystalHover: Settings.get("crystalHover", Theme.red)
    readonly property color crystalIcon: Settings.get("crystalIcon", Theme.rosewater)   // ícones claros ("branco" da paleta)
    readonly property color crystalEngrave: Settings.get("crystalEngrave", Theme.mauve)  // entalhes rúnicos do cristal (nervura/arcos)
    readonly property color crystalGlow: Settings.get("crystalGlow", Theme.red)          // glow do cristal (forte no hover)
    readonly property color accent: Settings.get("accent", Theme.mauve)
    readonly property color ballText: Settings.get("ballText", Theme.red)          // nº do workspace
    readonly property color ballSigil: Settings.get("ballSigil", Theme.dimGreen)   // sigilo (pentáculo) gravado na bola
    readonly property color clock: Settings.get("clock", Theme.text)
    readonly property color dotActive: Settings.get("dotActive", Theme.red)         // arco do workspace atual
    readonly property color dotUrgent: Settings.get("dotUrgent", Theme.peach)        // urgente
    readonly property color dotOccupied: Settings.get("dotOccupied", Theme.maroon)    // ocupado
    readonly property color dotEmpty: Settings.get("dotEmpty", Theme.surface1)     // vazio

    // ── Tempos (ms) ─────────────────────────────────────
    readonly property int  ballAnim: Settings.get("ballAnim", 220)
    readonly property int  crystalRotAnim: Settings.get("crystalRotAnim", 220)
    readonly property int  crystalDistAnim: Settings.get("crystalDistAnim", 200)
    readonly property int  crystalOpacityAnim: Settings.get("crystalOpacityAnim", 150)
    readonly property int  crystalScaleAnim: Settings.get("crystalScaleAnim", 130)
    readonly property int  crystalFillAnim: Settings.get("crystalFillAnim", 340)      // subida do brilho base→ponta no hover
    readonly property int  crystalPulseTime: Settings.get("crystalPulseTime", 620)    // meio-período do pulso do glow no hover
    readonly property int  layoutAnim: Settings.get("layoutAnim", 180)   // sliders de áudio
    readonly property int  clockAnim: Settings.get("clockAnim", 150)
    readonly property int  hoverCloseMs: Settings.get("hoverCloseMs", 130)
    readonly property int  selectMs: Settings.get("selectMs", 200)
}
