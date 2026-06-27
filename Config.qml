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
    readonly property real cavaRadMax: 70      // comprimento máx dos espetos radiais (círculo)
    readonly property real cavaBarFactor: 0.6  // largura da barra (× slot)
    readonly property real cavaBarsOpacity: 0.5
    readonly property real cavaRingOpacity: 0.85
    // gradiente radial do círculo (Cavasik): base interna → meio → pontas dos picos
    readonly property color cavaColor1: Theme.blue   // interno (base do espectro)
    readonly property color cavaColor2: Theme.red    // meio
    readonly property color cavaColor3: Theme.green  // pontas (picos altos)

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
    readonly property color  audioMutedColor: Theme.red
    readonly property real   volStep: 0.05       // passo do scroll (5%)
    readonly property real   sinkVolMax: 1.5     // headphone até 150%
    readonly property real   sourceVolMax: 1.0   // microfone até 100%
    readonly property real   audioSliderW: 150
    readonly property real   audioSliderH: 22
    readonly property real   audioDevW: 280      // largura do seletor de dispositivos (direito no áudio)
    readonly property color  audioSliderBg: Theme.surface0
    readonly property color  audioSliderFill: Theme.mauve
    readonly property color  audioSliderText: Theme.text

    // ── Captura (4ª pétala) ─────────────────────────────
    readonly property string iconScreenshot: ""   // câmera (print)
    readonly property string iconRecord: ""       // filmadora (gravar)
    readonly property string iconRecording: ""    // parar (enquanto grava)
    readonly property color  captureRecColor: Theme.red // vermelho enquanto grava

    // ── Atualizações (2ª pétala) ─────────────────────────
    readonly property int    updateInterval: 300000   // checa pacotes a cada 5 min (ms)
    readonly property string iconUpdate: ""          // pacotes (nf-fa-download)
    readonly property string iconMango: ""           // atualizar MangoWC (nf-fa-refresh)
    // checagem (rodada por sh -c, sem terminal): tenta refrescar (sudo -n, não trava) e CONTA.
    // Sem NOPASSWD p/ `apt update`, o refresh é pulado e ele conta a partir das listas atuais.
    readonly property string updateCheckCmd: "sudo -n apt update >/dev/null 2>&1; apt list --upgradable 2>/dev/null | grep -c upgradable"
    // upgrade do sistema: abre um terminal (sudo pede senha aqui). Troque `nala`/`kitty` se quiser.
    readonly property string updateUpgradeSpawn: "kitty -e bash -lc 'sudo nala upgrade || sudo apt upgrade; echo; echo Concluido; read -n1 -s'"
    // build/atualização do MangoWC via script do usuário, num terminal.
    readonly property string updateMangoSpawn: "kitty -e bash -lc '$HOME/.config/mango/scripts/update-mango.sh; echo; echo Concluido; read -n1 -s'"

    // ── Bandeja / system tray (7ª pétala) ───────────────
    readonly property string iconTray: "󰀻"       // ícone genérico quando a bandeja está vazia (nf-md-apps)
    readonly property int    trayIconSize: 16     // tamanho dos ícones dos apps na pétala

    // menu estilizado do clique direito (TrayMenu.qml)
    readonly property color  trayMenuBg: Theme.base
    readonly property color  trayMenuBorder: Theme.surface0
    readonly property color  trayMenuHover: Theme.surface1
    readonly property color  trayMenuText: Theme.text
    readonly property color  trayMenuTextDisabled: Theme.overlay0
    readonly property real   trayMenuW: 220       // largura fixa do menu
    readonly property real   trayMenuRadius: 10
    readonly property real   trayMenuPad: 6       // recuo interno do painel
    readonly property real   trayMenuRowH: 28
    readonly property real   trayMenuRowRadius: 6
    readonly property real   trayMenuSepH: 9      // altura da faixa do separador
    readonly property int    trayMenuTextSize: 13
    readonly property int    trayMenuIconSize: 16 // ícone dentro do menu
    readonly property real   trayMenuGap: 21      // folga acima da pétala (o menu abre pra cima)
    readonly property int    trayMenuAnim: 140    // duração da animação de entrada do menu (ms)

    // ── Notificações (topo-centro da tela) ──────────────
    readonly property real   notifWidth: 360       // largura do toast
    readonly property real   notifTopMargin: 12    // folga do topo da tela
    readonly property real   notifSpacing: 8       // espaço entre toasts
    readonly property real   notifPad: 12          // recuo interno do card
    readonly property real   notifRadius: 14
    readonly property int    notifTimeout: 5000    // auto-dismiss (ms); urgência crítica não some
    readonly property int    notifAnim: 160        // animação de entrada do toast (ms)
    readonly property real   notifIconSize: 38     // ícone do app no toast
    readonly property int    notifAppSize: 11      // tamanho do nome do app
    readonly property int    notifSummarySize: 13  // título (negrito)
    readonly property int    notifBodySize: 12     // corpo
    readonly property int    notifBodyMaxLines: 6  // limite de linhas do corpo
    readonly property color  notifBg: Theme.base
    readonly property color  notifBorder: Theme.surface0
    readonly property color  notifAppText: Theme.subtext0
    readonly property color  notifSummary: Theme.text
    readonly property color  notifBody: Theme.subtext1
    readonly property color  notifLow: Theme.overlay0      // faixa de urgência baixa
    readonly property color  notifNormal: Theme.mauve      // normal (acento)
    readonly property color  notifCritical: Theme.red      // crítica (vermelho)

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

    // ── Cores (semânticas → paleta em Theme.qml) ────────
    readonly property color ball: Theme.crust
    readonly property color petal: Theme.maroon
    readonly property color petalHover: Theme.red
    readonly property color petalIcon: Theme.base
    readonly property color accent: Theme.mauve
    readonly property color ballText: Theme.green
    readonly property color clock: Theme.text
    readonly property color layoutPill: Theme.surface0
    readonly property color layoutPillHover: Theme.mauve
    readonly property color layoutText: Theme.text
    readonly property color layoutTextHover: Theme.crust
    readonly property color dotActive: Theme.green
    readonly property color dotUrgent: Theme.red
    readonly property color dotOccupied: Theme.dimGreen
    readonly property color dotEmpty: Theme.surface1

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
