# ADR-001 — Desktop framework

Status: Provisional
Date: 2026-09-09

## Context
Native macOS behavior and web-editor maturity pull in different directions.

## Options
Swift/AppKit; Tauri 2/Rust; Electron.

## Decision
**DECISION:** Keep the Swift/AppKit development shell. Defer a release-framework freeze until packaging and editor-completeness are measured. The query worker remains independent of UI.

## Evidence
Comparable editor/grid/query/cancel probes on the same DuckDB worker: [framework comparison](../research/framework-comparison.md). Native had the lowest process-tree RSS and fastest median dataset-ready launch on this Mac. Tauri and Electron had slightly faster UI round trips and ship CodeMirror. See also [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Continue shipping the AppKit developer app. A throwaway Tauri/Electron probe remains available. Do not quote native executable size as product download size.

## Risks
Native editor completion and bundled Python may still cost more than Tauri/Rust for a polished SQL editor. WebKit/Electron process trees cost more resident memory here.

## Revisit when
Before production editor investment or alpha packaging, or if CodeMirror-quality editing becomes the blocking P0 gap.
