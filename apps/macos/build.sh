#!/bin/bash
set -euo pipefail
QUELYT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUELYT_APP="$QUELYT_ROOT/.build/Quelyt.app"
mkdir -p "$QUELYT_APP/Contents/MacOS" "$QUELYT_APP/Contents/Resources/python"
cp "$QUELYT_ROOT/apps/macos/Quelyt.swift" "$QUELYT_ROOT/.build/main.swift"
swiftc -O -module-cache-path /tmp/quelyt-swift-cache \
  "$QUELYT_ROOT/apps/macos/Theme.swift" \
  "$QUELYT_ROOT/apps/macos/SQLEditor.swift" \
  "$QUELYT_ROOT/apps/macos/KeyTable.swift" \
  "$QUELYT_ROOT/apps/macos/TypeHeader.swift" \
  "$QUELYT_ROOT/apps/macos/InsetHeader.swift" \
  "$QUELYT_ROOT/apps/macos/DestinationPages.swift" \
  "$QUELYT_ROOT/apps/macos/Sidebar.swift" \
  "$QUELYT_ROOT/apps/macos/CommandPalette.swift" \
  "$QUELYT_ROOT/.build/main.swift" \
  -o "$QUELYT_APP/Contents/MacOS/Quelyt"
cp "$QUELYT_ROOT/src/quelyt/worker.py" "$QUELYT_APP/Contents/Resources/python/worker.py"
cp "$QUELYT_ROOT/src/quelyt/history.py" "$QUELYT_APP/Contents/Resources/python/history.py"
python3 - "$QUELYT_APP" "$QUELYT_ROOT" <<'PY'
import pathlib, plistlib, shutil, subprocess, sys

app = pathlib.Path(sys.argv[1])
root = pathlib.Path(sys.argv[2])
runtime = app / 'Contents' / 'Resources' / 'runtime'
python = root / '.venv' / 'bin' / 'python'
if not python.is_file():
    python = pathlib.Path(sys.executable)

# Recreate the venv when the interpreter was previously rewritten.
python_bin = runtime / 'bin' / 'python3'
needs_venv = True
if python_bin.exists():
    try:
        probe = subprocess.run([str(python_bin), '-c', 'print(1)'], capture_output=True, timeout=5)
        needs_venv = probe.returncode != 0
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        needs_venv = True
if needs_venv:
    if runtime.exists():
        shutil.rmtree(runtime)
    subprocess.check_call([str(python), '-m', 'venv', '--copies', str(runtime)])

venv_python = runtime / 'bin' / 'python3'
if not venv_python.exists():
    venv_python = runtime / 'bin' / 'python'

def site_packages(py):
    return pathlib.Path(subprocess.check_output(
        [str(py), '-c', 'import site; print(site.getsitepackages()[0])'], text=True
    ).strip())

src_py = root / '.venv' / 'bin' / 'python'
if src_py.is_file():
    src_site = site_packages(src_py)
    dest_site = site_packages(venv_python)
    skip = {'pip', 'setuptools', 'pkg_resources', 'wheel', '_distutils_hack'}
    for item in src_site.iterdir():
        name = item.name.split('-')[0]
        if name in skip or item.name.startswith('pip') or item.name.startswith('setuptools') or item.name.startswith('wheel') or item.name.endswith('.pth'):
            continue
        dest = dest_site / item.name
        if item.is_dir():
            if dest.exists():
                shutil.rmtree(dest)
            shutil.copytree(item, dest)
        else:
            shutil.copy2(item, dest)

probe = subprocess.run([str(venv_python), '-c', 'import duckdb, sqlglot'], capture_output=True, timeout=30)
if probe.returncode != 0:
    subprocess.check_call([str(venv_python), '-m', 'pip', 'install', '--disable-pip-version-check', '-q', '-r', str(root / 'requirements.txt')])

def relocate(binary: pathlib.Path):
    if not binary.is_file() or binary.is_symlink():
        return
    try:
        out = subprocess.check_output(['/usr/bin/otool', '-L', str(binary)], text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return
    libdir = binary.parent
    for line in out.splitlines()[1:]:
        path = line.split()[0].strip()
        if not path.startswith('/') or path.startswith('/usr/lib') or path.startswith('/System/'):
            continue
        if 'Python.framework' in path:
            continue
        source = pathlib.Path(path)
        if not source.exists():
            continue
        dest = libdir / source.name
        if not dest.exists():
            shutil.copy2(source, dest)
        subprocess.call(['/usr/bin/install_name_tool', '-change', path, '@loader_path/' + source.name, str(binary)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

for so in runtime.rglob('*.so'):
    relocate(so)

notices_src = (root / 'docs' / 'release' / 'THIRD_PARTY_NOTICES.md').read_text()
license_text = ''
for candidate in [
    pathlib.Path(sys.base_prefix) / 'LICENSE',
    pathlib.Path(sys.base_prefix) / 'LICENSE.txt',
    pathlib.Path(sys.base_prefix) / 'lib' / f'python{sys.version_info.major}.{sys.version_info.minor}' / 'LICENSE.txt',
]:
    if candidate.is_file():
        license_text = candidate.read_text(errors='replace')
        break
if license_text:
    notices = notices_src.replace(
        'The developer app bundle copies a CPython interpreter into `Contents/Resources/runtime` at build time. The exact license text from that interpreter is written into the bundled copy of this file. Nested standard-library and OpenSSL notices remain a remainder, not a complete redistribution audit.',
        'Bundled CPython ' + sys.version.split()[0] + ' from ' + sys.base_prefix + '.\n\n```text\n' + license_text.strip() + '\n```\n\nNested standard-library and OpenSSL notices remain a remainder, not a complete redistribution audit.'
    )
else:
    notices = notices_src + f'\n\nBundled CPython {sys.version.split()[0]} from {sys.base_prefix}. Nested stdlib/OpenSSL notices remain a remainder.\n'
(app / 'Contents' / 'Resources' / 'THIRD_PARTY_NOTICES.md').write_text(notices)

plist = {
    'CFBundleExecutable': 'Quelyt',
    'CFBundleIdentifier': 'dev.quelyt.desktop',
    'CFBundleName': 'Quelyt',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '0.1.0',
    'CFBundleVersion': '1',
    'LSMinimumSystemVersion': '13.0',
    'NSHighResolutionCapable': True,
}
(app / 'Contents' / 'Info.plist').write_bytes(plistlib.dumps(plist))
PY
printf 'Developer build: %s\n' "$QUELYT_APP"
