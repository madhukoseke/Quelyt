# Quelyt

Explore your data. Locally.

**Status:** Discovery Sprint 0 recommends **NARROW**. Milestone 1 is a native macOS developer build for constrained CSV/Parquet exploration. It is not a signed distributable or an autonomous AI analyst. The developer shell is a dark studio; SQL and results share that chrome.

Start with [Discovery Sprint 0](docs/product/discovery-sprint-0.md), [measured experiments](docs/research/experiments.md), [competitors](docs/research/competitive-landscape.md), [architecture](docs/architecture/overview.md) and [ADRs](docs/adr/README.md). The original [master plan](docs/QUELYT_MASTER_PLAN.md) is preserved.

## Run on this development Mac

Requires macOS, Swift Command Line Tools and Python 3.12. Runtime dependencies are pinned; they are development requirements, not intended end-user prerequisites.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
apps/macos/build.sh
open .build/Quelyt.app
```

Open or drop one CSV/Parquet file. Run queries against `dataset` using **⌘ Return**. The left sidebar is a product navigation rail: **Databases**, **History**, **Connections**, **Settings** and **AI**. Databases holds the current file, recents and columns; click a column to insert its quoted name at the caret. History loads or reruns saved SQL. Connections and AI are honest not-yet-available states (no remote databases, no Talk to Data). Hide the sidebar with **⌃B**. **Profile** keeps column stats on Databases rows and puts the generated SQL in the editor. Two-column results with a numeric Y axis (2–24 rows) draw a bar or line chart bound to that SQL. **Cancel** stops the disposable worker. The original file is never changed. File > Open Recent reopens a previous dataset. Select result rows and use **⌘C** to copy TSV with headers.

Example:

```sql
SELECT region, SUM(amount) AS revenue
FROM dataset
GROUP BY region
ORDER BY revenue DESC;
```

Files up to 256 MiB, at most 100 columns, 2,000 displayed result rows, 4,096 characters per cell and a 2 MiB complete JSON response. A conservative SQL subset rejects writes, multiple statements, external data sources, unapproved functions and CTEs. DuckDB has a 512 MB memory setting; this is not a whole-process memory cap. No spill directory. Engine interrupt deadline 15 s; native process deadline 30 s. Complex queries may be rejected or run out of memory. The grid still shows strings/NULL; a parallel typed `values` payload is used only for charting. Profile and bar/line charts are a developer-build slice, not a Tableau replacement or a full export model.

Each operation reimports a transient snapshot before external access is disabled. SQL traces and recent file paths are stored locally in SQLite (`~/Library/Application Support/dev.quelyt.desktop/history.sqlite`); result grids and credentials are not. Launching without a file argument reopens the last readable dataset if it still exists. The app needs this checkout and `.venv`; moving the checkout requires rebuilding. No model or cloud calls are made by the app. AI scripts under `experiments/` are separate, explicit local evaluations.

## Validate

```sh
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python experiments/discovery/engine.py
.venv/bin/python experiments/discovery/retrieval.py
.venv/bin/python experiments/discovery/investigation.py
.venv/bin/python experiments/discovery/held_out.py
```

The Ollama and PostgreSQL experiments have additional installed-tool prerequisites documented in [research](docs/research/experiments.md). They use synthetic data only. Do not pull new models to run the held-out suite.

## Known release gates

- Comparable Tauri/Swift/Electron editor+grid workload recorded; release framework still provisional pending packaging and editor completeness.
- Better local model; the held-out 50-case suite failed product gates (7/30 supported, 6/20 clarify/refuse). Talk to Data stays out of the app.
- OS filesystem/network confinement. SQL policy and DuckDB settings are defense in depth, not a complete sandbox.
- Broader native accessibility and drag/drop testing. Native file picker, query shortcut, cancellation, row copying, scrolling, dataset profile, two-column bar/line charts, local SQL history and the product navigation rail have been exercised in the developer shell.
- Bundled runtime, license notices, Developer ID signing/notarization and clean-machine offline installation.

See [Milestone 1 verification](docs/research/milestone-1.md) for actual checks and remaining gaps. No open-source license or business model has been selected.

## Editor and result controls

SQL highlighting and schema completion are available in the native editor (**Escape**, or Workspace > Complete SQL). **⌘1 / ⌘2 / ⌘3** focus SQL, results, and History. File > Save Query (**⌘S**) and Open Query use local `.sql` files. The titlebar holds Open, Run, Cancel, Profile and Copy.

Filter the returned rows with the Results search field; click a column header to sort. Chart toggles visibility for eligible results. **Export…** saves the original returned result as JSON with SQL, column types, typed values and truncation flags. Export and chart follow the executed query, not display filtering/sorting. Decimals export as exact strings; integers retain their original JSON representation. The current row/cell limits apply. See [UI/UX progress](docs/research/ui-ux-progress.md) for checks and remaining acceptance work.

Run `apps/macos/release-preflight.sh` to inspect distribution prerequisites. The developer bundle is expected to fail until its runtime, identity, notarization and offline release gates are resolved.
