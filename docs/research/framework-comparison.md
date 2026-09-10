# Desktop framework comparison — 2026-09-09

Same DuckDB worker and million-row synthetic `sales.parquet`. Three shells: Swift/AppKit developer app, Tauri 2/WKWebView probe, Electron 44/Chromium probe. Warm-cache, this development Mac. Not a 60fps, cold-disk, or signed-download claim.

**FACT (this run):** all three executed preview (`SELECT * LIMIT 200`), regional aggregate (East=32,999,967 / West=16,500,033), write rejection, and cancellation of a cross join.

| Shell | Preview median round trip | Aggregate median | Write rejected | Cancelled | 100k-row grid create | Large editor insert |
|---|---|---|---|---|---|---|
| Native AppKit | 221 ms | 213 ms | yes | yes | 16 ms (100,000 table rows) | 1.9 ms (`NSTextView` assign) |
| Tauri / WKWebView | 159 ms | 166 ms | yes | yes | 4 ms | 46 ms (CodeMirror) |
| Electron / Chromium | 154 ms | 158 ms | yes | yes | 9 ms | 29 ms (CodeMirror) |

Round trips include snapshot import and IPC. Worker policy is identical; UI framework is not the SQL boundary.

Fresh-process launch to first dataset-ready (`QUELYT_READY`), three alternating-order runs:

| Shell | Median ready | Approx. RSS sum | Processes counted |
|---|---|---|---|
| Native | 423 ms | 84 MiB | 1 |
| Tauri | 654 ms | 178 MiB | 1 + 3 new WebKit XPC helpers |
| Electron | 690 ms | 367 MiB | 4 (main + helpers) |

RSS sums descendants plus newly created WebKit helpers and may double-count shared pages. Native executable size still excludes Python/DuckDB.

Raw JSON: [native-results.json](../../experiments/frameworks/native-results.json), [tauri-results.json](../../experiments/frameworks/tauri-results.json), [electron-results.json](../../experiments/frameworks/electron-results.json), [launch-results.json](../../experiments/frameworks/launch-results.json). Reproduce from [experiments/frameworks/README.md](../../experiments/frameworks/README.md).

**Limits:** one machine, warm cache, synthetic four-column fixture. Native stream timings are `displayIfNeeded` polling, not vsync. Web probes virtualize ~20 DOM rows; native keeps 100,000 model rows. CodeMirror schema completion exists only in the web probes. Packaging, drag/drop parity, VoiceOver, and signed size were not compared.

**Consequence:** keep the Swift development shell. Do not freeze a release framework. The worker protocol stays UI-independent. Tauri remains the leading web-editor alternative if CodeMirror/completion outweighs process-tree memory.
