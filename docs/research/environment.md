# Development environment — 2026-09-09

**FACT:** repository initially contained only `docs/QUELYT_MASTER_PLAN.md`; no application, tests, package configuration or repository-local AGENTS.md. The master plan was read in full. No repository-specific Git worktree was present; do not infer a clean repo from an ancestor Git repository.

**FACT:** Apple M3 MacBook Air, arm64, 16 GB RAM, macOS 15.5. Command Line Tools selected, Swift 6.1.2, Rust 1.93.1, Node 22.22.3, Python 3.12, uv 0.9.15. Full Xcode is not required for the AppKit command-line prototype. No signing credentials were inspected.

**FACT:** Homebrew PostgreSQL 14.17 is installed; independent EDB PostgreSQL 15.7 universal binaries exist at `/Library/PostgreSQL/15`. Experiments use the latter in a disposable Unix-socket-only cluster, never existing data/services. Selected installed directories: bin 29 MB, lib 119 MB, share 7.5 MB; this is not a minimal relocatable package size.

**FACT:** existing Ollama local API has `llama3.2:1b` Q8_0 (1.32 GB model file; digest baf6a787fdffd633537aa2eb51cfd54cb93ff08e28040095462bb63daf552878) and `qwen3-embedding:4b` Q4_K_M (2.50 GB). Only the 1B model was used. No models downloaded, no external database credentials needed.

**EXPERIMENTAL RESULT:** uv could not access its default cache and then panicked under sandbox even with a temporary cache. Python venv worked; package download and localhost/model/native GUI access required approved execution outside the sandbox. Dependencies are isolated in `.venv`: DuckDB 1.5.5 and SQLGlot 30.18.0. No global tooling configuration changed.

**OPEN QUESTION:** clean-machine install, offline packet-level audit, signed/notarized distribution, Intel hardware behavior, memory pressure on an 8 GB Mac, sustained thermal behavior. Measurements on this development machine do not establish those properties.
