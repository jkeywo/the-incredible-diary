const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
function environment(preferred, preference, denied = false) {
  const context = {
    navigator: { languages: preferred, language: preferred[0] },
    localStorage: { getItem() { if (denied) throw Error('Denied'); return preference; } },
    DIARY_TRANSLATIONS: { en: { UI_LOADING_PROGRESS: 'Loading {percent}%', HELLO: 'Hello' }, fr: { HELLO: 'Bonjour' } },
  };
  vm.runInNewContext(fs.readFileSync('assets/ui/loading/localisation.js', 'utf8'), context);
  return context.DiaryLocalisation;
}
assert.equal(environment(['fr-FR', 'en-GB'], 'automatic').text('HELLO'), 'Bonjour');
assert.equal(environment(['fr-FR'], 'en').text('HELLO'), 'Hello');
assert.equal(environment(['de', 'fr'], 'automatic').locale(), 'fr');
assert.equal(environment(['ja'], 'automatic').locale(), 'en');
assert.equal(environment(['fr'], 'automatic').text('UI_LOADING_PROGRESS', { percent: 37 }), 'Loading 37%');
assert.equal(environment(['fr'], '', true).locale(), 'fr');
assert.equal(environment(['en'], 'automatic').text('MISSING'), '');
console.log('LOCALISATION WEB PASS: browser preferences, override, fallback, blocked storage and formatting');
