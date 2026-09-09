# ADR-006 — Agent architecture

Status: Proposed
Date: 2026-09-09

## Context
Generated answers need inspectable evidence and constrained operations.

## Options
One-shot SQL; bounded tool loop; general agent framework.

## Decision
**DECISION:** Plan a small bounded tool loop after model gate: schema, read query, chart proposal; no shell/write tool.

## Evidence
Scripted attribution reconciles net change; no model loop superiority measured. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Trace records context, SQL, results, errors and timings, not chain-of-thought.

## Risks
Tool budgets do not prevent semantic mistakes or prompt injection.

## Revisit when
Held-out multi-step benchmark demonstrates improved correct answers.
