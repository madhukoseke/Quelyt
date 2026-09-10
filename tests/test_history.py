import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'src'))
from quelyt import history


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = pathlib.Path(self.tmp.name) / 'history.sqlite'
        os.environ['QUELYT_HISTORY_PATH'] = str(self.path)

    def tearDown(self):
        os.environ.pop('QUELYT_HISTORY_PATH', None)
        self.tmp.cleanup()

    def test_record_list_delete_and_recent_sources(self):
        first = history.record({
            'path': str(pathlib.Path(self.tmp.name) / 'sales.csv'),
            'sql': 'SELECT * FROM dataset LIMIT 200',
            'action': 'query', 'ok': True, 'row_count': 3, 'dataset_rows': 3,
            'elapsed_ms': 12.5, 'chart_kind': 'none',
        })
        history.record({
            'path': str(pathlib.Path(self.tmp.name) / 'sales.csv'),
            'sql': 'DELETE FROM dataset',
            'action': 'query', 'ok': False, 'error': 'Read mode accepts exactly one SELECT query.',
            'kind': 'PolicyError',
        })
        listed = history.list_traces(limit=10)
        self.assertTrue(listed['ok'])
        self.assertEqual(len(listed['traces']), 2)
        self.assertEqual(listed['traces'][0]['sql'], 'DELETE FROM dataset')
        self.assertFalse(listed['traces'][0]['ok'])
        self.assertEqual(listed['sources'][0]['name'], 'sales.csv')
        history.delete_trace(listed['traces'][0]['id'])
        listed = history.list_traces()
        self.assertEqual(len(listed['traces']), 1)
        self.assertEqual(listed['traces'][0]['id'], first['id'])

    def test_clear_and_reject_empty_sql(self):
        history.record({'path': '/tmp/a.csv', 'sql': 'SELECT 1 FROM dataset', 'ok': True})
        self.assertEqual(len(history.list_traces()['traces']), 1)
        history.clear()
        self.assertEqual(history.list_traces()['traces'], [])
        self.assertEqual(history.list_traces()['sources'], [])
        with self.assertRaises(history.HistoryError):
            history.record({'path': '/tmp/a.csv', 'sql': '  ', 'ok': True})

    def test_prunes_oldest_traces(self):
        original = history.MAX_TRACES
        history.MAX_TRACES = 3
        try:
            for index in range(5):
                history.record({'path': '/tmp/a.csv', 'sql': f'SELECT {index} FROM dataset', 'ok': True})
            traces = history.list_traces()['traces']
            self.assertEqual(len(traces), 3)
            self.assertEqual(traces[0]['sql'], 'SELECT 4 FROM dataset')
            self.assertEqual(traces[-1]['sql'], 'SELECT 2 FROM dataset')
        finally:
            history.MAX_TRACES = original

    def test_process_protocol(self):
        payload = json.dumps({'path': '/tmp/a.csv', 'sql': 'SELECT * FROM dataset', 'ok': True})
        env = os.environ.copy()
        env['QUELYT_HISTORY_PATH'] = str(self.path)
        recorded = subprocess.run(
            [sys.executable, '-I', '-B', str(ROOT / 'src/quelyt/history.py'), 'record'],
            input=payload, text=True, capture_output=True, env=env, timeout=10,
        )
        self.assertEqual(recorded.returncode, 0)
        listed = subprocess.run(
            [sys.executable, '-I', '-B', str(ROOT / 'src/quelyt/history.py'), 'list'],
            text=True, capture_output=True, env=env, timeout=10,
        )
        body = json.loads(listed.stdout)
        self.assertTrue(body['ok'])
        self.assertEqual(len(body['traces']), 1)


if __name__ == '__main__':
    unittest.main()
