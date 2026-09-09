# Disposable macOS isolation experiment

This is an experiment with **deprecated `sandbox-exec`**, not a production policy or a supported application distribution mechanism. Run on macOS with the development virtual environment:

```sh
.venv/bin/python experiments/isolation/run.py
```

Only synthetic temporary files are involved. The probe permits the selected file, Python runtime, experiment/worker code and system libraries; denies other content by default; allows metadata reads and exact root-directory enumeration; denies file writes and network. The policy also has broad process and Mach lookup permissions and has **not** been audited as a complete security boundary. The checked-in profile substitutes a placeholder for its temporary directory.

**EXPERIMENTAL RESULT (macOS 15.5):** selected file read succeeds; unselected sibling read, write and localhost connection receive PermissionError. The actual DuckDB worker under the same policy returns SUM(amount)=30. Raw results: `results.json`.

**Failure investigated:** initial strict profile aborted Python with exit -6 before output. A network-only diagnostic policy started normally. Adding metadata reads did not resolve it. A targeted system log reported `deny file-read-data /`; allowing exactly `/` (not a recursive subpath) resolved startup. No broad user-directory read grant was added. This demonstrates why realistic runtime probes are necessary.

**Decision:** do not integrate this deprecated mechanism into the app. The production-shaped next experiment is a signed App Sandbox helper with explicit selected-file capability transfer. Future model networking must not accidentally grant query workers network privileges. See `docs/research/macos-isolation.md`.
