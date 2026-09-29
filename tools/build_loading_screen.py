"""Embed the loader art and CSS so direct Godot exports need no extra file copies.

Run after changing assets/ui/loading inputs. Pillow is needed only to prepare
the generated illustration; committed shell.html works on Windows and CI.
"""
import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/ui/loading'


def main():
    shell = (ART / 'shell.template.html').read_text(encoding='utf-8')
    shell = shell.replace('@LOADING_CSS@', (ART / 'loading.css').read_text(encoding='utf-8'))
    for token, filename in [('DIARY', 'diary.png'), ('GODOT', 'godot-icon.png')]:
        data = base64.b64encode((ART / filename).read_bytes()).decode('ascii')
        shell = shell.replace('@' + token + '@', 'data:image/png;base64,' + data)
    (ART / 'shell.html').write_text(shell, encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
