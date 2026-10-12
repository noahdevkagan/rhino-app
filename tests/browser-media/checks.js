/* Execute the production Swift-generated scripts against real HTML media in Chrome.
   All audio is silent, generated locally. No site, account, server, or network is used. */
(async () => {
    const results = [];
    const stage = document.getElementById('stage');
    const assert = (condition, message) => { if (!condition) throw new Error(message); };
    const pause = () => (0, eval)(rhinoScripts.pause);
    const resume = () => (0, eval)(rhinoScripts.resume);
    const settle = () => new Promise(resolve => setTimeout(resolve, 0));
    const size = 8000 * 30 * 2;
    const buffer = new ArrayBuffer(44 + size), data = new DataView(buffer);
    function str(at, s) { for (let i = 0; i < s.length; i++) data.setUint8(at + i, s.charCodeAt(i)); }
    str(0, 'RIFF'); data.setUint32(4, 36 + size, true); str(8, 'WAVE'); str(12, 'fmt ');
    data.setUint32(16, 16, true); data.setUint16(20, 1, true); data.setUint16(22, 1, true);
    data.setUint32(24, 8000, true); data.setUint32(28, 16000, true); data.setUint16(32, 2, true);
    data.setUint16(34, 16, true); str(36, 'data'); data.setUint32(40, size, true);
    const blob = new Blob([buffer], { type: 'audio/wav' });
    // Data URLs avoid cross-document blob ownership/teardown races in media engines.
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i += 16384) binary += String.fromCharCode(...bytes.subarray(i, i + 16384));
    const source = 'data:audio/wav;base64,' + btoa(binary);
    async function media(doc = document, kind = 'audio', container = null) {
        const element = doc.createElement(kind);
        const ready = new Promise((resolve, reject) => {
            element.addEventListener('loadedmetadata', resolve, { once: true });
            element.addEventListener('error', () => reject(new Error('local WAV failed to load')), { once: true });
        });
        element.src = source;
        element.preload = 'auto';
        (container || (doc === document ? stage : doc.body)).append(element);
        await ready;
        return element;
    }
    let a, b;
    async function test(name, check) {
        document.getElementById('result').textContent = 'RUNNING: ' + name + '\n' + results.join('\n');
        try {
            resume();
            if (a) a.pause();
            if (b) b.pause();
            stage.replaceChildren();
            a = await media(); b = await media();
            await check();
            results.push('ok ' + name);
        } catch (error) { results.push('FAIL ' + name + ': ' + error.message); }
    }
    await test('restore only originally-playing media', async () => {
        await a.play();
        assert(pause() === 'paused' && a.paused && b.paused, 'pause');
        resume();
        assert(!a.paused && b.paused, 'only the owned element should resume');
    });
    await test('multiple playing elements', async () => {
        await Promise.all([a.play(), b.play()]);
        pause(); assert(a.paused && b.paused, 'both pause');
        resume(); assert(!a.paused && !b.paused, 'both resume');
    });
    await test('already paused page', async () => {
        assert(pause() === 'idle', 'no ticket'); resume(); assert(a.paused && b.paused, 'no playback');
    });
    await test('manual play then pause', async () => {
        await a.play(); pause(); await a.play(); a.pause(); await settle(); resume();
        assert(a.paused, 'manual pause must be respected');
    });
    await test('seek during recording', async () => {
        await a.play(); pause(); a.currentTime = 5; resume(); assert(a.paused, 'seek cancels restore');
    });
    await test('replaced element', async () => {
        await a.play(); pause(); a.remove(); b.id = 'a'; resume();
        assert(a.paused && b.paused, 'neither detached nor replacement element starts');
    });
    await test('replaced source', async () => {
        await a.play(); pause(); a.src = URL.createObjectURL(blob); a.load(); resume();
        assert(a.paused, 'new source stays paused');
    });
    await test('single-page navigation', async () => {
        await a.play(); pause(); location.hash = 'different-video'; resume(); assert(a.paused, 'new page');
    });
    await test('navigation and back-forward cache', async () => {
        await a.play(); pause(); window.dispatchEvent(new PageTransitionEvent('pagehide')); resume();
        assert(a.paused, 'ownership is cleared');
    });
    await test('unknown token and duplicate resume', async () => {
        await a.play(); pause(); (0, eval)(rhinoScripts.other); assert(a.paused, 'wrong token');
        resume(); a.pause(); resume(); assert(a.paused, 'consumed token');
    });
    await test('muted playback', async () => {
        a.muted = true; await a.play(); assert(pause() === 'idle' && !a.paused, 'muted media untouched');
    });
    await test('expired pause request', async () => {
        await a.play(); assert((0, eval)(rhinoScripts.expired) === 'idle' && !a.paused, 'no late pause');
    });
    await test('same-origin iframe', async () => {
        const frame = document.createElement('iframe'); stage.append(frame);
        const child = await media(frame.contentDocument);
        await child.play(); pause(); assert(child.paused, 'frame pauses');
        resume(); assert(!child.paused, 'frame resumes'); child.pause();
    });
    await test('detached iframe', async () => {
        const frame = document.createElement('iframe'); stage.append(frame);
        const child = await media(frame.contentDocument);
        await child.play(); pause(); frame.remove(); resume(); assert(child.paused, 'detached frame stays paused');
    });
    await test('open shadow root', async () => {
        const host = document.createElement('div'); stage.append(host);
        await a.play();
        host.attachShadow({mode:'open'}).append(a);
        // Moving an element can interrupt its pending play promise. Playback intent
        // (paused=false) is synchronous, which is what the production script tests.
        a.play().catch(() => {});
        pause(); assert(a.paused, 'shadow media pauses');
        resume(); assert(!a.paused, 'shadow media resumes'); a.pause();
    });
    await test('rejected play is not retried', async () => {
        await a.play(); pause(); let attempts = 0;
        a.play = () => { attempts++; return Promise.reject(new Error('blocked')); };
        resume(); resume(); await settle(); assert(attempts === 1, 'no retry');
    });
    await test('video element', async () => {
        const video = await media(document, 'video'); await video.play(); pause();
        assert(video.paused, 'video pauses'); resume(); assert(!video.paused, 'video resumes'); video.pause();
    });
    await test('inaccessible embedded document', async () => {
        const frame = document.createElement('iframe'); frame.sandbox = ''; frame.srcdoc = '<p>isolated</p>';
        const loaded = new Promise(resolve => frame.onload = resolve); stage.append(frame); await loaded;
        await a.play(); assert(pause() === 'paused' && a.paused, 'skip inaccessible frame'); resume(); assert(!a.paused, 'root resumes');
    });
    if (a) a.pause(); if (b) b.pause();
    const failures = results.filter(result => result.startsWith('FAIL'));
    document.getElementById('result').textContent =
        (failures.length ? 'FAIL: ' : 'PASS: ') + results.length + ' browser media cases\n' + results.join('\n');
})().catch(error => { document.getElementById('result').textContent = 'FAIL: harness: ' + error.message; });
