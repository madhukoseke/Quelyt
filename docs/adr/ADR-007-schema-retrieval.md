# ADR-007 — Schema retrieval

Status: Accepted for initial scope
Date: 2026-09-09

## Context
Small file schema does not require a context platform.

## Options
Whole small schema; lexical/BM25; embeddings; graph service.

## Decision
**DECISION:** Pass bounded selected-dataset schema first; use lexical lookup when needed, defer embeddings/graph infrastructure.

## Evidence
Synthetic retrieval 0.8 recall; graph expansion did not improve synonyms. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Explicit context size budget and user selection; keep definitions editable later.

## Risks
Toy benchmark understates enterprise ambiguity.

## Revisit when
Measured recall/context budget fails on real multi-table user tasks.
