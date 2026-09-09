# Technology evidence for Sprint 0

Verified: 2026-09-09 against first-party documentation. This note supports provisional architecture decisions; it does not report local benchmark results. **FACT** = supported by linked documentation. **ASSUMPTION** = engineering inference. **OPEN QUESTION** = requires measurement or implementation verification.

## Desktop framework comparison

| Option | FACT | ASSUMPTION: fit and cost | Evidence needed before committing |
| --- | --- | --- | --- |
| Swift + SwiftUI/AppKit | `NSViewRepresentable` embeds AppKit views in SwiftUI and requires explicit coordination for state/delegate communication. [Apple API](https://developer.apple.com/documentation/SwiftUI/NSViewRepresentable?changes=la&language=objc). | Strong candidate for macOS integration. A serious SQL editor and large table may require AppKit or a web editor bridge; native UI does not automatically mean less implementation work. | Real editor completion, 100k-row virtualized result view, accessibility, selection/copy, background query cancellation and packaging. |
| Tauri 2 + Rust + web UI | Rust core orchestrates windows and IPC; macOS UI uses the OS WKWebView rather than bundling a browser engine. Secrets and sensitive logic belong in the core. [Process model](https://v2.tauri.app/concept/process-model/). | Attractive provisional balance for a web editor/grid with a narrow native command boundary. Smaller shell does not imply smaller total app once DuckDB/models are included. WebKit behavior and Rust integration add test work. | Identical workload to Swift/Electron, native menus/file drops, editor workers, streaming IPC, database cancellation, sidecar cleanup and release build size. |
| Electron + TypeScript | Node main process controls lifecycle; Chromium renderers are separate. Context isolation and a preload bridge mediate renderer access; utility processes can host intensive/crash-prone work. [Process model](https://www.electronjs.org/docs/latest/tutorial/process-model). | Strong fallback if editor/browser compatibility dominates velocity. Runtime overhead is a hypothesis to measure, not grounds for dismissal. | Measure the complete process tree, not just main-process RSS; verify native module packaging and isolated IPC. |

**ASSUMPTION — recommended experiment:** Tauri is the leading hypothesis, with Swift and Electron retained as realistic alternatives. Build one representative interaction per candidate and record cold start, total memory, query cancellation, scrolling, keyboard navigation and implementation time on the same Mac. A “Hello World” bundle-size comparison cannot settle the decision. Avoid a weighted score filled with guessed numbers.

## DuckDB and the trust boundary

**FACT:** DuckDB documents C, Rust and Node.js integrations and direct file workflows. Its concurrency model permits multiple writers within a single process and read-only access from multiple processes; unrestricted independent writers to the same native file are not the default model. [Client overview](https://duckdb.org/), [concurrency](https://duckdb.org/docs/current/connect/concurrency).

**ASSUMPTION:** use one owner for each writable workspace database. SQL execution belongs off the UI thread, and a restartable worker is worth testing for crash containment and hard cancellation. A worker process alone is not an OS sandbox.

**FACT:** current documentation also describes the Quack client-server protocol for multi-process native-format writes, marked beta from DuckDB 1.5.2. It does not invalidate the simpler in-process ownership choice for P0. [Concurrency](https://duckdb.org/docs/current/connect/concurrency).

**FACT:** DuckDB SQL can read filesystem content and load extensions. `enable_external_access=false` blocks external file operations, with explicit `allowed_paths`/`allowed_directories` exceptions. Configuration locking is available. The documentation explicitly treats these settings as defense in depth and recommends OS-level sandboxing for untrusted SQL. [Security overview](https://duckdb.org/docs/current/operations_manual/securing_duckdb/overview).

**FACT:** Extensions execute with the privileges of the DuckDB process. Signing/trust is part of the extension security model. [Extension security](https://duckdb.org/docs/current/operations_manual/securing_duckdb/securing_extensions).

**ASSUMPTION — required design:** a SELECT-only parser is insufficient. Use all of: dialect-aware parsing; one allowed statement; function/table scope checks; engine restrictions; no agent-controlled extension installation; no ambient secrets; resource budgets; deadline/cancellation; bounded output; and an independently constrained worker before claiming robust isolation. Treat schema names, cell strings and model tool arguments as untrusted input.

**ASSUMPTION — file opening:** trusted application code registers a user-selected file and returns a logical dataset handle. Agent SQL references the dataset, never an unrestricted path tool. Compare (a) exact path grants for lazy Parquet reads with (b) trusted import into a private workspace followed by external access disabled. Record the copy cost and path/symlink/replacement behavior. “Open” and “Import” must remain distinguishable.

**OPEN QUESTION:** test blocked filesystem functions, remote URLs, macros, extension loading, configuration changes, multiple statements, injected identifiers, enormous joins, timeout and cancellation against the exact bundled engine version. An SQL parser and passing happy-path queries do not establish a security boundary.

## Metadata and credentials

**FACT:** SQLite explicitly lists desktop application data storage and application file formats as suitable uses. [Appropriate uses](https://www.sqlite.org/whentouse.html).

**ASSUMPTION:** use SQLite for workspace metadata, history and inspectable semantic definitions. Keep analytical tables separate from application state. Add migrations and restore testing before release. A graph database and a vector service are unjustified until retrieval experiments beat simpler SQLite records/lexical retrieval.

**ASSUMPTION:** native Keychain references should be the only credential identifiers stored in metadata. Secrets must never pass into the renderer, model context, query history or default logs. Verify access/deletion/migration through the eventual signing identity; no credentials are needed for the file-only milestone.

## Local AI runtime

**FACT:** Ollama offers local execution and also cloud models. Its local-only switch is `OLLAMA_NO_CLOUD=1` or `disable_ollama_cloud` configuration; default binding is loopback port 11434. Model pulls and application updates can use the network. The FAQ distinguishes local prompts from prompts processed by cloud models. [Ollama FAQ](https://docs.ollama.com/faq).

**FACT:** Ollama documents tool calling, including multi-step agent loops; model compatibility matters. [Tool calling](https://docs.ollama.com/capabilities/tool-calling).

**ASSUMPTION:** use an existing local Ollama installation for the first model experiment, behind a minimal provider interface. Keep deterministic SQL/chart workflows useful without it. Label endpoint and model residency separately: a localhost URL is not proof that inference remains local. Do not silently configure the user's global runtime or silently fall back to cloud.

**OPEN QUESTION:** benchmark a pinned model digest, quantization, context size and hardware against held-out SQL, tool-call, ambiguity and investigation cases. Report failures and correct final answers separately from syntactically valid SQL. No RAM-tier recommendation, tokens/sec claim or sub-minute AI promise is established yet.

**ASSUMPTION:** llama.cpp/MLX may eventually remove external-runtime setup or improve packaging/performance, but they remain alternatives requiring their own integration, model-license and lifecycle experiments. Do not bundle several runtimes in P0.

## PostgreSQL feasibility and scope

**FACT:** `initdb` creates the cluster and must run as the server owner, not root. It exposes authentication options; the shipped configuration must be chosen deliberately. [PostgreSQL initdb](https://www.postgresql.org/docs/current/app-initdb.html).

**ASSUMPTION:** a local process prototype can establish initialization/start/stop feasibility without proving redistribution. Package architecture-specific binaries and dependencies only after inspecting dynamic library paths, licenses and signing behavior. Use a private data directory and constrained socket/listener; avoid ambient trust authentication or a broadly reachable listener.

**OPEN QUESTION:** binary provenance, clean-machine runtime dependencies, upgrades/backups, crash recovery, actual signed package size and user demand. Keep bundled PostgreSQL out of the file-investigation MVP until both lifecycle and need are demonstrated.

## macOS distribution

**FACT:** Apple distinguishes notarization from App Review. Its workflow uses Developer ID signing, hardened runtime, `notarytool` and ticket stapling; notarization checks malicious content and signing issues. Apple recommends testing launch behavior on a Mac not used for development. [Notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution?changes=_9), [clean-machine testing](https://help.apple.com/xcode/mac/current/en.lproj/dev1cc22a95c.html).

**FACT:** Tauri supports configuration of macOS signing identity and notarization. [Tauri signing](https://v2.tauri.app/distribute/sign/macos/).

**ASSUMPTION — initial distribution:** signed and notarized direct-download DMG, Apple Silicon first pending hardware evidence. Verify every nested executable/library, entitlements, quarantine launch, chosen file access, offline operation, uninstall behavior and update recovery. Hardened runtime, App Sandbox and app-level query policy are different controls; one does not prove another.

**OPEN QUESTION:** availability of a Developer ID identity and credentials; this note neither reads nor creates them. Local development builds do not prove Gatekeeper acceptance. Do not mark packaging complete until an actual signed artifact passes clean-machine verification.

## Decision gates

1. **ASSUMPTION:** validate local analytical correctness and cancellation before selecting a UI framework permanently.
2. **ASSUMPTION:** validate model correctness/offline behavior before promising autonomous investigations.
3. **ASSUMPTION:** validate file/network confinement before describing arbitrary generated SQL as safe.
4. **ASSUMPTION:** validate clean installation before claiming no-runtime-dependency onboarding.

No performance figures in this note are experiment results. Source paths using `current`/`latest` may change; record package versions alongside any implementation and rerun compatibility/security checks when upgrading.
