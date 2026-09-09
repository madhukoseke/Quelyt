#!/bin/bash
set -euo pipefail
QUELYT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUELYT_APP="$QUELYT_ROOT/.build/Quelyt.app"
mkdir -p "$QUELYT_APP/Contents/MacOS"
swiftc -O -module-cache-path /tmp/quelyt-swift-cache "$QUELYT_ROOT/apps/macos/Quelyt.swift" -o "$QUELYT_APP/Contents/MacOS/Quelyt"
python3 - "$QUELYT_APP" "$QUELYT_ROOT" <<'PY'
import pathlib,plistlib,sys
p=pathlib.Path(sys.argv[1])/'Contents/Info.plist'
p.write_bytes(plistlib.dumps({'CFBundleExecutable':'Quelyt','CFBundleIdentifier':'dev.quelyt.desktop','CFBundleName':'Quelyt','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.0','CFBundleVersion':'1','LSMinimumSystemVersion':'13.0','NSHighResolutionCapable':True,'QuelytWorkspace':sys.argv[2]}))
PY
printf 'Developer build: %s\n' "$QUELYT_APP"
