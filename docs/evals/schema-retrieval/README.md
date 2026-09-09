# Schema retrieval baseline

Runnable script: `experiments/discovery/retrieval.py`; full cases/results: `retrieval-results.json` alongside it.

**EXPERIMENTAL RESULT:** lexical, BM25 and one-hop graph expansion each achieve 0.8 mean table recall across five questions at 10/100/1,000/5,000 synthetic tables. Whole-schema recall is 1.0 by construction. Context is measured in characters, not model tokens. Timings exclude index construction.

**OPEN QUESTION:** realistic distractors, column recall, synonym dictionaries, embeddings, foreign-key graph expansion, token cost and execution accuracy. Current distractors are repetitive; the suite cannot justify production retrieval quality. Add anonymized real schema shapes only with authorization. Keep a full-small-schema baseline, top-k recall and context-budget curves; compare schema-only embeddings with lexical/BM25 and explicit metric definitions before adding a vector dependency.
