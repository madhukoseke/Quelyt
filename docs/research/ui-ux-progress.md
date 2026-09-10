# Workspace UI/UX — 2026-09-10

Direction selected by the user: quiet native workspace, clear hierarchy, generous spacing, focused SQL/results. Continue the AppKit developer shell; release framework remains provisional.

## Implemented and verified

- CSV/Parquet opening, transient DuckDB snapshots, schema, SQL execution, bounded results, cancellation and source-preserving query policy.
- Dataset profile (null rates, distinct counts, min/max), simple result-bound bar/line charts, local SQLite query history and recent sources.
- This UI pass adds a restrained native toolbar, explicit Query / Results hierarchy, readable column names and types, visible Copy rows action, keyboard shortcut hint, and empty/loading/no-results/error/cancelled states.
- History and charts remain integrated. Missing history source files now prevent rerunning against an unrelated open dataset.
- Swift optimized build succeeds. All 20 Python worker/history tests pass. Four native action checks pass: preview, profile, write rejection, cancellation.
- Actual native control checks: Profile dataset shows correct statistics for a three-row synthetic fixture; Cmd-Return with an empty filter shows No rows returned; DELETE shows the policy rejection; aggregate restores two result rows and a chart (East 40, West 16). Initial own-view render inspected.

## Pending, in priority order

1. Broader accessibility and layout acceptance: VoiceOver reading order, chart data descriptions, smallest-window layout, physical drag/drop, keyboard-only history and result selection.
2. SQL editing improvements: syntax highlighting, schema completion, and error locations. Current editor is plain native text; CodeMirror exists only in disposable comparison probes.
3. Results workflow: sorting/filtering, deliberate chart controls, typed export, saved-query organization. Current copy is selected rows as TSV.
4. Supported OS confinement, bundled runtime, license notices, signing/notarization and clean-machine offline installation before public distribution.
5. AI remains research-only; do not expose Talk to Data until model/evaluation gates pass. Real database connections and multi-dataset work remain outside this slice.

The developer app is usable for constrained local exploration, not the complete planned MVP. Tests and synthetic measurements do not establish usability with target users.
