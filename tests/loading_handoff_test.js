// Run with Node.js. Tests the actual exported-loader logic without downloading Godot.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = readFileSync('assets/ui/loading/shell.template.html', 'utf8');
const source = html.slice(html.indexOf('const GODOT_CONFIG'), html.lastIndexOf('</script>'))
  .replace('$GODOT_CONFIG', '{}').replace('$GODOT_THREADS_ENABLED', 'false');

async function scenario({ first = 'engine', reduced = false, fail = false, missing = false } = {}) {
  const elements = Object.fromEntries(['loading-label', 'status', 'status-progress', 'status-notice'].map(id => [id, {
    style: {}, removed: false, textContent: '', classList: { add() {} },
    remove() { this.removed = true; }, removeAttribute() {}, appendChild() {},
  }]));
  const events = {};
  const timers = [];
  let resolve, reject;
  const started = new Promise((yes, no) => { resolve = yes; reject = no; });
  const window = {
    matchMedia: () => ({ matches: reduced }),
    addEventListener: (name, fn) => { events[name] = fn; },
    setTimeout: (fn, ms) => { timers.push({ fn, ms }); },
  };
  const context = {
    window, navigator: {}, console: { error() {} },
    document: { getElementById: id => elements[id], createTextNode: text => ({ text }), createElement: () => ({}) },
    Engine: class {
      static getMissingFeatures() { return []; }
      startGame(options) { options.onProgress(25, 100); return started; }
    },
  };
  if (missing) delete context.Engine;
  vm.runInNewContext(source, context);
  const ready = () => { window.diaryTitleReady = true; events['diary-title-ready'](); };
  if (missing) {
    assert.match(elements['loading-label'].textContent, /could not/);
    assert.equal(elements.status.removed, false);
    return;
  }
  assert.match(elements['loading-label'].textContent, /25%/);
  if (first === 'title') ready();
  assert.equal(timers.length, 0);
  if (fail) reject('Download failed'); else resolve();
  await Promise.resolve();
  if (first === 'engine') {
    assert.equal(timers.length, 0);
    ready();
  }
  if (fail) {
    assert.equal(timers.length, 0);
    assert.equal(elements.status.removed, false);
    assert.match(elements['loading-label'].textContent, /could not/);
  } else {
    assert.equal(timers.length, 1);
    assert.equal(timers[0].ms, reduced ? 0 : 200);
    assert.equal(elements.status.removed, false);
    ready(); // Repeated readiness cannot schedule duplicate teardown.
    assert.equal(timers.length, 1);
    timers[0].fn();
    assert.equal(elements.status.removed, true);
  }
}
(async () => {
  await scenario();
  await scenario({ first: 'title' });
  await scenario({ reduced: true });
  await scenario({ fail: true });
  await scenario({ missing: true });
  console.log('LOADING HANDOFF PASS: both readiness orders, reduced motion, progress and persistent errors');
})().catch(error => { console.error(error); process.exitCode = 1; });
