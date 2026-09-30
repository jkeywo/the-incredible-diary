/* Available before Godot starts. Export injects the same CSV catalogue as the game. */
(function (scope) {
  function choose(preferred, supported) {
    for (const candidate of preferred) {
      const locale = String(candidate).replaceAll('-', '_').toLowerCase();
      const exact = supported.find(item => item.toLowerCase() === locale);
      if (exact) return exact;
      const language = locale.split('_')[0];
      if (supported.includes(language)) return language;
    }
    return 'en';
  }
  function locale() {
    let preference = 'automatic';
    try { preference = scope.localStorage.getItem('diary-language') || preference; } catch (_) {}
    const available = Object.keys(scope.DIARY_TRANSLATIONS || { en: {} });
    return choose(preference === 'automatic'
      ? (scope.navigator.languages || [scope.navigator.language]) : [preference], available);
  }
  function text(id, args = {}) {
    const catalogues = scope.DIARY_TRANSLATIONS || { en: {} };
    const value = (catalogues[locale()] || {})[id] || catalogues.en[id] || '';
    return value.replace(/\{([A-Za-z][A-Za-z0-9_]*)\}/g, (match, key) => args[key] ?? match);
  }
  scope.DiaryLocalisation = { choose, locale, text };
  if (typeof module !== 'undefined') module.exports = scope.DiaryLocalisation;
})(globalThis);
