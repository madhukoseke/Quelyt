# Native interaction QA — 2026-09-09

**EXPERIMENTAL RESULT:** Computer Use access became available in the continuation after initially being blocked by macOS permissions.

Observed through actual macOS Accessibility state and input:

- Clicked SQL editor, selected/replaced text, executed aggregate with ⌘ Return. Correct East=32,999,967 and West=16,500,033 for the million-row synthetic fixture.
- Entered DELETE and clicked Run. Visible read-mode rejection; no execution.
- Started a large cross join; clicked Cancel. Visible cancellation and enabled editor/run controls.
- Used ⌘O, native Open panel, Go to Folder and selected synthetic sales.csv. Dataset schema and 200-row preview appeared, one million total rows.

**Issue found:** NSNumber interpolation displayed 72.31999999999999 ms. Fixed by explicit one-decimal formatting.

**Continuation improvements:** streamed Python result fetching replaces fetchmany(2001); full serialized response (including SQL/schema/JSON escaping) is capped at 2 MiB. Added Python isolated mode (-I) to native worker launch and selected-row TSV copying with headers.

**EXPERIMENTAL RESULT after rebuild:** copied a selected grid row with ⌘C and pasted into the editor; observed exact header and values. Count action subsequently returned 1,000,000. Scrolled three pages and observed rows 39–53. Formatted timing displayed 53.4 ms without binary floating-point noise.

This record is not a blanket accessibility claim. Drag/drop, VoiceOver, keyboard-only result navigation and all supported window sizes still require coverage. Earlier M1 notes accurately describe the original permission blocker; this continuation supersedes that blocker for the tested interactions.
