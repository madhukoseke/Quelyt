# ADR-005 — AI runtime

Status: Provisional
Date: 2026-09-09

## Context
Offline capability must not imply an unreliable default analyst.

## Options
Existing Ollama; embedded llama.cpp/MLX; optional cloud.

## Decision
**DECISION:** Use existing Ollama for evaluations only; no production model default yet.

## Evidence
Installed llama3.2:1b matched 9/20 denotations on the development smoke set; one false-confidence ordering case. The same digest scored 7/30 supported and 6/20 expected clarify/refuse on the 50-case held-out split, with 2 unsafe attempts and 0 unsafe executions in the harness. See [experiment report](../research/experiments.md), [held-out eval](../evals/held-out/README.md) and [primary sources](../research/technology-sources.md).

## Consequences
Preserve deterministic use without AI. No automatic cloud fallback.

## Risks
Localhost can proxy cloud; residency/privacy and stronger model quality unproven.

## Revisit when
A pinned model passes held-out correctness/tool/safety thresholds.
