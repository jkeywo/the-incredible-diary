"""Install the pinned official Godot runtime and selected export templates locally."""
import os
import platform
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / '.godot-version').read_text().strip()
BASE = f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable'
TOOLS = ROOT / '.tools'

def download(name, destination):
    print(f'Downloading {name}', flush=True)
    urllib.request.urlretrieve(f'{BASE}/{name}', destination)

def main():
    windows = platform.system() == 'Windows'
    if not windows and platform.system() != 'Linux':
        raise SystemExit('This setup supports Windows x64 and Linux x64 CI.')
    runtime = TOOLS / 'godot'
    runtime.mkdir(parents=True, exist_ok=True)
    archive_name = f'Godot_v{VERSION}-stable_' + ('win64.exe.zip' if windows else 'linux.x86_64.zip')
    executable = runtime / (f'Godot_v{VERSION}-stable_win64_console.exe' if windows else 'godot')
    with tempfile.TemporaryDirectory() as temporary:
        archive = Path(temporary) / 'runtime.zip'
        if not executable.exists():
            download(archive_name, archive)
            with zipfile.ZipFile(archive) as package:
                package.extractall(runtime)
            if not windows:
                (runtime / f'Godot_v{VERSION}-stable_linux.x86_64').rename(executable)
                executable.chmod(0o755)
        templates = TOOLS / 'templates'
        templates.mkdir(exist_ok=True)
        names = ['web_nothreads_debug.zip', 'web_nothreads_release.zip',
                 'windows_debug_x86_64.exe', 'windows_release_x86_64.exe']
        if not all((templates / name).exists() for name in names):
            archive = Path(temporary) / 'templates.tpz'
            download(f'Godot_v{VERSION}-stable_export_templates.tpz', archive)
            with zipfile.ZipFile(archive) as package:
                for name in names:
                    (templates / name).write_bytes(package.read('templates/' + name))
    print(f'Ready: {executable}')

if __name__ == '__main__':
    main()
