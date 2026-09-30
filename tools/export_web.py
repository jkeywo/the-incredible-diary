"""Export web, then separate the title's dependencies from deferred content.

Use Godot's ZIP export and PCKPacker so imported resources and script remaps
remain in the engine's own formats. The engine itself is still needed at boot.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/web"
REF = re.compile(r'"res://([^"\n]+)"')
PRELOAD = re.compile(r'(?:\bpreload\(\s*|\bextends\s+)"res://([^"\n]+)"')


def dependencies(roots):
    found = set()
    pending = list(roots)
    while pending:
        name = pending.pop()
        if name in found or not (ROOT / name).is_file():
            continue
        found.add(name)
        if Path(name).suffix not in {".gd", ".tscn", ".tres", ".godot"}:
            continue
        source = (ROOT / name).read_text(encoding="utf-8-sig")
        pending.extend((PRELOAD if name.endswith(".gd") else REF).findall(source))
    return found


def main():
    godot = str(Path(sys.argv[1]).resolve())
    OUT.mkdir(parents=True, exist_ok=True)

    def run(*args):
        subprocess.run([godot, "--headless", "--path", str(ROOT), *args], check=True, timeout=300)

    run("--export-release", "Web", str(OUT / "index.html"))
    archive = ROOT / "build/web-full.zip"
    run("--export-pack", "Web", str(archive))
    roots = ["assets/ui/loading/native_loading.tscn", "assets/ui/mission_1/title_screen.tscn",
             "assets/ui/loading/boot-splash.png", "default_bus_layout.tres",
             "assets/rooms/mission_1/01_docks.tscn"]
    project = (ROOT / "project.godot").read_text()
    roots += re.findall(r'="\*res://([^"]+)"', project)
    roots += [str(p.relative_to(ROOT)).replace("\\", "/")
              for p in (ROOT / "addons").rglob("*.gd")]
    boot_sources = dependencies(roots)
    boot_sources.update("localisation/" + p.name for p in (ROOT / "localisation").glob("*.csv"))
    with zipfile.ZipFile(archive) as source:
        names = set(source.namelist())
        boot = {name for name in names if not name.startswith(".godot/imported/")}
        imports = {}
        for name in sorted(names):
            if name.endswith(".import"):
                imports[name.removesuffix(".import")] = {
                    ref for ref in REF.findall(source.read(name).decode())
                    if ref in names and ref.startswith(".godot/imported/")}
        for name in boot_sources:
            boot.update(imports.get(name, set()))
        chunks = [[name] for name in sorted(names - boot)]
        plan = {"bootstrap": sorted(boot), "chunks": chunks}
        (ROOT / "build/web-pack-plan.json").write_text(json.dumps(plan), encoding="utf-8")
        originals = {name.removesuffix(".remap").removesuffix(".import") for name in names
                     if not name.startswith(".godot/")}
    run("--script", "res://tools/pack_web.gd", "--quit-after", "2")
    chunks_by_entry = {}
    packs = {}
    for i, entries in enumerate(chunks):
        content = OUT / f"chunk-{i}.pck"
        digest = hashlib.sha256(content.read_bytes()).hexdigest()
        filename = f"asset-{digest}.pck"
        size = content.stat().st_size
        content.replace(OUT / filename)
        packs[digest] = {"url": filename, "bytes": size}
        for entry in entries:
            chunks_by_entry[entry] = digest
    resource_packs = {}
    for name in sorted(originals):
        required = set()
        for dependency in dependencies([name]):
            required.update(chunks_by_entry[entry] for entry in imports.get(dependency, set())
                            if entry in chunks_by_entry)
        resource_packs["res://" + name] = sorted(required)
    config = {"packs": packs, "resources": resource_packs}
    html = OUT / "index.html"
    text = html.read_text(encoding="utf-8")
    text = re.sub(r'("index.pck"\s*:\s*)\d+', lambda m: m[1] + str((OUT / "index.pck").stat().st_size), text)
    text = text.replace("const GODOT_CONFIG =", "window.DIARY_CONTENT = " + json.dumps(config) + ";\nconst GODOT_CONFIG =")
    text = text.replace('<script src="index.js">', '<script src="content-cache.js"></script>\n\t\t<script src="index.js">')
    html.write_text(text, encoding="utf-8")
    (OUT / "content-cache.js").write_bytes((ROOT / "assets/ui/loading/content-cache.js").read_bytes())
    (OUT / "audio-credits.txt").write_bytes((ROOT / "assets/audio/mission_3/CREDITS.txt").read_bytes())
    (ROOT / "build/web-content-manifest.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
    check = subprocess.run([godot, "--headless", "--path", str(OUT), "--main-pack", "index.pck",
                            "--script", str(ROOT / "tests/exported_content_test.gd"), "--quit-after", "300"],
                           cwd=OUT, capture_output=True, text=True, timeout=60)
    (ROOT / "build/exported-content-test.log").write_text(check.stdout + check.stderr, encoding="utf-8")
    if check.returncode or "EXPORTED CONTENT PASS" not in check.stdout or any(
        error in check.stdout + check.stderr for error in ["SCRIPT ERROR", "Failed loading resource", "Assertion failed"]
    ):
        raise RuntimeError("Exported resource validation failed; see build/exported-content-test.log")
    print(f"Web: title + docks pack {(OUT / 'index.pck').stat().st_size / 1e6:.2f} MB; {len(packs)} reusable asset packs")


if __name__ == "__main__":
    main()
