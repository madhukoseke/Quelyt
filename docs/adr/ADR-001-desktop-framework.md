# ADR-001 — Desktop framework

Status: Provisional
Date: 2026-09-09

## Context
Native macOS behavior and web-editor maturity pull in different directions.

## Options
Swift/AppKit; Tauri 2/Rust; Electron.

## Decision
**DECISION:** Use a Swift/AppKit development shell for M1; defer the release framework until a representative comparative prototype.

## Evidence
Native grid compiled/launched on local CLT; official process models in research/technology-sources.md. No comparative performance result. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Keep worker protocol independent of UI. A throwaway shell costs less than prematurely freezing framework.

## Risks
Native editor completion and bundled Python may cost more than Tauri/Rust.

## Revisit when
Before production editor investment or alpha packaging.
