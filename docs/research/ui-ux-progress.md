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

Working sessions now use a titled window and `NSToolbar` instead of the editorial hero. `NSSplitViewController` hosts a collapsible full-height sidebar (default ~268pt, **⌃B** or the toolbar sidebar button) and the SQL/results/chart data plane. Drop-on-window still opens one CSV/Parquet file.

The sidebar is a dark product navigation rail (Dokploy/Databricks-style), not a stacked inspector. Explore: **Databases** (open, recents, searchable columns) and **History**. Workspace: **Connections** and **AI** show not-yet-available copy; **Settings** states local-only facts. Selecting a row switches sidebar context only; SQL/results stay in the main pane. Clicking a column still inserts the quoted identifier. Profile statistics decorate Databases column rows and survive later queries. No fake cloud orgs, Docker, Swarm, remote connections, or AI chat.

The developer shell is a cohesive dark studio mapped from [DB Pro](https://www.dbpro.app/) dark CSS tokens and product screenshots (tokens below). SQL/results no longer sit on a light paper pane.

Native build succeeds. 31 Python tests pass. Native UI regression checks include quoted column insert, profile-stat retention, column filter, recents cap, nav destination selection, gated Connections/AI states, and sidebar collapse. Four native smoke checks pass on the million-row Parquet fixture.

## Design tokens — DB Pro dark studio (2026-09-10)

Extracted from live CSS (`:root` / `.dark` on dbpro.app) plus product screenshots (`editor-feature-1`, `data-browser-feature-1`, `inspector-hero`). Marketing copy and images are not stored in this repo. AppKit maps Geist/IBM Plex to SF Pro + SF Mono.

Source notes: the public site defaults to a warmer light theme (`#f5f4f3`, brand `#2563eb`). Dark mode and the desktop app chrome are near-black navy, not OLED-pure black. Primary accent is **blue**, not teal. Teal `#00bb7f` is used for table/success marks; amber `#f99c00` for dirty cells; red `#ff6568` for diffs/errors.

### Color

| Token | Hex | AppKit use |
| --- | --- | --- |
| canvas / background | `#0a0d14` | Window, editor, grid |
| surface / sidebar / card | `#11151f` | Nav rail, elevated chrome |
| muted / accent / selected pill | `#1a2030` | Nav selection, hover, header chip |
| input | `#2a3040` | Search/input fill |
| line / border | `#222734` | Hairline borders |
| line-strong | `#333a49` | Chart axes, stronger rules |
| ink / foreground | `#e7e9ee` | Primary text |
| ink-muted | `#9aa2b1` | Secondary labels |
| faint | `#69707e` | Section headers, comments, NULL |
| brand / primary / ring | `#3b82f6` | Run button, focus, empty-state icon |
| brand-hover / SQL keyword | `#60a5fa` | Keyword highlight, hover |
| brand-deep | `#1e3a8a` | Pressed/deep brand |
| success / chart-2 | `#00bb7f` | Local badge, chart series, strings |
| warn / chart-3 | `#f99c00` | Numeric literals |
| danger | `#ff6568` | Errors (status copy) |

Light-theme site tokens (`#f5f4f3`, `#2563eb`, sidebar `#fff`) are documented for contrast only; the developer app does not use them.

### Typography

| Role | DB Pro | Quelyt AppKit |
| --- | --- | --- |
| UI | Geist Sans / IBM Plex Sans, 400–600 | SF Pro, 11–13pt UI, 12pt semibold section titles |
| Marketing display | IBM Plex Serif | Not used in-app |
| SQL / grid | Geist Mono | SF Mono 13pt editor, 12pt cells |
| Weights | 400 / 500 / 600 / 700 | regular / medium / semibold |
| Section labels | ~11pt muted | 11pt medium, faint |

### Iconography

Outline Lucide-style marks at ~13–16px. Quelyt uses SF Symbols, medium weight: `cylinder.split.1x2`, `clock`, `link`, `gearshape`, `sparkles`, `play.fill`. No filled candy icons.

### Spacing, radius, elevation

| Measure | Value |
| --- | --- |
| Radius (CSS `--radius`) | 10pt |
| Selected pill | 8pt |
| Hairline | 1pt `#222734` |
| Sidebar default | ~268pt (220–340) |
| Nav row | 34pt |
| Result row | 32pt |
| Editor inset | 15×14 |
| Elevation | Flat surfaces + hairline, no drop shadows |

### Motion

Selected pill and hover fill `#1a2030` (hover at 55% alpha). No bounce. Tracking-area hover on nav rows. Focus uses brand ring via `darkAqua`.

### Product chrome observed (screenshots)

- Unified dark titlebar; icon-only tools; blue primary action (`Run Query` / `Insert`).
- Thin left rail + schema list with selected row wash.
- Spreadsheet grid: same canvas as editor, vertical hairlines, type glyphs in headers.
- SQL: blue keywords, green table marks in autocomplete, dark completion card.

Quelyt does not copy tabs, ER diagrams, inline row editing, pending-change inspector, or remote connections. Remaining gaps vs DB Pro: no command palette, no tab strip, no type glyphs in grid headers, no Lucide icon set (SF Symbols instead), no Geist webfonts (system fonts), no inspector pane.
