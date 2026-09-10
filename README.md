# Quelyt

Explore your data. Locally.

**Status:** Discovery Sprint 0 recommends **NARROW**. Milestone 1 is a native macOS developer build for constrained CSV/Parquet exploration. It is not a signed distributable or an autonomous AI analyst.

Start with [Discovery Sprint 0](docs/product/discovery-sprint-0.md), [measured experiments](docs/research/experiments.md), [competitors](docs/research/competitive-landscape.md), [architecture](docs/architecture/overview.md) and [ADRs](docs/adr/README.md). The original [master plan](docs/QUELYT_MASTER_PLAN.md) is preserved.

## Run on this development Mac

Requires macOS, Swift Command Line Tools and Python 3.12. Runtime dependencies are pinned; they are development requirements, not intended end-user prerequisites.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
apps/macos/build.sh
open .build/Quelyt.app
```

Open or drop one CSV/Parquet file. Run queries against `dataset` using **⌘ Return**. **Profile dataset** computes row counts, null rates, distinct counts and min/max per column, and puts the generated SQL in the editor. Two-column results with a numeric Y axis (2–24 rows) draw a bar or line chart bound to that SQL. **Cancel** stops the disposable worker. The original file is never changed. Schema and query results appear locally. Standard File/Open and text-edit menus are available. Select result rows and use **⌘C** to copy TSV with headers.

Example:

```sql
SELECT region, SUM(amount) AS revenue
FROM dataset
GROUP BY region
ORDER BY revenue DESC;
```

Files up to 256 MiB, at most 100 columns, 2,000 displayed result rows, 4,096 characters per cell and a 2 MiB complete JSON response. A conservative SQL subset rejects writes, multiple statements, external data sources, unapproved functions and CTEs. DuckDB has a 512 MB memory setting; this is not a whole-process memory cap. No spill directory. Engine interrupt deadline 15 s; native process deadline 30 s. Complex queries may be rejected or run out of memory. The grid still shows strings/NULL; a parallel typed `values` payload is used only for charting. Profile and bar/line charts are a developer-build slice, not a Tableau replacement or a full export model.

Each operation reimports a transient snapshot before external access is disabled. No durable imported data or history is stored. The app needs this checkout and `.venv`; moving the checkout requires rebuilding. No model or cloud calls are made by the app. AI scripts under `experiments/` are separate, explicit local evaluations.

## Validate

```sh
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python experiments/discovery/engine.py
.venv/bin/python experiments/discovery/retrieval.py
.venv/bin/python experiments/discovery/investigation.py
```

The Ollama and PostgreSQL experiments have additional installed-tool prerequisites documented in [research](docs/research/experiments.md). They use synthetic data only.

## Known release gates

- Comparable Tauri/Swift/Electron editor+grid workload recorded; release framework still provisional pending packaging and editor completeness.
- Better local model and held-out correctness, ambiguity and tool-safety evaluation; the installed 1B model failed the initial quality test.
- OS filesystem/network confinement. SQL policy and DuckDB settings are defense in depth, not a complete sandbox.
- Broader native accessibility and drag/drop testing, saved history. Native file picker, query shortcut, cancellation, row copying, scrolling, dataset profile and two-column bar/line charts have been exercised.
- Bundled runtime, license notices, Developer ID signing/notarization and clean-machine offline installation.

See [Milestone 1 verification](docs/research/milestone-1.md) for actual checks and remaining gaps. No open-source license or business model has been selected.
