// ==UserScript==
// @name         LK's Shell — Ponte do YouTube Music
// @namespace    lks-shell
// @version      1.0.0
// @description  Publica o estado da aba do YouTube Music e executa os comandos do popup do LK's Shell.
// @match        https://music.youtube.com/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// @noframes
// ==/UserScript==

(function () {
    'use strict';

    // O shell inicia services/ytm_bridge.py nesta porta. O userscript conversa
    // com ele por HTTP: POST /state (heartbeat + estado) e GET /commands (fila).
    const BASE = 'http://127.0.0.1:26541';
    const CLIENT_ID = 'ytm-' + Math.random().toString(36).slice(2) + '-' + Date.now().toString(36);
    const STATE_MS = 1000;
    const COMMAND_MS = 500;
    const START_FLAG = 'lksShellYtmStart';
    const START_RELOAD_FLAG = 'lksShellYtmStartReloaded';

    // Botões de "tocar" dos itens da home/biblioteca. Servem para iniciar alguma
    // música quando a aba ainda não tem nenhuma faixa carregada.
    const START_SELECTORS = [
        'ytmusic-shelf-renderer ytmusic-responsive-list-item-renderer #play-button',
        'ytmusic-shelf-renderer ytmusic-two-row-item-renderer #play-button',
        'ytmusic-shelf-renderer ytmusic-play-button-renderer',
        'ytmusic-carousel-shelf-renderer ytmusic-two-row-item-renderer #play-button',
        'ytmusic-carousel-shelf-renderer ytmusic-responsive-list-item-renderer #play-button',
        'ytmusic-grid-renderer ytmusic-two-row-item-renderer #play-button',
        'ytmusic-responsive-list-item-renderer #play-button',
        'ytmusic-two-row-item-renderer #play-button',
        'ytmusic-play-button-renderer'
    ];

    let stateTimer = null;
    let commandTimer = null;
    let starting = false;

    // ── acesso ao player ──────────────────────────────────────────────────────

    function playerApi() {
        return document.querySelector('#movie_player');
    }

    function videoEl() {
        return document.querySelector('video.html5-main-video') || document.querySelector('video');
    }

    function safeCall(obj, name, fallback) {
        if (!obj || typeof obj[name] !== 'function') return fallback;
        try {
            // Os argumentos extras (posição do seek, volume…) vêm depois do fallback.
            const args = Array.prototype.slice.call(arguments, 3);
            const value = obj[name].apply(obj, args);
            return value === undefined || value === null ? fallback : value;
        } catch (e) {
            return fallback;
        }
    }

    function videoData() {
        const data = safeCall(playerApi(), 'getVideoData', {});
        return data && typeof data === 'object' ? data : {};
    }

    function playerResponse() {
        const response = safeCall(playerApi(), 'getPlayerResponse', null);
        return response && typeof response === 'object' ? response : null;
    }

    function mediaSessionInfo() {
        const metadata = navigator.mediaSession && navigator.mediaSession.metadata;
        if (!metadata) return {};
        let art = '';
        if (Array.isArray(metadata.artwork) && metadata.artwork.length > 0) {
            art = metadata.artwork[metadata.artwork.length - 1].src || '';
        }
        return {
            title: metadata.title || '',
            artist: metadata.artist || '',
            art: art
        };
    }

    function hasTrack() {
        const data = videoData();
        if (data.video_id) return true;

        const response = playerResponse();
        if (response && response.videoDetails && response.videoDetails.videoId) return true;

        // Fallback: a Media Session já anuncia uma faixa mesmo antes de o
        // elemento #movie_player terminar de carregar.
        return !!mediaSessionInfo().title;
    }

    function trackInfo() {
        const data = videoData();
        const response = playerResponse();
        const details = (response && response.videoDetails) || {};
        const session = mediaSessionInfo();

        let title = details.title || data.title || session.title || '';
        if (!title) {
            const el = document.querySelector('ytmusic-player-bar .title');
            if (el) title = el.getAttribute('title') || el.textContent || '';
        }

        let artist = details.author || data.author || session.artist || '';
        if (!artist) {
            const el = document.querySelector('ytmusic-player-bar .byline');
            if (el) {
                const text = el.getAttribute('title') || el.textContent || '';
                artist = text.split('•')[0].trim();
            }
        }

        let art = session.art || '';
        const thumbs = details.thumbnail && details.thumbnail.thumbnails;
        if (Array.isArray(thumbs) && thumbs.length > 0) {
            art = thumbs[thumbs.length - 1].url || art;
        }
        if (!art) {
            const img = document.querySelector('ytmusic-player-bar img');
            if (img) art = img.src || '';
        }

        return { title: title, artist: artist, art: art };
    }

    function isPaused() {
        const api = playerApi();
        if (api && typeof api.getPlayerState === 'function') {
            const state = safeCall(api, 'getPlayerState', 2);
            if (state === 1) return false;          // tocando
            if (state === 3) return false;          // buffering (intenção: tocar)
            if (state === 2 || state === 0 || state === 5) return true;
        }
        const video = videoEl();
        return video ? !!video.paused : true;
    }

    function currentPosition() {
        const api = playerApi();
        if (api && typeof api.getCurrentTime === 'function') {
            return Math.max(0, Number(safeCall(api, 'getCurrentTime', 0)) || 0);
        }
        const video = videoEl();
        return video ? Math.max(0, Number(video.currentTime) || 0) : 0;
    }

    function currentDuration() {
        const api = playerApi();
        if (api && typeof api.getDuration === 'function') {
            return Math.max(0, Number(safeCall(api, 'getDuration', 0)) || 0);
        }
        const video = videoEl();
        return video ? Math.max(0, Number(video.duration) || 0) : 0;
    }

    function currentVolume() {
        const api = playerApi();
        if (api && typeof api.getVolume === 'function') {
            return Math.max(0, Math.min(1, (Number(safeCall(api, 'getVolume', 100)) || 0) / 100));
        }
        const video = videoEl();
        return video ? Math.max(0, Math.min(1, Number(video.volume) || 0)) : 1;
    }

    function playMedia() {
        const api = playerApi();
        if (api && typeof api.playVideo === 'function') {
            safeCall(api, 'playVideo', null);
            return;
        }
        const video = videoEl();
        if (video) video.play().catch(function () {});
    }

    function pauseMedia() {
        const api = playerApi();
        if (api && typeof api.pauseVideo === 'function') {
            safeCall(api, 'pauseVideo', null);
            return;
        }
        const video = videoEl();
        if (video) video.pause();
    }

    function nextMedia() {
        safeCall(playerApi(), 'nextVideo', null);
    }

    function previousMedia() {
        safeCall(playerApi(), 'previousVideo', null);
    }

    function seekMedia(seconds) {
        const target = Math.max(0, Number(seconds) || 0);
        const api = playerApi();
        if (api && typeof api.seekTo === 'function') {
            safeCall(api, 'seekTo', null, target, true);
            return;
        }
        const video = videoEl();
        if (video) video.currentTime = target;
    }

    function setVolume(value) {
        const volume = Math.max(0, Math.min(1, Number(value) || 0));
        const api = playerApi();
        if (api && typeof api.setVolume === 'function') {
            safeCall(api, 'setVolume', null, Math.round(volume * 100));
            return;
        }
        const video = videoEl();
        if (video) video.volume = volume;
    }

    // ── iniciar alguma música quando não há faixa carregada ───────────────────

    function realClick(element) {
        if (!element) return false;
        try {
            element.dispatchEvent(new MouseEvent('click', {
                bubbles: true,
                cancelable: true,
                view: window
            }));
            return true;
        } catch (e) {
            try {
                element.click();
                return true;
            } catch (e2) {
                return false;
            }
        }
    }

    function clickBarPlay() {
        const bar = document.querySelector('ytmusic-player-bar');
        if (!bar) return false;
        const button = bar.querySelector(
            '#play-pause-button, tp-yt-paper-icon-button#play-pause-button, yt-icon-button#play-pause-button'
        );
        return realClick(button);
    }

    function clickStartItem() {
        for (let s = 0; s < START_SELECTORS.length; s++) {
            let nodes;
            try {
                nodes = document.querySelectorAll(START_SELECTORS[s]);
            } catch (e) {
                continue;
            }
            for (let i = 0; i < nodes.length; i++) {
                const node = nodes[i];
                // nunca clicar no botão da própria player bar
                if (node.closest && node.closest('ytmusic-player-bar')) continue;
                if (realClick(node)) return true;
            }
        }
        return false;
    }

    // Tenta retomar a faixa atual; se não houver nenhuma, tenta iniciar a
    // primeira música disponível na página e, em último caso, vai para a home.
    function startMusic() {
        if (starting) return;
        starting = true;

        let tries = 0;
        function attempt() {
            if (hasTrack()) {
                playMedia();
                starting = false;
                publish();
                return;
            }

            // 1ª tentativa: o botão da player bar pode retomar uma fila já carregada.
            if (tries === 0) clickBarPlay();

            // 2ª em diante: clica no play de um item da home/biblioteca.
            if (tries >= 1 && clickStartItem()) {
                setTimeout(function () { publish(); }, 700);
                setTimeout(function () { starting = false; }, 1600);
                return;
            }

            tries++;
            if (tries < 8) {
                setTimeout(attempt, 800);
                return;
            }

            // Nenhum item na página atual: vai para a home e tenta de novo ao carregar.
            if (location.pathname !== '/' || location.search) {
                try { sessionStorage.setItem(START_FLAG, '1'); } catch (e) {}
                starting = false;
                location.href = 'https://music.youtube.com/';
                return;
            }

            // Já estamos na home e ela ainda não renderizou: recarrega uma vez.
            let reloaded = false;
            try { reloaded = sessionStorage.getItem(START_RELOAD_FLAG) === '1'; } catch (e) {}
            if (!reloaded) {
                try {
                    sessionStorage.setItem(START_RELOAD_FLAG, '1');
                    sessionStorage.setItem(START_FLAG, '1');
                } catch (e) {}
                starting = false;
                location.reload();
                return;
            }

            starting = false;
        }

        attempt();
    }

    function maybeAutoStartFromHome() {
        let flag = false;
        try { flag = sessionStorage.getItem(START_FLAG) === '1'; } catch (e) {}
        if (!flag) return;
        try { sessionStorage.removeItem(START_FLAG); } catch (e) {}

        let tries = 0;
        const timer = setInterval(function () {
            if (hasTrack()) {
                clearInterval(timer);
                publish();
                return;
            }
            if (clickStartItem()) {
                clearInterval(timer);
                setTimeout(function () { publish(); }, 700);
                return;
            }
            tries++;
            if (tries >= 16) clearInterval(timer);
        }, 500);
    }

    function toggleMedia() {
        if (!hasTrack()) {
            startMusic();
            return;
        }
        if (isPaused()) playMedia();
        else pauseMedia();
    }

    // ── estado e comandos ─────────────────────────────────────────────────────

    function currentState() {
        const info = trackInfo();
        return {
            client: CLIENT_ID,
            title: info.title,
            artist: info.artist,
            art: info.art,
            position: currentPosition(),
            duration: currentDuration(),
            paused: isPaused(),
            volume: currentVolume(),
            hasTrack: hasTrack(),
            url: location.href,
            visibility: document.visibilityState === 'visible' ? 'visible' : 'hidden'
        };
    }

    // GM_xmlhttpRequest evita CORS e funciona mesmo com o servidor em 127.0.0.1.
    // O fallback fetch serve para quando o userscript rodar sem o Tampermonkey.
    function request(method, path, body, callback) {
        const url = BASE + path;
        const data = body ? JSON.stringify(body) : undefined;
        const headers = body ? { 'Content-Type': 'application/json' } : {};

        if (typeof GM_xmlhttpRequest === 'function') {
            GM_xmlhttpRequest({
                method: method,
                url: url,
                headers: headers,
                data: data,
                timeout: 2500,
                onload: function (response) { callback && callback(null, response); },
                onerror: function (error) { callback && callback(error || new Error('rede')); },
                ontimeout: function () { callback && callback(new Error('timeout')); }
            });
            return;
        }

        fetch(url, {
            method: method,
            headers: headers,
            body: data,
            cache: 'no-store'
        }).then(function (response) {
            return response.text().then(function (text) {
                callback && callback(null, { status: response.status, responseText: text });
            });
        }).catch(function (error) {
            callback && callback(error);
        });
    }

    // Sempre envia, mesmo quando o estado não mudou: o servidor usa esses
    // POSTs como heartbeat (TTL de 3 s) para saber que a aba continua aberta.
    // Por isso não há deduplicação por JSON aqui.
    function publish() {
        request('POST', '/state', currentState(), null);
    }

    function execute(command) {
        if (!command || typeof command !== 'object') return;
        switch (command.cmd) {
            case 'play':
                if (hasTrack()) playMedia();
                else startMusic();
                break;
            case 'pause':
                pauseMedia();
                break;
            case 'toggle':
                toggleMedia();
                break;
            case 'next':
                nextMedia();
                break;
            case 'previous':
                previousMedia();
                break;
            case 'seek':
                if (typeof command.position === 'number') seekMedia(command.position);
                break;
            case 'volume':
                if (typeof command.volume === 'number') setVolume(command.volume);
                break;
        }
        // Manda o novo estado logo depois da ação, sem esperar o próximo ciclo.
        setTimeout(function () { publish(); }, 250);
    }

    function pollCommands() {
        request('GET', '/commands?client=' + encodeURIComponent(CLIENT_ID), null, function (error, response) {
            if (error || !response || response.status !== 200) return;
            let data;
            try { data = JSON.parse(response.responseText); } catch (e) { return; }
            const commands = (data && data.commands) || [];
            for (let i = 0; i < commands.length; i++) execute(commands[i]);
        });
    }

    function start() {
        publish();
        maybeAutoStartFromHome();

        stateTimer = setInterval(function () { publish(); }, STATE_MS);
        commandTimer = setInterval(pollCommands, COMMAND_MS);

        document.addEventListener('visibilitychange', function () {
            publish();
        });

        // A SPA do YTM troca de página sem recarregar; o player continua o mesmo,
        // mas o estado (URL/visibilidade) muda.
        document.addEventListener('yt-navigate-finish', function () {
            publish();
            maybeAutoStartFromHome();
        });

        // Eventos do player do YouTube (quando disponíveis).
        const api = playerApi();
        if (api && typeof api.addEventListener === 'function') {
            try { api.addEventListener('onStateChange', function () { publish(); }); } catch (e) {}
            try { api.addEventListener('onVideoDataChange', function () { publish(); }); } catch (e) {}
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }
})();
