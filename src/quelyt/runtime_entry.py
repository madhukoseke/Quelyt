"""Frozen helper dispatcher. No arbitrary scripts or interpreter arguments."""
import sys
from quelyt import worker, history

if __name__ == '__main__':
    mode = sys.argv.pop(1) if len(sys.argv) > 1 else ''
    if mode == 'worker':
        raise SystemExit(worker.main())
    if mode == 'history':
        raise SystemExit(history.main())
    raise SystemExit('Expected worker or history')
