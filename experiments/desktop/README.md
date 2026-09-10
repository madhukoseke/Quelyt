# Native desktop experiment

`Probe.swift` is the disposable 100,000-row AppKit baseline. It compiled and launched with Swift 6.1.2. It does not integrate an engine, simulate streaming AI, or establish a framework performance winner.

The M1 development shell in `apps/macos/` subsequently integrates DuckDB in a disposable process and the native editor/grid. Its own-view bitmap rendering exposed missing content width and a zero-sized schema view; both were fixed and rerendered.

To build the baseline:

```sh
swiftc -module-cache-path /tmp/quelyt-swift-cache experiments/desktop/Probe.swift -o experiments/desktop/probe
```

To test the integrated shell after generating the million-row engine fixture:

```sh
apps/macos/build.sh
open -n .build/Quelyt.app --args "$PWD/experiments/discovery/data/sales.parquet" --smoke-test "$PWD/experiments/desktop/native-smoke-results.json"
```

The smoke harness invokes the app's action methods and actual worker lifecycle. It validates preview, dataset profile, rejected write and cancellation. It is not an OS-level click/keyboard/drag test. `--snapshot /absolute/output.png` renders the application's own view after a successful query for layout inspection. Generated app bundles/binaries are ignored.

**OPEN QUESTION:** full Accessibility/Screen Recording permissions for automated pointer/keyboard inspection; at the time of this run those remained pending. Comparable Tauri/Electron editor+grid+query/cancel probes and launch/RSS measurements are in [framework comparison](../research/framework-comparison.md). Release signing and actual scrolling/copy/resize/drop/shortcuts in the shipping app remain. The 167 KB native executable size excludes Python/DuckDB and must not be quoted as product download size.
