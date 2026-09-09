# Discovery Sprint 0

2026-09-09 · **DECISION: NARROW and proceed to Milestone 1.**

Quelyt should first prove that a SQL-capable analyst can open an unfamiliar local CSV/Parquet dataset, check an answer and understand its evidence faster than with their current tool. The broader intelligence layer remains an **ASSUMPTION**, not a platform to build now.

## Product thesis and initial user

**ASSUMPTION:** the strongest initial user is a solo analyst or analytics engineer on macOS who repeatedly receives local extracts, knows enough SQL to inspect a result, and cannot casually upload source data. Choose this over a nontechnical general audience: schema/metric ambiguity and model errors currently require informed review. Choose file exploration over production DB administration: fewer credentials, permissions and connector edge cases.

Magic moment: open a file → see rows and schema → run a useful aggregate → inspect the SQL and exact numbers → eventually ask a question and see a validated chart. The under-one-minute answer target applies after setup on supported datasets; it is unproven for local model installation and arbitrary investigations.

**FACT:** [competitor research](../research/competitive-landscape.md) shows local AI, SQL generation and semantic context already exist. **ASSUMPTION:** a consistent offline workflow with visible evidence and less setup could win. No interviews or willingness-to-pay evidence were collected. Do not describe this as validated demand or a moat.

## Five riskiest assumptions

| Risk | Cheap falsification experiment | Result / next gate |
|---|---|---|
| People prefer this workflow enough to switch | Five observed sessions using participants' current tools and Quelyt; compare time and trust on equivalent tasks. No outreach without authorization. | OPEN QUESTION. Seek 3/5 independently returning within a week; do not use this convenience sample as market proof. |
| Practical local AI answers correctly on 16 GB | 20–50 executable questions, multiple data seeds, pinned local model; score output contracts and exact answers separately. | EXPERIMENTAL RESULT: installed 1B model 9/20 denotation matches; one match omits tie ordering. Fails readiness gate. Try stronger compatible model later, no automatic cloud fallback. |
| Read-mode SQL can be safely executed | Probe file/network reads, writes, extensions, multi-statements, expensive queries, cancellation. | EXPERIMENTAL RESULT: engine read-only alone permits external reads/writes. Layered policy required; current tests are not proof of OS isolation. |
| Local files can feel instant in a desktop app | Million-row format benchmark, bounded result transport, native table, cancellation and input stress. | EXPERIMENTAL RESULT: engine fast on simple warm-cache fixture. Native baseline compiles/launches. Full desktop performance not established. |
| Schema/context improves investigation enough to justify complexity | Full schema vs lexical/BM25/graph; scripted attribution vs aggregate; later embeddings and model ablation. | EXPERIMENTAL RESULT: simple retrieval misses synonyms; graph did not help. Scripted breakdown works but no agent superiority established. Defer context platform. |

See [raw experiment interpretation](../research/experiments.md) and [machine constraints](../research/environment.md).

## Architecture hypothesis and recommended stack

**DECISION for M1:** DuckDB 1.5.5 query engine; a small Python 3.12 worker with SQLGlot 30.18.0 lets us reuse measured APIs and safety tests. AppKit/Swift development shell provides real Mac file selection and virtualized results. Python is an internal bridge, not a promise of the release runtime. Do not make users install Python in the eventual product.

**ASSUMPTION for release:** Tauri 2/Rust with CodeMirror and a bounded virtualized web grid remains a strong alternative to Swift/AppKit with a native engine bridge. No permanent framework winner: the remaining comparison must test equivalent editor, data, cancellation and packaging behavior. An MVP implementation seam should prevent UI selection from dictating SQL policy.

SQLite is the metadata recommendation when durable history starts; native Keychain for future secrets; existing Ollama for local-model experiments; no embedded model, cloud provider, vector database or connector framework in M1. Basic table and native/chart-library bar/line visualizations should precede a general chart grammar.

## Local-only feasibility matrix

“Yes” means architecturally feasible; measured and unmeasured are distinguished.

| Capability | Fully local | Cloud optional | Cloud required | Evidence / constraint |
|---|---|---|---|---|
| DuckDB/files | Yes | No | No | Measured CSV/Parquet/JSON queries |
| SQLite metadata | Yes | No | No | Documented, not implemented in M1 |
| PostgreSQL | Yes | Remote connection later | No | Local lifecycle measured; redistribution unproven |
| SQL editor/grid | Yes | No | No | Native prototype built |
| Profiling/charts | Yes | No | No | Deterministic SQL; full UI chart workflow pending |
| Schema search | Yes | Optional remote embeddings later | No | Lexical/BM25 measured on synthetic schema |
| Embeddings | Yes | Yes | No | Local model installed, comparison not run |
| AI chat | Yes, with model | Yes, explicit opt-in | No | Local inference measured; quality failed |
| Agent investigation | Feasible | Yes | No | Scripted trace only; model planning unvalidated |
| Knowledge graph | Yes | No | No | SQLite representation hypothesis; unnecessary now |
| MCP | Yes | Remote clients later | No | Protocol integration deferred, not tested |

