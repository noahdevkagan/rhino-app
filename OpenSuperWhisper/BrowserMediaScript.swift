import Foundation

/// Runs inside an approved browser tab. Exact element references stay in that page;
/// Swift receives only status words and its own UUIDs, never browsing/media content.
enum BrowserMediaScript {
    static func pause(token: String, deadline: Date = Date().addingTimeInterval(1.5)) -> String {
        script(action: "pause", tokens: [token], deadline: deadline.timeIntervalSince1970 * 1000)
    }

    static func resume(tokens: [String]) -> String {
        script(action: "resume", tokens: tokens, deadline: 0)
    }

    private static func script(action: String, tokens: [String], deadline: Double) -> String {
        let encoded = String(data: try! JSONEncoder().encode(tokens), encoding: .utf8)!
        return "(() => { const action = '\(action)', tokens = \(encoded), deadline = \(deadline);\n" + body + "\n})()"
    }

    private static let body = #"""
    const key = Symbol.for('app.rhinovoice.media-pause.v1');
    const events = ['play', 'seeking', 'emptied', 'ended', 'loadstart'];
    function mediaInPage() {
        const found = new Set(), visited = new Set();
        function visit(doc) {
            if (!doc || visited.has(doc)) return;
            visited.add(doc);
            for (const media of doc.querySelectorAll('audio,video')) found.add(media);
            for (const host of doc.querySelectorAll('*')) {
                if (host.shadowRoot) visit(host.shadowRoot);
            }
            for (const frame of doc.querySelectorAll('iframe,frame')) {
                try { visit(frame.contentDocument); } catch (_) { /* cross-origin */ }
            }
        }
        visit(document);
        return found;
    }
    function sourceDefinition(media) {
        // currentSrc can still name the old resource immediately after src changes.
        return JSON.stringify([media.getAttribute('src'),
            Array.from(media.querySelectorAll('source')).map(source =>
                [source.getAttribute('src'), source.getAttribute('type'), source.getAttribute('media')])]);
    }
    function clear(record) {
        for (const name of events) record.media.removeEventListener(name, record.invalidate);
    }
    function removeGroup(token, group) {
        for (const record of group.records) clear(record);
        window.removeEventListener('pagehide', group.onPageHide);
        window[key].delete(token);
        if (!window[key].size) delete window[key];
    }
    if (action === 'pause') {
        // A request that timed out must not pause a tab much later when it wakes up.
        if (Date.now() > deadline) return 'idle';
        const token = tokens[0];
        if (window[key]?.has(token)) return 'paused';
        const records = [];
        for (const media of mediaInPage()) {
            // Don't interrupt WebRTC/calls, muted videos, ended or already-paused media.
            if (media.paused || media.ended || media.muted || media.volume === 0 ||
                media.srcObject || !media.currentSrc || media.readyState === 0 ||
                !Number.isFinite(media.currentTime)) continue;
            try {
                const record = {
                    media, source: media.currentSrc, definition: sourceDefinition(media),
                    document: media.ownerDocument,
                    url: media.ownerDocument.location.href, valid: true
                };
                media.pause();
                if (!media.paused) continue;
                record.position = media.currentTime;
                record.invalidate = () => { record.valid = false; clear(record); };
                for (const name of events) media.addEventListener(name, record.invalidate);
                records.push(record);
            } catch (_) { /* inaccessible/disappearing media */ }
        }
        if (!records.length) return 'idle';
        if (!window[key]) Object.defineProperty(window, key, { value: new Map(), configurable: true });
        const group = { records, onPageHide: () => {
            if (window[key]?.has(token)) removeGroup(token, group);
        }};
        window[key].set(token, group);
        window.addEventListener('pagehide', group.onPageHide);
        return 'paused';
    }
    if (!window[key]) return '[]';
    const completed = [];
    const reachable = mediaInPage();
    for (const token of tokens) {
        const group = window[key]?.get(token);
        if (!group) continue;
        // Consume ownership before play(), including rejections or re-entrant handlers.
        removeGroup(token, group);
        completed.push(token);
        for (const record of group.records) {
            const media = record.media;
            try {
                if (!record.valid || !reachable.has(media) || !media.isConnected ||
                    media.ownerDocument !== record.document ||
                    media.ownerDocument.location.href !== record.url ||
                    media.currentSrc !== record.source || sourceDefinition(media) !== record.definition || media.srcObject ||
                    !media.paused || media.ended ||
                    !Number.isFinite(media.currentTime) ||
                    Math.abs(media.currentTime - record.position) >= 0.25) continue;
                const promise = media.play();
                if (promise && typeof promise.catch === 'function') promise.catch(() => {});
            } catch (_) { /* closed/navigated tab, or site refusing playback */ }
        }
    }
    return JSON.stringify(completed);
    """#
}
