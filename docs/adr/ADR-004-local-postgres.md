# ADR-004 — Bundled PostgreSQL

Status: Accepted scope decision
Date: 2026-09-09

## Context
Managed local PostgreSQL is attractive but unrelated to file investigation.

## Options
Bundle now; connect existing servers later; defer entirely.

## Decision
**DECISION:** Defer bundling to P3; evaluate least-privilege remote connection after file wedge.

## Evidence
Three successful isolated lifecycle cycles; selected installed dirs total ~155 MB. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Avoid binary distribution, backups and upgrades in P0.

## Risks
Prototype depends on installed EDB binaries; relocation/upgrade unproven.

## Revisit when
Users demonstrate repeated need for a managed operational database.
