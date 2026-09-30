"""Embed the loader art and CSS so direct Godot exports need no extra file copies.

Run after changing assets/ui/loading inputs. Pillow is needed only to prepare
the generated illustration; committed shell.html works on Windows and CI.
"""
import base64
import json
from localisation import catalogues
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/ui/loading'


def main():
    shell = (ART / 'shell.template.html').read_text(encoding='utf-8')
    translations = {"en": {}}
    for key, row in catalogues().items():
        if not key.startswith('UI_LOADING_') and key not in ['UI_A_VOYAGE_BETWEEN_THE_PAGES', 'UI_THE_INCREDIBLE_DIARY', 'UI_MADE_WITH_GODOT']: continue
        for locale, value in row.items():
            if locale == 'keys' or locale.startswith(('_', '?')) or not value: continue
            translations.setdefault(locale, {})[key] = value
    table = json.dumps(translations, ensure_ascii=True).replace('<', '\\u003c')
    runtime = (ART / 'localisation.js').read_text(encoding='utf-8')
    shell = shell.replace('@LOCALISATION_SCRIPT@', '<script>window.DIARY_TRANSLATIONS = ' + table + ';\n' + runtime + '</script>')
    shell = shell.replace('@LOADING_CSS@', (ART / 'loading.css').read_text(encoding='utf-8'))
    for token, filename in [('DIARY', 'diary.png'), ('GODOT', 'godot-icon.png')]:
        data = base64.b64encode((ART / filename).read_bytes()).decode('ascii')
        shell = shell.replace('@' + token + '@', 'data:image/png;base64,' + data)
    (ART / 'shell.html').write_text(shell, encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
