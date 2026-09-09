# AI evaluation strategy

**DECISION:** no autonomous AI release based on demos. Store and version question, schema, seeded data, expected result or permitted clarification, model digest, prompt, settings, selected context, proposed/executed SQL, rows, timings, tool counts and errors.

The initial 20 questions and responses are in `experiments/discovery/ai-cases.json` and `ai-results.json`. This is a smoke set with one table and one data seed, not a benchmark adequate for release. 9/20 matched; the tie-order case demonstrates accidental agreement. Evaluate ordered outputs in order and on shuffled insertion order; compare numeric values with documented decimal/tolerance policy. Never score only SQL string equality or successful execution.

## Next held-out set (minimum 50)

10 aggregations and null/date boundaries; 10 joins including fanout and missing keys; 10 metric/semantic ambiguities requiring clarification; 10 multi-step attribution tasks including offsetting segments; 10 safety/adversarial cases including instructions in cell data, schema comments, multi-statements, filesystem/network functions and secret requests. Maintain development and held-out splits; use at least three data seeds and a deliberately out-of-domain schema. Include empty datasets, quoted identifiers and Unicode.

Measure table/column recall, join correctness, parser/JSON validity, result correctness, final-answer correctness, evidence linkage, honest uncertainty, refusal/clarification quality, unsafe attempts versus actual executions, tool budget, total and first-token latency, runtime memory and throughput. Store failures, not just aggregate accuracy. Release thresholds are proposed product gates: >=90% correct supported answers, >=95% expected clarification/refusal, zero observed unsafe executions, all numerical claims trace to results. Passing a finite safety suite does not prove safety.

Compare one-shot and bounded multi-step on the same model/context/data, with equal overall token/time budgets. Score correct reconciled attribution, not persuasive prose. Report descriptive changes separately from causal claims. The scripted E05 result is an oracle/data fixture, not evidence an LLM can investigate.

Local-only verification must confirm model residency and audit outbound requests with external network unavailable, after setup. Do not alter the user's Wi-Fi/global runtime automatically. Measure minimum hardware tiers rather than inventing them from parameter count.
