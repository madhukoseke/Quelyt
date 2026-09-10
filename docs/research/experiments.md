# Discovery experiments — 2026-09-09

All results use synthetic data on the [recorded machine](environment.md). Raw JSON and runnable scripts are in `experiments/`. Benchmarks are small feasibility checks, not production guarantees.

| Experiment | EXPERIMENTAL RESULT | Consequence / limitation |
|---|---|---|
| E01 DuckDB formats | 1M rows: Parquet 4.12 MB, CSV 25.79 MB, JSON 66.79 MB. Five-run aggregate median: 1.25 / 52.86 / 63.95 ms respectively. Preview medians: 1.17 / 24.72 / 22.05 ms. Process peak RSS 348 MB including fixture generation. | Strong fit for local analytics. Files were just generated and OS cache is warm; first measured run is not a cold-disk result. One simple four-column fixture, not a broad workload. |
| E02 PostgreSQL lifecycle | init 1.157 s; three start cycles 222/131/135 ms; stops 110–113 ms; SELECT 42 succeeds each cycle. | Feasible here without Docker or invoking Homebrew. Existing installation still required. Relocation, crash recovery, upgrade and signed redistribution unproven; defer MVP feature. |
| E03/E06 local SQL | Existing llama3.2:1b Q8_0: 9/20 denotation matches on a single-table task set. Median request latency 524 ms; median decode throughput ~48.5 tokens/s among responses with recorded decode metrics; first load ~1.87 s. Errors include invented filters, missing JSON key, wrong aggregate and date boundary. | Reject as default autonomous analyst. This is one model/prompt/config, not evidence against all local AI. |
| E04 retrieval | 10/100/1k/5k synthetic tables: lexical and BM25 mean table recall 0.8, full schema 1.0. At 5k tables lexical five-question scan ~13 ms; selected context ~54 chars vs 229k full. Graph expansion did not fix synonym misses. | Avoid vector/graph infrastructure now. Toy names and distractors make this optimistic. No tokenizer, column recall or downstream SQL accuracy measured. Embeddings remain an unrun comparison. |
| E05 investigation | Scripted three-query breakdown explains net -300 (-10%): West Enterprise -400, East Enterprise +100. | Action trace adds descriptive evidence beyond total comparison. NOT an LLM agent-vs-one-shot benchmark; causal explanation and model planning unvalidated. |
| SQL safety | DuckDB read-only connection blocks DELETE but permits external CSV reads, COPY file writes and configuration mutation. External-access disable + configuration lock block tested external operations. Interrupt stopped huge cross join in 108 ms. | Read-only is insufficient. Restrict statement/function scope and engine access; bound execution and result size. OS confinement still required before untrusted agent release. |
| E07 desktop | AppKit, Tauri and Electron probes ran the same worker: preview, aggregate, write reject, cancel. Native median dataset-ready 369 ms / ~82 MiB RSS; Tauri 506 ms / ~189 MiB including WebKit helpers; Electron 487 ms / ~368 MiB. | Keep Swift development shell. Not a packaging or 60fps winner. CodeMirror exists only in web probes. See [framework comparison](framework-comparison.md). |
| E08 held-out AI | Same installed llama3.2:1b, one-shot, 50 held-out cases: 7/30 supported denotations, 6/20 expected clarify/refuse, 2 unsafe attempts, 0 unsafe executions. Family scores 2/10 aggregate, 5/10 join, 6/10 ambiguity, 0/10 attribution, 0/10 safety. Median 2002 ms. | Product gates fail. Do not ship Talk to Data. Zero executions is harness policy, not a sandbox. Multi-step/tool-loop comparison unrun. See [held-out eval](../evals/held-out/README.md). |

## Reproduce

```
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python experiments/discovery/engine.py
.venv/bin/python experiments/discovery/retrieval.py
.venv/bin/python experiments/discovery/investigation.py
.venv/bin/python experiments/discovery/local_ai.py
.venv/bin/python experiments/discovery/held_out.py
.venv/bin/python experiments/local-postgres/run.py
.venv/bin/python experiments/frameworks/measure_launch.py
```

Local AI requires the existing local Ollama model. PostgreSQL script explicitly uses the installed EDB path and a temporary cluster; adapt the path on other machines. GUI build instructions are in the root README. Generated large fixtures are ignored.

## Evaluation caveat discovered during review

The top-three AI case matched this fixture despite omitting the requested ID tie-breaker. Denotation on one fixture can produce false confidence. Treat 9/20 as observed matches, not proven semantic correctness (at most 8/20 fully compliant queries after manual inspection of that case). The held-out suite now exists and the same 1B model failed its gates; do not select a stronger model merely from a demo — rerun `experiments/discovery/held_out.py`.
