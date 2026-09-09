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
Installed llama3.2:1b matched 9/20 denotations; one false-confidence ordering case. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Preserve deterministic use without AI. No automatic cloud fallback.

## Risks
Localhost can proxy cloud; residency/privacy and stronger model quality unproven.

## Revisit when
A pinned model passes held-out correctness/tool/safety thresholds.
