"""Synthetic OS sandbox probe. Never inspects actual private files."""
import json, pathlib, socket, sys
allowed, denied, output = map(pathlib.Path, sys.argv[1:])
results = {}
for name, action in [
    ('selected_read', lambda: allowed.read_text()),
    ('unselected_read', lambda: denied.read_text()),
    ('file_write', lambda: output.write_text('probe')),
]:
    try:
        action(); results[name] = 'allowed'
    except PermissionError: results[name] = 'blocked'
    except Exception as exc: results[name] = type(exc).__name__
try:
    with socket.create_connection(('127.0.0.1', 11434), timeout=1): pass
    results['network'] = 'allowed'
except PermissionError: results['network'] = 'blocked'
except Exception as exc: results['network'] = type(exc).__name__
print(json.dumps(results))
