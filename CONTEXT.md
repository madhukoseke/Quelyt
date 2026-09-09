# Quelyt

A local workspace for understanding datasets through queries and inspectable evidence.

## Language

**Dataset**: The data selected for an exploration, with columns and rows. A source file and a dataset are distinct: multiple explorations may use the same source.

**Open**: Make a selected source available to explore without changing the original. Opening does not promise a durable copy.

**Import**: Create a workspace-owned copy of source data. Changes to the source do not change that copy.

**Investigation**: A bounded sequence of data questions and queries that produces an evidence-backed answer. A contribution breakdown is not proof of causality.

**Action trace**: The inspectable record of selected context, executed SQL, results, timing and errors. It does not contain private model chain-of-thought.

**Read mode**: A mode that permits approved data-reading operations only. It does not authorize access to arbitrary files or remote services.
