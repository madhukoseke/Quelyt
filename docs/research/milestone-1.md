# Milestone 1 verification — 2026-09-09

**Implemented:** native macOS developer shell, selected CSV/Parquet opening/drop handler, schema display, plain SQL editing, bounded result table, dataset profile, two-column bar/line charts, error display, query cancellation and hard process deadline. Worker imports a transient dataset, validates a conservative SQL subset, disables external access/extensions, locks engine settings, and caps rows/cells/column names/output. No network calls, cloud SDK, telemetry or model integration exists in the application.

**EXPERIMENTAL RESULT:** 16 Python integration tests pass: CSV aggregate/source preservation, typed values, Parquet, quoted filename and column/null behavior, rejected statements/functions/sources, independent engine access restriction, row/cell/output/column limits, timeout, malformed/missing file, JSON process protocol, dataset profile and chart heuristic.

**EXPERIMENTAL RESULT:** optimized native Swift developer bundle builds. Loading the generated million-row Parquet through the actual native app returned 200 rows; observed worker elapsed ~58 ms including snapshot import. This is one warm fixture, excludes process/startup/display latency, and is not a cold-start guarantee.

**EXPERIMENTAL RESULT:** own-view render inspected; initial pane-width and schema-size bugs fixed. Corrected render is `.build/quelyt-preview-2.png` (ignored generated artifact). The app uses native light appearance for this iteration. No dark-mode support claim.

**EXPERIMENTAL RESULT:** all four native action-method checks passed (open preview, count, rejected write, cancellation). Results are recorded in `experiments/desktop/native-smoke-results.json`. It runs the actual process controller and action methods, not synthetic OS input. Physical keyboard, file-picker, drag/drop and accessibility validation remain pending because Computer Use permissions were not granted during the run. Two attempts returned the same pending-permissions response; independent testing continued.

## Review findings and limits

- Read-only DuckDB alone is insufficient; the observed bypass shaped both the implementation and ADR-008.
- The query worker is not an OS sandbox. Engine memory_limit is not total RSS. Before agent-generated SQL or public alpha, add OS confinement and resource testing.
- Python runtime and absolute workspace path are development-only. Bundle runtime/dependencies, resolve licenses and perform signed/notarized clean-machine testing before distribution.
- CTEs, UNION and unapproved functions are deliberately rejected; this is not a full SQL-client grammar.
- Every query reimports. Large-file lazy opening, persistent dataset handles and copy-vs-open UX need measurement.
- Result values in the grid remain display strings. A parallel typed `values` / `column_kinds` payload exists for bar/line charting; it is not a full export model. Dataset profile covers null %, distinct count and min/max. Top-k values, histograms, relationship guesses, history and AI remain later work.
- No end-to-end agent, embeddings comparison, paid service, real database connection or production packaging was tested.

**Status:** M1 implementation and automated core checks delivered; native physical-interaction acceptance remains open. Sprint 0 is complete as an evidence-based discovery deliverable, not as validation of all hypotheses. Do not call this the complete MVP.


## Continuation — native QA and worker bounds

Computer Use permissions are now available. Actual file-picker, SQL shortcut, write rejection, cancellation, row copying and scrolling checks passed; see [native interaction QA](native-interaction-qa.md). Core tests increased to 13, including exact serialized Unicode response bounds. Worker launch uses Python isolated mode; result fetching streams rows, and the complete JSON response is capped at 2 MiB. The timing display is formatted to one decimal.

The [OS isolation experiment](../../experiments/isolation/README.md) successfully ran the real worker while its diagnostic probes blocked unselected content reads, file writes and loopback network access. This deprecated mechanism remains outside the app; supported signed App Sandbox/XPC isolation is still a release gate.

## Continuation — profile and charts

The worker now returns typed `values` and `column_kinds` alongside string grid rows, still inside the 2 MiB JSON budget. `action: profile` computes per-column null %, distinct count and min/max in DuckDB after the transient snapshot, records the generated SQL, and does not use the user-SQL allowlist. Two-column results with 2–24 untruncated rows and a numeric Y axis suggest `bar` or `line`; the Swift shell draws that chart from the executed SQL. This is not a general chart grammar or Tableau replacement. The native smoke harness checks profile instead of Count rows.
