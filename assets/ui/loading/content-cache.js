/* Content hashes identify assets across rooms, missions and deployments.
 * Cache Storage is optional: private browsing/quota failures fall back to fetch.
 * No save data is placed in this cache. */
(function (root) {
  const jobs = new Map();
  const hex = bytes => Array.from(new Uint8Array(bytes), x => x.toString(16).padStart(2, '0')).join('');
  async function valid(bytes, hash) {
    return hex(await root.crypto.subtle.digest('SHA-256', bytes)) === hash;
  }
  root.diaryAssets = {
    begin(path, hash) {
      if (jobs.has(hash)) return;
      const job = { progress: 0, state: 'loading', error: '', bytes: null };
      jobs.set(hash, job);
      (async () => {
        const url = new URL(path, root.document.baseURI).href;
        let cache;
        try { cache = await root.caches.open('diary-assets-v1'); } catch (_) {}
        if (cache) {
          try {
            const cached = await cache.match(url);
            if (cached) {
              const bytes = await cached.arrayBuffer();
              if (await valid(bytes, hash)) {
                job.bytes = bytes; job.progress = 1; job.state = 'ready'; return;
              }
              await cache.delete(url);
            }
          } catch (_) { /* A cache read failure must not prevent an online load. */ }
        }
        const controller = new AbortController();
        const timeout = root.setTimeout(() => controller.abort(), 120000);
        try {
          const response = await root.fetch(url, { signal: controller.signal });
          if (response.status === 404) throw new Error('This version is no longer available. Please reload the page.');
          if (!response.ok) throw new Error('Download interrupted. Please try again.');
          const length = Number(response.headers.get('content-length'));
          const reader = response.body.getReader();
          const parts = []; let received = 0;
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            parts.push(value); received += value.byteLength;
            job.progress = length > 0 ? Math.min(0.99, received / length) : 0;
          }
          const bytes = new Uint8Array(received); let offset = 0;
          for (const part of parts) { bytes.set(part, offset); offset += part.byteLength; }
          if (!await valid(bytes, hash)) throw new Error('Incomplete download. Please try again.');
          if (cache) {
            try { await cache.put(url, new Response(bytes)); } catch (_) {}
          }
          job.bytes = bytes.buffer; job.progress = 1; job.state = 'ready';
        } finally { root.clearTimeout(timeout); }
      })().catch(error => { job.error = error.message; job.state = 'failed'; });
    },
    status(hash) {
      const job = jobs.get(hash);
      return JSON.stringify(job ? { state: job.state, progress: job.progress, error: job.error } : {});
    },
    bytes(hash) { return jobs.get(hash).bytes; },
    release(hash) { jobs.delete(hash); }
  };
})(globalThis);
