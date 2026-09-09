# ADR-002 — Analytical engine

Status: Accepted for P0
Date: 2026-09-09

## Context
Local columnar file exploration is the wedge.

## Options
DuckDB; SQLite imports; external PostgreSQL.

## Decision
**DECISION:** Use DuckDB, pinned to the tested version; one worker owns its transient database.

## Evidence
Million-row CSV/Parquet/JSON benchmark and interrupt result in research/experiments.md. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Fast analytical path; initial selected file is materialized in memory for confinement.

## Risks
Import cost and RAM scale with expanded data; explicit limits needed. DuckDB is not an OS sandbox.

## Revisit when
Large-file constraints or packaging fail measured targets.
