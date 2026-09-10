# Disposable desktop framework probes

Same DuckDB worker, same synthetic `sales.parquet` / `sales.csv` fixtures, three shells: Swift/AppKit, Tauri 2/WKWebView, Electron/Chromium.

This is not a 60fps claim, a download-size claim, or a permanent framework winner.

## Fixtures

```sh
.venv/bin/python experiments/discovery/engine.py
```

## Native comparison

```sh
apps/macos/build.sh
open -n .build/Quelyt.app --args "$PWD/experiments/discovery/data/sales.parquet" --compare "$PWD/experiments/frameworks/native-results.json"
```

## Web probes

```sh
cd experiments/frameworks
npm run build:web
env -u ELECTRON_RUN_AS_NODE QUELYT_COMPARE=1 ./node_modules/electron/dist/Electron.app/Contents/MacOS/Electron electron.cjs
env -u ELECTRON_RUN_AS_NODE QUELYT_COMPARE=1 src-tauri/target/release/quelyt-tauri-probe
```

## Launch / RSS

```sh
.venv/bin/python experiments/frameworks/measure_launch.py
```

Writes `launch-results.json`. RSS sums descendants plus new WebKit helpers and may double-count shared pages.

Unset `ELECTRON_RUN_AS_NODE` when launching the Electron binary; that flag makes `require('electron').app` undefined in this environment.

