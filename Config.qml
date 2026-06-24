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

    // ── Relógio ─────────────────────────────────────────
    readonly property string clockFormat: "d/M HH:mm"

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
