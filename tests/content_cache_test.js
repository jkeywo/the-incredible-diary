const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const { webcrypto, createHash } = require('node:crypto');
const source = fs.readFileSync('assets/ui/loading/content-cache.js', 'utf8');
const payload = new TextEncoder().encode('Shared asset bytes');
const hash = createHash('sha256').update(payload).digest('hex');
const cached = new Map();
let downloads = 0;
let corrupt = false;
function context(blockCache = false) {
  const root = {
    crypto: webcrypto, URL, Response, Uint8Array, Map, AbortController,
    document: { baseURI: 'https://example.test/game/' }, setTimeout, clearTimeout,
    caches: { open: async () => {
      if (blockCache) throw Error('Storage blocked');
      return {
        match: async key => cached.get(key)?.clone(),
        delete: async key => cached.delete(key),
        put: async (key, response) => cached.set(key, response.clone())
      };
    } },
    fetch: async () => { downloads++; return new Response(corrupt ? 'broken' : payload, { headers: { 'content-length': String(payload.length) } }); }
  };
  vm.runInNewContext(source, root);
  return root.diaryAssets;
}
async function finish(api) {
  for (let i = 0; i < 100; i++) {
    const status = JSON.parse(api.status(hash));
    if (status.state !== 'loading') return status;
    await new Promise(resolve => setTimeout(resolve, 2));
  }
  throw Error('Cache job did not finish');
}
(async () => {
  let api = context();
  api.begin('asset.pck', hash); api.begin('asset.pck', hash);
  assert.equal((await finish(api)).state, 'ready');
  assert.equal(downloads, 1);
  assert.deepEqual(new Uint8Array(api.bytes(hash)), payload);
  api.release(hash);
  // A fresh page/misson uses the same durable cache, with no network request.
  api = context(); api.begin('asset.pck', hash);
  assert.equal((await finish(api)).state, 'ready'); assert.equal(downloads, 1);
  cached.set('https://example.test/game/asset.pck', new Response('corrupt cache'));
  api = context(); api.begin('asset.pck', hash);
  assert.equal((await finish(api)).state, 'ready'); assert.equal(downloads, 2);
  api = context(true); api.begin('asset.pck', hash);
  assert.equal((await finish(api)).state, 'ready'); assert.equal(downloads, 3);
  corrupt = true; api = context(true); api.begin('asset.pck', hash);
  assert.equal((await finish(api)).state, 'failed');
  corrupt = false; api.release(hash); api.begin('asset.pck', hash);
  assert.equal((await finish(api)).state, 'ready');
  console.log('CONTENT CACHE PASS: deduplication, cross-page reuse, corrupt-cache repair, unavailable storage, integrity failure and retry');
})().catch(error => { console.error(error); process.exitCode = 1; });
