#!/bin/bash
set -euo pipefail
QUELYT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUELYT_APP="${1:-$QUELYT_ROOT/.build/Quelyt.app}"
python3 - "$QUELYT_APP" <<'PY'
import pathlib, plistlib, subprocess, sys
app=pathlib.Path(sys.argv[1]); failures=[]
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
if info.get('QuelytWorkspace'): failures.append('Developer workspace path is embedded; runtime is not relocatable.')
if not (app/'Contents/Resources/runtime').exists(): failures.append('Bundled runtime is absent.')
if not (app/'Contents/Resources/THIRD_PARTY_NOTICES.md').exists(): failures.append('Bundled third-party notices are absent.')
signature=subprocess.run(['/usr/bin/codesign','-dv','--verbose=4',str(app)], capture_output=True, text=True)
if 'Authority=Developer ID Application:' not in signature.stderr: failures.append('Developer ID Application identity is absent.')
checks=[('Developer ID signature', ['/usr/bin/codesign','--verify','--deep','--strict',str(app)]),('Gatekeeper assessment', ['/usr/sbin/spctl','--assess','--type','execute',str(app)]),('Notarization ticket', ['/usr/bin/xcrun','stapler','validate',str(app)])]
for label, args in checks:
 result=subprocess.run(args, capture_output=True)
 if result.returncode: failures.append(label+' did not pass.')
print('\n'.join('BLOCKED: '+item for item in failures) if failures else 'Automated preflight passed; clean-machine offline and isolation acceptance still required.')
sys.exit(bool(failures))
PY
