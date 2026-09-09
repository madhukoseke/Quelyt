# ADR-003 — Application metadata

Status: Proposed; deferred beyond M1
Date: 2026-09-09

## Context
History and semantic definitions should remain local.

## Options
SQLite; JSON files; analytical database.

## Decision
**DECISION:** Recommend SQLite with migrations; do not scaffold until persistent state exists.

## Evidence
SQLite application-storage guidance in technology-sources.md. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Separate lifecycle from analytical data and never store raw credentials.

## Risks
Migration/restore tests still required; no implementation evidence yet.

## Revisit when
First saved query/history feature.