“Localhost” alone does not establish local inference. Ollama can route cloud models; require known local model residency and test outbound traffic before privacy claims. Setup/model downloads and signed distribution are separate from offline use.

## MVP priorities

- **P0:** open CSV/Parquet; schema and bounded preview; single read query; cancellation/deadline; errors; deterministic profile; inspectable SQL/result evidence; bar/line chart; opt-in local question workflow only after evaluation gate; no account or telemetry. AI-disabled use remains useful.
- **P1:** saved queries/history in SQLite, custom metric definitions, better SQL editing/completion, PostgreSQL connection using least-privilege credentials, vetted local model setup, multiple datasets and joins, explicit cloud request preview.
- **P2:** SQLite connector, schema hybrid retrieval if measured benefit, MCP with scoped permissions/audit, richer visualizations, context search and editable memory.
- **P3:** bundled PostgreSQL, scheduled agents, transformations, notebooks, Python tools, broad connectors, team features.

**Do not build yet:** account/backend/billing, sync, RBAC, graph database, vector service, plugin marketplace, arbitrary agent shell/Python, SQL write mode, bundled Postgres, dbt/Tableau replacement, automatic relationship learning, global memory, dozens of providers, Intel release before testing. Open-source/license and commercial model remain preference/business questions; no license grant is assumed.

## Milestone 1 — local file query foundation

**DECISION before scaffolding:** build a runnable developer Mac application that opens a selected CSV/Parquet, shows a schema/preview, runs a constrained SELECT against `dataset`, reports errors/timing/truncation, and cancels a worker. Supply a headless worker and integration tests. The source file must remain unchanged. Use only transient workspace copies; label that behavior.

Acceptance: CSV and Parquet fixture round-trips; query correctness; file/path quoting; write/external access rejection; timeout/cancellation; large-result truncation; malformed input; native open/query/error interaction visually inspected. Build from documented commands. No credential-dependent packaging acceptance in this developer milestone.

M1 is intentionally not the complete P0 or the AI north-star demo. Durable metadata, production sandboxing, model quality and distributable runtime remain gates. The framework ADR is provisional so this shell cannot accidentally become an irreversible architecture claim.

## Thirty-day plan and decision gates

| Days | Deliverable | Gate |
|---|---|---|
| 1–3 | Sprint 0 + M1 native file/query slice | Correct files, bounded operations, honest evidence |
| 4–7 | Compare realistic Tauri/Swift editor+grid; package engine worker; five user sessions if recruited | Select desktop framework; at least 3 participants complete useful query unaided |
| 8–12 | Local provider and >=50 held-out SQL/ambiguity/safety cases across data seeds | >=90% correct supported answers, no unsafe execution in suite; report uncertainty |
| 13–17 | Bounded 3–6 step investigation with trace, deterministic profile and bar/line charts | Attribution sums reconcile; no unsupported causal claim; multi-step beats one-shot on held-out cases |
| 18–22 | SQLite history, dataset reopening, resource limits, OS confinement, privacy audit | Restart/crash recovery, no unexpected network, edit/delete stored context |
| 23–26 | Signed/notarized Apple Silicon development-to-alpha packaging | Clean Mac Gatekeeper launch and offline use; Developer ID required |
| 27–30 | Private alpha sessions, fix highest-impact issues, evaluate repeat use | Proceed only if trusted answers and repeated use; otherwise narrow again |

This is a sequence with stop gates, not a promised release date. If local AI still fails, ship a useful SQL/file alpha and keep investigation experimental. If users show no switching value, revisit wedge before platform work.

## First ten implementation tasks

1. Define selected-file/query/result/error protocol with limits and no credentials.
2. Implement trusted CSV/Parquet snapshot import and schema preview.
3. Enforce one-query AST policy, table/function scope and locked engine settings.
4. Add bounded rows/cells/output, deadline, cancellation and process cleanup.
5. Build native file picker, SQL editor and virtualized result table.
6. Add fixture-based worker integration/security tests and native smoke verification.
7. Benchmark comparable native vs web editor/grid; resolve framework ADR.
8. Expand held-out AI cases with joins, ambiguity, injection and reordered data; evaluate stronger local model.
9. Add profile/chart and bounded provider/tool trace behind quality gate.
10. Add local history and signed clean-machine packaging path before private alpha.

Tasks 1–6 define M1; remaining tasks are subsequent work. See [architecture](../architecture/overview.md), [ADRs](../adr/README.md), and [AI evaluation strategy](../evals/strategy.md).
