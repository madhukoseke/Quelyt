# ADR-008 — SQL safety

Status: Accepted for M1; release hardening pending
Date: 2026-09-09

## Context
Read-only connection does not confine filesystem access.

## Options
Prompt-only; engine read-only; layered restriction.

## Decision
**DECISION:** Trust selected-file import separately, then disable external access/extensions, lock config, allow one scoped SELECT, impose budgets, use disposable worker.

## Evidence
Readonly probes allowed file read and COPY write; hardened probes blocked them; interrupt 108 ms. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
No agent access until stronger sandbox/privacy validation; conservative SQL subset may reject legitimate queries.

## Risks
Python process is not OS sandbox; engine defects or resource exhaustion remain possible.

## Revisit when
Before exposing generated SQL or opening alpha to untrusted workloads.


## Follow-up evidence — 2026-09-09
The [disposable isolation probe](../../experiments/isolation/README.md) blocks unselected file contents, writes and localhost networking while executing the real worker. Do not ship its deprecated sandbox-exec profile. The [supported helper design](../research/macos-isolation.md) remains unimplemented. Native worker launch now uses Python `-I -B`; streamed fetching and a complete 2 MiB JSON response budget reduce result amplification. Neither change establishes OS isolation in the shipping path.
