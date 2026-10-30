pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Ponte local com a aba do YouTube Music no Zen.
//
// O shell sobe services/ytm_bridge.py, que:
//   • lê o zen-sessions.jsonlz4 para saber se já existe uma aba do YTM aberta
//     (mesmo antes do userscript conectar);
//   • guarda o estado publicado pelo userscript (services/ytm_bridge.user.js)
//     e a fila de comandos (play/pause/next/previous/seek/volume).
//
// O userscript é quem fala com o player de verdade. Aqui cuidamos do ciclo do
// processo Python e do polling de /state. Sem a ponte, o MediaService cai no
// MPRIS do Zen (que só controla a Media Session ativa).
Singleton {
    id: root

    readonly property string baseUrl: "http://127.0.0.1:26541"

    property bool available: false      // servidor Python respondeu
    property bool ready: false          // já deu para saber se há aba aberta
    property bool connected: false      // userscript publicando estado
    property bool hasYtmTab: false      // session store do Zen tem aba do YTM
    property int ytmTabCount: 0

    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property bool hasTrack: false
    property bool paused: true
    property real duration: 0
    property real volume: 1
    property real position: 0

    property double _stateAt: 0
    property real _basePosition: 0
    property int _pollFailures: 0
    property bool _polling: false
    property bool _started: false
    property var _requests: []

    function init() {
        if (_started) return
        _started = true
        launchServer()
        pollTimer.start()
        positionTimer.start()
        watchdog.start()
    }

    function launchServer() {
        if (serverProcess.running) return
        // O Python sai com código 0 se já houver outra instância saudável na
        // porta; nesse caso o polling continua falando com ela.
        serverProcess.exec(["python3", Quickshell.shellPath("services/ytm_bridge.py")])
    }

    // ── polling de /state ─────────────────────────────────────────────────────

    function removeRequest(xhr) {
        const index = _requests.indexOf(xhr)
        if (index >= 0) _requests.splice(index, 1)
    }

    function pollState() {
        if (_polling) return
        _polling = true

        const xhr = new XMLHttpRequest()
        _requests.push(xhr)
        let done = false

        function finish(ok, text) {
            if (done) return
            done = true
            removeRequest(xhr)
            _polling = false

            if (ok) {
                handleState(text)
                return
            }

            _pollFailures++
            if (_pollFailures >= 2) {
                available = false
                connected = false
            }
            // Se o Python não estiver disponível, libera o popup para o
            // fallback (MPRIS/abrir a aba) depois de algumas tentativas.
            if (!ready && _pollFailures >= 6) ready = true
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            finish(xhr.status >= 200 && xhr.status < 300, xhr.responseText || "")
        }
        xhr.ontimeout = function() { finish(false, "") }
        xhr.onerror = function() { finish(false, "") }
        xhr.open("GET", baseUrl + "/state")
        xhr.timeout = 1500
        xhr.send()
    }

    function numberOr(value, fallback) {
        const n = Number(value)
        return isFinite(n) ? n : fallback
    }

    function handleState(text) {
        let data
        try {
            data = JSON.parse(text)
        } catch (e) {
            data = null
        }
        if (!data || typeof data !== "object") {
            // Resposta 200 que não é da ponte (ex.: outra coisa na porta).
            _pollFailures++
            if (_pollFailures >= 2) available = false
            if (!ready && _pollFailures >= 6) ready = true
            return
        }

        _pollFailures = 0
        available = true
        ready = true
        connected = data.connected === true
        hasYtmTab = data.hasYtmTab === true
        ytmTabCount = Math.max(0, Math.round(numberOr(data.ytmTabCount, 0)))

        if (!connected) {
            clearState()
            return
        }

        title = typeof data.title === "string" ? data.title : ""
        artist = typeof data.artist === "string" ? data.artist : ""
        artUrl = typeof data.art === "string" ? data.art : ""
        hasTrack = data.hasTrack === true
        paused = data.paused !== false
        duration = Math.max(0, numberOr(data.duration, 0))
        volume = Math.max(0, Math.min(1, numberOr(data.volume, 1)))

        const pos = Math.max(0, numberOr(data.position, 0))
        _basePosition = duration > 0 ? Math.min(pos, duration) : pos
        _stateAt = Date.now()
        updatePosition()
    }

    function clearState() {
        title = ""
        artist = ""
        artUrl = ""
        hasTrack = false
        paused = true
        duration = 0
        volume = 1
        _basePosition = 0
        _stateAt = 0
        position = 0
    }

    // Extrapola a posição entre dois heartbeats para o slider não ficar aos
    // saltos. O userscript manda a posição real a cada ~1 s.
    function updatePosition() {
        if (!connected || paused) {
            position = _basePosition
            return
        }
        const elapsed = _stateAt > 0 ? (Date.now() - _stateAt) / 1000 : 0
        let pos = _basePosition + elapsed
        if (duration > 0) pos = Math.min(pos, duration)
        position = Math.max(0, pos)
    }

    // ── comandos ──────────────────────────────────────────────────────────────

    function sendCommand(cmd, extra) {
        if (!connected) return false

        const payload = { cmd: cmd }
        if (extra) {
            for (const key in extra) payload[key] = extra[key]
        }

        // Atualização otimista: o popup responde na hora; o próximo /state
        // confirma (ou corrige) o estado real.
        if (cmd === "toggle") {
            if (!hasTrack) {
                paused = false
            } else {
                paused = !paused
            }
            _basePosition = position
            _stateAt = Date.now()
            updatePosition()
        } else if (cmd === "play") {
            paused = false
            _basePosition = position
            _stateAt = Date.now()
        } else if (cmd === "pause") {
            paused = true
            _basePosition = position
        } else if (cmd === "seek") {
            const target = numberOr(extra && extra.position, -1)
            if (target >= 0) {
                _basePosition = duration > 0 ? Math.min(duration, target) : target
                _stateAt = Date.now()
                position = _basePosition
            }
        } else if (cmd === "volume") {
            const value = numberOr(extra && extra.volume, -1)
            if (value >= 0) volume = Math.max(0, Math.min(1, value))
        }

        postCommand(payload)
        return true
    }

    function postCommand(payload) {
        const xhr = new XMLHttpRequest()
        _requests.push(xhr)
        let done = false

        function finish() {
            if (done) return
            done = true
            removeRequest(xhr)
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) finish()
        }
        xhr.ontimeout = finish
        xhr.onerror = finish
        xhr.open("POST", baseUrl + "/command")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.timeout = 1500
        xhr.send(JSON.stringify(payload))
    }

    // ── ciclo de vida ─────────────────────────────────────────────────────────

    Process {
        id: serverProcess
        onExited: (exitCode, exitStatus) => {
            // Código 0 = já havia uma instância saudável (outro shell); não
            // insiste. Se morreu de verdade, o watchdog tenta subir de novo.
            if (exitCode !== 0 && !root.available) restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: root.launchServer()
    }

    Timer {
        id: pollTimer
        interval: 500
        repeat: true
        onTriggered: root.pollState()
    }

    Timer {
        id: positionTimer
        interval: 250
        repeat: true
        running: root.connected
        onTriggered: root.updatePosition()
    }

    // Garante que a ponte volte se o processo cair sem derrubar o shell.
    Timer {
        id: watchdog
        interval: 5000
        repeat: true
        running: root._started
        onTriggered: {
            if (!serverProcess.running && !root.available) root.launchServer()
        }
    }

    // Diagnóstico/atalho manual: `qs ipc call ytm status`, `qs ipc call ytm toggle`…
    IpcHandler {
        target: "ytm"
        function play(): void { root.sendCommand("play") }
        function pause(): void { root.sendCommand("pause") }
        function toggle(): void { root.sendCommand("toggle") }
        function next(): void { root.sendCommand("next") }
        function previous(): void { root.sendCommand("previous") }
        function status(): string {
            return JSON.stringify({
                available: root.available,
                connected: root.connected,
                hasYtmTab: root.hasYtmTab,
                hasTrack: root.hasTrack,
                paused: root.paused,
                title: root.title,
                artist: root.artist,
                position: root.position,
                duration: root.duration,
                volume: root.volume
            })
        }
    }
}
