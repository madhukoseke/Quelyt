# ADR-010 — macOS packaging

Status: Provisional
Date: 2026-09-09

## Context
Development launch is not distributable installation.

## Options
Direct signed DMG; Mac App Store; developer-only bundle.

## Decision
**DECISION:** Developer bundle for M1; recommend signed/notarized direct Apple Silicon DMG for alpha.

## Evidence
Apple notarization workflow and local arm64 toolchain; no signing performed. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Bundle all runtime dependencies and license notices before alpha; no Python/Homebrew user requirement.

## Risks
Developer ID credentials, clean-machine launch, quarantine and updates untested.

## Revisit when
Before any user-facing download/distribution.
