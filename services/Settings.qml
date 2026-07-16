pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Armazenamento de configurações do usuário (singleton). Guarda APENAS os
// "overrides" — o que o usuário mudou na janela de configurações — num JSON em
// ~/.config/quickshell/settings.json. Tudo que não estiver aqui cai no padrão
// (os valores literais do Config.qml / a paleta escolhida no Theme.qml).
//
//   • get(chave, padrão) -> valor efetivo (override OU padrão)
//   • set(chave, valor)  -> grava o override (persiste + dispara export se for cor/tema)
//   • unset(chave)       -> remove UMA chave (volta ao literal do código)
//   • revert(chave)      -> volta UMA chave ao padrão de fábrica (snapshot, senão remove)
//   • reset()            -> volta TUDO ao padrão (recarrega o settings.default.json)
//   • makeDefault()      -> torna os overrides atuais o novo padrão (com backup do anterior)
//   • isOverridden(ch)   -> a chave difere do padrão de fábrica? (alimenta o aviso ↺ da UI)
//
// Chaves de cor da PALETA crua usam prefixo "pal_" (ex.: pal_crust) e são lidas
// pelo Theme.qml. Chaves "themeShell"/"themeCava" escolhem a paleta. As demais
// chaves batem com o nome da property no Config.qml (ex.: shellHeight, ballRadius…).
Singleton {
    id: root

    // Estado da janela de configurações (a 3º cristal liga isto).
    property bool open: false

    // Mapa de overrides (chave -> valor). Reatribuído inteiro a cada mudança para
    // que os bindings de Config/Theme que leem get() reavaliem.
    property var data: ({})

    // Snapshot do padrão de fábrica (settings.default.json) mantido em memória.
    // Reatribuído inteiro (como data) p/ os bindings de isOverridden() reavaliarem.
    property var defaults: ({})

    readonly property string filePath: Quickshell.env("HOME") + "/.config/quickshell/settings.json"

    // valor efetivo de uma chave (override, senão o padrão passado)
    function get(key, fallback) {
        return (data && data[key] !== undefined && data[key] !== null) ? data[key] : fallback
    }
    function has(key) { return data && data[key] !== undefined && data[key] !== null }

    // a chave está "fora do padrão de fábrica"? (override presente E diferente do
    // snapshot — depois de makeDefault() os campos deixam de aparecer como alterados)
    function isOverridden(key) {
        if (!has(key)) return false
        const d = defaults ? defaults[key] : undefined
        if (d === undefined || d === null) return true
        return JSON.stringify(data[key]) !== JSON.stringify(d)
    }

    // volta UMA chave ao padrão de fábrica: valor do snapshot se houver, senão remove
    function revert(key) {
        const d = defaults ? defaults[key] : undefined
        if (d !== undefined && d !== null) set(key, d)
        else unset(key)
    }

    // grava/atualiza um override
    function set(key, value) {
        var d = {}
        for (var k in data) d[k] = data[k]
        d[key] = value
        data = d
        saveTimer.restart()
        // mudou cor da paleta ou tema -> regenera os temas externos (kitty/rofi/vesktop…)
        if (key.indexOf("pal_") === 0 || key.indexOf("theme") === 0) exportTimer.restart()
    }

    // remove um override (volta essa chave ao padrão)
    function unset(key) {
        if (!has(key)) return
        var d = {}
        for (var k in data) if (k !== key) d[k] = data[k]
        data = d
        saveTimer.restart()
        if (key.indexOf("pal_") === 0 || key.indexOf("theme") === 0) exportTimer.restart()
    }

    // volta TUDO ao padrão: recarrega o arquivo settings.default.json (o "padrão de
    // fábrica" deste setup). Se ele não existir/estiver vazio, cai em {} = padrões do código.
    function reset() {
        var def = ({})
        try { def = JSON.parse(defaultsFile.text() || "{}") } catch (e) { def = ({}) }
        defaults = def
        var d = {}
        for (var k in def) d[k] = def[k]   // cópia independente do snapshot
        data = d
        save()
        exportTimer.restart()
    }

    // torna a configuração ATUAL o novo padrão: faz backup do settings.default.json
    // (se existir) e o substitui pelos overrides de agora. O conteúdo NÃO passa pela
    // shell (glifos PUA/acentos quebrariam o Qt.btoa) — o backup vai por cp e a
    // escrita por FileView.setText, sequenciadas pelo onExited do processo.
    function makeDefault() {
        saveTimer.stop()
        save()   // garante o settings.json em dia
        var d = {}
        for (var k in data) d[k] = data[k]
        defaults = d   // atualiza o snapshot -> os avisos "fora do padrão" somem
        backupProc.pending = JSON.stringify(data, null, 2)
        backupProc.exec(["sh", "-c",
            '[ -s "$1" ] && cp -f "$1" "$1.bak-$(date +%Y%m%d-%H%M%S)" || true',
            "sh", defaultsPath])
    }

    // faz o backup do padrão anterior; ao terminar, grava o novo padrão
    Process {
        id: backupProc
        property string pending: ""
        onExited: {
            if (pending === "") return
            defaultsFile.setText(pending)
            pending = ""
        }
    }

    function save() {
        file.setText(JSON.stringify(data, null, 2))
    }

    // arquivo de persistência (lido em bloco no início p/ não piscar o padrão)
    FileView {
        id: file
        path: root.filePath
        blockLoading: true
        printErrors: false   // 1ª execução: o arquivo ainda não existe (normal) -> sem warning
        onLoaded: {
            try { root.data = JSON.parse(file.text() || "{}") }
            catch (e) { root.data = ({}) }
        }
        onLoadFailed: root.data = ({})   // arquivo ainda não existe -> tudo no padrão
    }

    // arquivo de PADRÃO ("voltar ao default"). Carrega o snapshot no boot;
    // reset() relê o texto na hora (pega edições feitas à mão no arquivo).
    readonly property string defaultsPath: Quickshell.env("HOME") + "/.config/quickshell/settings.default.json"
    FileView {
        id: defaultsFile
        path: root.defaultsPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            try { root.defaults = JSON.parse(defaultsFile.text() || "{}") }
            catch (e) { root.defaults = ({}) }
        }
        onLoadFailed: root.defaults = ({})   // sem arquivo de padrão -> padrões do código
    }

    // grava com pequeno atraso (junta várias edições seguidas num write só)
    Timer { id: saveTimer; interval: 400; onTriggered: root.save() }
    // regenera os temas externos com atraso (junta várias trocas de cor)
    Timer { id: exportTimer; interval: 600; onTriggered: ThemeExport.exportAll() }
}
