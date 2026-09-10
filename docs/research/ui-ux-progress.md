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

## Implemented continuation — editor and results

The earlier pending list is superseded by this section:

- Native SQL keyword/comment/string highlighting, undo support, quoted schema-name completion via Escape or Workspace > Complete SQL. Parser error locations focus the editor at the reported line/column; runtime/binder errors remain message-only.
- Save Query / Open Query use local `.sql` files and native dialogs; query folders are organized with the filesystem rather than an in-app folder model.
- Filter returned rows, click column headers for numeric-aware sorting, and toggle eligible charts. These controls operate on the bounded returned result. Chart and export use the original executed query result, unaffected by display filtering/sorting.
- Export writes the worker's original JSON bytes, preserving large integers without an AppKit round trip. SQL, column types, typed values and truncation flags accompany the returned rows. DECIMAL values are exact strings with column types; dates are strings, non-finite floats become null, and display/string limits still apply. Decimal-valued charts are deferred rather than approximating export values.
- Workspace shortcuts Cmd-1/2/3 focus editor/results/history. Charts expose labels and values to accessibility. Negative bars extend from zero.
- Native build and seven new native regression checks pass: highlighting preserves text/selection, quoted completion, filtering, numeric sorting, parser location, chart accessibility values and chart toggle. Four original native smoke checks also pass. Updated loaded layout visually inspected using own-view capture.

Remaining: physical interaction acceptance for the new file dialogs/completion, VoiceOver session, smallest-window and physical drag/drop acceptance; supported OS confinement; relocatable runtime bundle; complete bundled-library license audit; Developer ID signing/notarization; clean-machine offline installation. Existing AI and database-connection research gates remain unchanged.

Release preparation includes `apps/macos/release-preflight.sh` and dependency notices in `docs/release/THIRD_PARTY_NOTICES.md`. The preflight currently fails as expected for the developer build; it does not provision or claim OS isolation.

Final continuation verification: 31 Python tests, seven native UI regression checks, and four native smoke checks pass on the final build.

## Implemented continuation — native control plane

Working sessions now use a titled window and `NSToolbar` instead of the editorial hero. `NSSplitViewController` hosts a collapsible full-height sidebar (default ~240pt, **⌃B** or the toolbar sidebar button) and the SQL/results/chart data plane. Drop-on-window still opens one CSV/Parquet file.

The sidebar owns dataset identity (name, format, row/column counts, source unchanged), up to seven recents from local history, a searchable column list, and history that fills leftover height. Clicking a column inserts the quoted identifier at the SQL caret. Profile statistics decorate the same column rows (`null % · distinct · min/max`) and survive later queries; generated profile SQL still lands in the editor. This is not VoiceOver, physical drag/drop, App Sandbox, or a relocatable runtime.

Native build succeeds. 31 Python tests pass. Twelve native UI regression checks pass, including quoted column insert, profile-stat retention, column filter, recents cap and sidebar collapse. Four native smoke checks pass on the million-row Parquet fixture. Loaded layout inspected via own-view capture.
