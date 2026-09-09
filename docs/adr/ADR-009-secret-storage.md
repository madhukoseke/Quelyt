# ADR-009 — Secret storage

Status: Proposed; no secrets in M1
Date: 2026-09-09

## Context
Future database/model credentials must stay out of history/context.

## Options
Keychain; plaintext metadata; environment variables.

## Decision
**DECISION:** Use native macOS Keychain and opaque references; create no secret storage until needed.

## Evidence
macOS product boundary and privacy requirements; no credentials required by file-only M1. See [experiment report](../research/experiments.md) and [primary sources](../research/technology-sources.md).

## Consequences
Signing identity and access/deletion tests become connector gates.

## Risks
Not validated with signed application yet.

## Revisit when
First external provider/database connection.
