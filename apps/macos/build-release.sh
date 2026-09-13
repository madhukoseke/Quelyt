#!/bin/bash
set -euo pipefail
QUELYT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$QUELYT_ROOT"
bash apps/macos/build.sh
export PYINSTALLER_CONFIG_DIR="$QUELYT_ROOT/.build/pyinstaller-cache"
.venv/bin/python -m PyInstaller --noconfirm --clean --onedir --name quelyt-runtime \
  --paths src --collect-submodules sqlglot --hidden-import _duckdb \
  --distpath .build/frozen --workpath .build/freeze-work --specpath .build \
  src/quelyt/runtime_entry.py
python3 apps/macos/package-release.py
