# macOS query-worker isolation

Verified: 2026-09-09. Documentation review only; **no tested OS isolation is claimed**. FACT denotes documentation or code inspection, ASSUMPTION denotes a proposed design, and OPEN QUESTION requires an experiment. Archived Apple references below remain useful but require validation on supported macOS versions.

## Current boundary

**FACT — code inspection:** [Quelyt.swift](../../apps/macos/Quelyt.swift) launches the workspace `.venv/bin/python` through `Process`, sends a file path and SQL over a pipe, and selects a small environment. [worker.py](../../src/quelyt/worker.py) imports the chosen file before disabling DuckDB external access and applies SQL policy. Its own header correctly says this is an application policy boundary, not an OS sandbox. Removing environment variables and running a subprocess do not establish filesystem or network confinement.

## Supported production mechanisms

**FACT:** Apple's helper guide describes embedding and signing a command-line helper for a sandboxed app, including tools built outside Xcode. The same basic workflow applies to direct Developer ID distribution. An inheriting helper uses `com.apple.security.app-sandbox` and `com.apple.security.inherit`; the guide warns against additional helper entitlements and development `get-task-allow`. [Embedding a helper](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app).

**FACT:** inheritance grants the parent's static sandbox rights, not file grants acquired after launch. Apple says to pass data or a bookmark for those files. The main app must not use `inherit`. User-selected read-only access supports `NSOpenPanel`; drag interactions can also add access. Persistent reopening uses security-scoped bookmarks. Outgoing networking requires a client entitlement even for another server on the same machine; incoming networking has a separate server entitlement. [Entitlement reference, including inheritance, file access and networking](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html).

**ASSUMPTION:** the smallest production-shaped experiment is a signed, sandboxed file-only app with a bundled inheriting helper, neither carrying network access. This tests the present milestone with minimal IPC change. It limits the application relative to the user account; it does **not** give the worker fewer static privileges than the UI, nor guarantee that only one selected file is accessible.

**FACT:** Apple documents separate sandboxes for XPC services and recommends XPC for privilege separation. Service crashes and invalidated connections must be handled by the caller. [Creating XPC services](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html).

**ASSUMPTION:** once the UI/model broker gains network access, an inheriting query worker gains that same static capability. At that point use a separately sandboxed XPC query service without network entitlements; keep model networking in a different component. Do not add a client entitlement to the entire process tree merely to call loopback Ollama and continue claiming a network-denied query worker.

## File capability transfer

**ASSUMPTION:** for the first small-fixture experiment, pass selected file bytes through a bounded pipe and create the temporary snapshot inside the sandbox container. This avoids confusing an ordinary path string with a file grant. The existing import policy still checks type/size and disables further external reads before executing SQL.

**ASSUMPTION:** evaluate a bookmark-based transfer next to avoid unnecessary copying for large Parquet files. Resolve the grant in the receiving process, retain access only while needed and test read-only behavior. Persistent recent-file reopening also needs stale-bookmark handling, moved/deleted-file UX and deliberate grant removal. Do not automatically grant the containing directory. Container data remains accessible according to the process's sandbox, so isolate secrets and unrelated workspace history from the query service.

**OPEN QUESTION:** the minimum reliable bookmark/file-descriptor bridge from a Swift launcher to bundled Python; direct lazy file reads; symlinks and replacement between selection and use; and whether App Sandbox's baseline rights meet the intended threat model. A successful selected-file read alone proves none of these.

## Python packaging implications

**FACT:** Apple says to sign nested tools, libraries and frameworks, and to store Python scripts as resources. [Code signing tasks](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html).

**ASSUMPTION:** bundle a pinned Python runtime, DuckDB native extension, SQL parser and required libraries. Launch only the bundle-owned executable; remove reliance on the repository virtual environment, external interpreter paths and user site-packages. Audit dynamic-library paths, Python import paths, caches, bytecode writes, temporary directories and executable identity. A wrapper's entitlements alone do not prove the interpreter it starts receives the intended sandbox; inspect the executed chain and test denials.

**ASSUMPTION:** keep runtime contents immutable after signing and preserve library validation unless evidence identifies a specific requirement. Python packaging complexity may justify a small native DuckDB helper later, but this review does not establish that rewrite as necessary. No notarization or redistribution readiness follows from a working development virtual environment.

## sandbox-exec

**FACT — local Apple manual:** `/usr/share/man/man1/sandbox-exec.1`, inspected through `man sandbox-exec`, marks the command deprecated and directs app developers to App Sandbox. The same guidance is consistent with Apple's supported helper workflow above. [Installed manual](/usr/share/man/man1/sandbox-exec.1).

**ASSUMPTION — decision proposal:** a `sandbox-exec` profile may help investigate denial behavior in a disposable developer probe. Keep that experiment explicitly prototype-only; do not make it the production isolation architecture or treat undocumented profile syntax as a stable application API.

## Smallest next experiment

**ASSUMPTION — proposed test, not completed:** build an isolated sandboxed app/helper fixture first, then substitute the bundled Python worker without changing the probes.

1. Sign app and helper using the documented entitlements; inspect both signatures and the actual interpreter identity. Include neither network entitlement and no broad home-directory grant.
2. Open one synthetic CSV through `NSOpenPanel`, transfer bounded bytes, import/query it and verify expected rows. Confirm the source cannot be modified.
3. From the helper, attempt an ungranted sibling read, arbitrary user-file write, outbound loopback connection and a listening socket; require OS denials, not parser rejection. Use synthetic probe files rather than personal data. Record sandbox diagnostics.
4. Test cancellation, forced worker exit, repeated launch, malformed input and bounded stdout. Repeat after replacing the native probe with bundled Python/DuckDB.
5. Record OS version, signing identity class, complete entitlements, runtime versions and every allowed/denied operation. Defer security claims until these checks pass; notarized clean-machine distribution is a separate release gate.

**OPEN QUESTION:** newer enhanced security helper extensions may provide a stronger boundary on newer systems, but their OS floor and DuckDB/Python compatibility were not evaluated here. Apple's [current helper-extension documentation](https://developer.apple.com/documentation/xcode/creating-enhanced-security-helper-extensions) is a follow-up candidate, not a selected dependency.


## Subsequent disposable experiment

**EXPERIMENTAL RESULT:** after this source review, `experiments/isolation/run.py` successfully exercised Python and the actual DuckDB worker under a diagnostic sandbox-exec profile. Selected synthetic CSV read succeeded; unselected sibling read, writes and loopback connection were denied. [Experiment and startup diagnosis](../../experiments/isolation/README.md). This is limited evidence for a deprecated development mechanism, not validation of the supported App Sandbox design proposed above.
