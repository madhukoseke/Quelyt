"""Stage a self-contained candidate, preserving the developer app separately."""
import json
import pathlib
import plistlib
import shutil
import subprocess
import importlib.metadata

ROOT = pathlib.Path(__file__).resolve().parents[2]
APP = ROOT / '.build/release/Quelyt.app'
if APP.exists():
    shutil.rmtree(APP)
shutil.copytree(ROOT / '.build/Quelyt.app', APP)
resources = APP / 'Contents/Resources'
# Remove prior developer-runtime experiments; only frozen runtime is shipped.
for name in ('runtime', 'python'):
    if (resources / name).exists():
        shutil.rmtree(resources / name)
helper = APP / 'Contents/Helpers/runtime'
shutil.copytree(ROOT / '.build/frozen/quelyt-runtime', helper)
info = APP / 'Contents/Info.plist'
plist = plistlib.loads(info.read_bytes()); plist.pop('QuelytWorkspace', None)
info.write_bytes(plistlib.dumps(plist))
resources.mkdir(exist_ok=True)
shutil.copy2(ROOT / 'docs/release/THIRD_PARTY_NOTICES.md', resources)
manifest = {'architecture': 'arm64', 'python': subprocess.check_output([str(ROOT/'.venv/bin/python'), '-V'], text=True).strip(), 'packages': {}}
for name in ('duckdb', 'sqlglot', 'pyinstaller'):
    manifest['packages'][name] = subprocess.check_output([str(ROOT/'.venv/bin/python'), '-c', f'import importlib.metadata; print(importlib.metadata.version({name!r}))'], text=True).strip()
(resources/'runtime-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
subprocess.run(['/usr/bin/codesign', '--force', '--deep', '--sign', '-', str(APP)], check=True)
print(APP)
