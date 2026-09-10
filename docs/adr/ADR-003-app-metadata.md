# ADR-003 — Application metadata

Status: Accepted for local history
Date: 2026-09-09

## Context
History and semantic definitions should remain local.

## Options
SQLite; JSON files; analytical database.

## Decision
**DECISION:** SQLite with a versioned schema for action traces and recent sources. Store SQL, outcome, timing and chart kind — not result grids or credentials. Path override `QUELYT_HISTORY_PATH` for tests; default `~/Library/Application Support/dev.quelyt.desktop/history.sqlite`.

## Evidence
SQLite application-storage guidance in technology-sources.md. Implementation and tests in `src/quelyt/history.py` and `tests/test_history.py`. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Metadata lifecycle is separate from DuckDB snapshots. Oldest traces prune after 500 rows. Users can delete a trace or clear history. Source files are never modified.

## Risks
Restore/backup of the history file is untested. Crash mid-write relies on SQLite defaults. Paths to moved files remain until deleted.

## Revisit when
Saved named queries, semantic definitions, or a need to store bounded result previews.
