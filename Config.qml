pragma Singleton
import Quickshell
import QtQuick

// Configuração central (singleton). Edite aqui para customizar aparência/comportamento
// sem mexer na lógica. Acesse de qualquer componente como `Config.<algo>`.
Singleton {
    id: cfg

    // ── Janela ──────────────────────────────────────────
    readonly property int  shellHeight: 360   // altura da janela do shell (espaço p/ submenu)
    readonly property int  cavaHeight: 260    // altura da janela do cava
    readonly property int  barHeight: 1       // espessura da barra de fundo

    // ── Bola / menu ─────────────────────────────────────
    readonly property real ballRadius: 46
    readonly property real ballPeek: 28        // fatia visível quando recolhida
    readonly property real dotRingFactor: 0.62 // raio do anel de workspaces (× ballRadius)
    readonly property real dotSize: 8          // diâmetro do ponto de workspace
    readonly property real dotActiveSize: 11   // diâmetro do ponto ativo
    readonly property real dotHitR: 9          // raio de clique do ponto
    readonly property real gothicR: 32         // raio dos cantos góticos (bola ↔ barra)

    // ── Pétalas ─────────────────────────────────────────
    readonly property real petalW: 25
    readonly property real petalH: 84
    readonly property real petalGap: 10        // folga bola → pétala
    readonly property real petalShrink: 0.8    // escala das não-hover
    readonly property real petalHoverScale: 1.2
    readonly property real petalHoverExtend: 5 // quanto a pétala em hover estende p/ a bola (px)
    readonly property real petalFlare: 8       // tamanho dos cantos góticos da pétala
    readonly property real petalStartDeg: 180  // ângulo da 1ª pétala (0=dir, 90=topo, 180=esq)
    readonly property real petalStepDeg: 30    // passo entre pétalas (e do scroll)
    readonly property int  petalDir: -1        // sentido do anel (+1 / -1)
    readonly property real hitMargin: 8        // folga radial do hit-test
    readonly property real menuMargin: 16      // folga lateral da máscara quando aberto

    // ── Submenu de layouts ──────────────────────────────
    readonly property real layoutRowH: 23
    readonly property real layoutPillW: 132
    readonly property real layoutBow: 38       // curvatura horizontal (segue a bola)
    readonly property real layoutTilt: 0.34    // inclinação por deslocamento
    readonly property real layoutGap: 8        // folga bola → 1ª opção

    // ── Cava ────────────────────────────────────────────
    readonly property real cavaMaxH: 180       // altura máx das barras lineares
    readonly property real cavaRadMax: 55      // comprimento máx dos espetos radiais
    readonly property real cavaBarFactor: 0.6  // largura da barra (× slot)
    readonly property real cavaBarsOpacity: 0.5
    readonly property real cavaRingOpacity: 0.62

    // ── Áudio (5ª pétala) ───────────────────────────────
    readonly property string iconFont: "Symbols Nerd Font"   // fonte dos ícones (troque pela sua)
    readonly property string iconOutput: ""            // volume (headphone/saída)
    readonly property string iconOutputMuted: ""       // volume mudo
    readonly property string iconInput: ""             // microfone (entrada)
    readonly property string iconInputMuted: ""        // microfone mudo
    readonly property string iconConfig: ""            // engrenagem (config)
    readonly property int    audioIconSize: 17               // tamanho dos ícones (maiores)
    readonly property real   audioBtnMargin: 3               // recuo do painel de botões
    readonly property real   audioBtnDarken: 1.22            // fundo do botão (× mais escuro)
    readonly property real   audioBtnHoverDarken: 1.5        // botão sob o cursor
    readonly property color  audioMutedColor: "#f38ba8"
    readonly property real   volStep: 0.05       // passo do scroll (5%)
    readonly property real   sinkVolMax: 1.5     // headphone até 150%
    readonly property real   sourceVolMax: 1.0   // microfone até 100%
    readonly property real   audioSliderW: 150
    readonly property real   audioSliderH: 22
    readonly property color  audioSliderBg: "#313244"
    readonly property color  audioSliderFill: "#cba6f7"
    readonly property color  audioSliderText: "#cdd6f4"

    // ── Captura (4ª pétala) ─────────────────────────────
    readonly property string iconScreenshot: ""   // câmera (print)
    readonly property string iconRecord: ""       // filmadora (gravar)
    readonly property string iconRecording: ""    // parar (enquanto grava)
    readonly property color  captureRecColor: "#f38ba8" // vermelho enquanto grava

    // ── Bandeja / system tray (7ª pétala) ───────────────
    readonly property string iconTray: "󰀻"       // ícone genérico quando a bandeja está vazia (nf-md-apps)
    readonly property int    trayIconSize: 16     // tamanho dos ícones dos apps na pétala

    // menu estilizado do clique direito (TrayMenu.qml)
    readonly property color  trayMenuBg: "#1e1e2e"
    readonly property color  trayMenuBorder: "#313244"
    readonly property color  trayMenuHover: "#45475a"
    readonly property color  trayMenuText: "#cdd6f4"
    readonly property color  trayMenuTextDisabled: "#6c7086"
    readonly property real   trayMenuW: 220       // largura fixa do menu
    readonly property real   trayMenuRadius: 10
    readonly property real   trayMenuPad: 6       // recuo interno do painel
    readonly property real   trayMenuRowH: 28
    readonly property real   trayMenuRowRadius: 6
    readonly property real   trayMenuSepH: 9      // altura da faixa do separador
    readonly property int    trayMenuTextSize: 13
    readonly property int    trayMenuIconSize: 16 // ícone dentro do menu
    readonly property real   trayMenuGap: 23      // folga acima da pétala (o menu abre pra cima)

    // ── Relógio (data à esquerda da bola, hora à direita) ──
    readonly property string dateFormat: "d/M"
    readonly property string timeFormat: "HH:mm"
    readonly property real   clockSideGap: 40   // distância do centro da bola até a borda interna de cada texto

    // ── Fontes (px) ─────────────────────────────────────
    readonly property int  petalIconSize: 13
    readonly property int  ballNumberSize: 18
    readonly property int  ballLayoutSize: 11
    readonly property int  layoutTextSize: 12
    readonly property int  clockSize: 13

    // ── Cores ───────────────────────────────────────────
    readonly property color ball: "#11111b"
    readonly property color petal: "#eba0ac"
    readonly property color petalHover: "#f38ba8"
    readonly property color petalIcon: "#1e1e2e"
    readonly property color accent: "#cba6f7"
    readonly property color ballText: "#a6e3a1"
    readonly property color clock: "#cdd6f4"
    readonly property color layoutPill: "#313244"
    readonly property color layoutPillHover: "#cba6f7"
    readonly property color layoutText: "#cdd6f4"
    readonly property color layoutTextHover: "#11111b"
    readonly property color dotActive: "#a6e3a1"
    readonly property color dotUrgent: "#f38ba8"
    readonly property color dotOccupied: "#5c7a52"
    readonly property color dotEmpty: "#45475a"

    // ── Tempos (ms) ─────────────────────────────────────
    readonly property int  ballAnim: 220
    readonly property int  petalRotAnim: 220
    readonly property int  petalDistAnim: 200
    readonly property int  petalOpacityAnim: 150
    readonly property int  petalScaleAnim: 130
    readonly property int  petalRadiusAnim: 150
    readonly property int  petalFlareAnim: 160
    readonly property int  layoutAnim: 180
    readonly property int  layoutColorAnim: 120
    readonly property int  dotAnim: 120
    readonly property int  clockAnim: 150
    readonly property int  hoverCloseMs: 130
    readonly property int  selectMs: 200
}
