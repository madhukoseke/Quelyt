import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

import duckdb
from sqlglot.errors import ParseError

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'src'))
from quelyt.worker import query, validate_sql, PolicyError, suggest_chart


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.csv = self.root / "sales ' quoted.csv"
        self.csv.write_text('region,amount\nWest,10\nEast,20\nWest,5\n')

    def tearDown(self):
        self.tmp.cleanup()

    def test_export_types_preserve_decimal_boolean_and_large_integer(self):
        response = query({'path': str(self.csv), 'sql': "SELECT CAST('123456789012345678.123456789' AS DECIMAL(30,9)) AS precise, TRUE AS flag, CAST('170141183460469231731687303715884105727' AS HUGEINT) AS huge FROM dataset LIMIT 1"})
        self.assertEqual(response['values'][0], ['123456789012345678.123456789', True, 170141183460469231731687303715884105727])
        self.assertEqual(json.loads(json.dumps(response))['values'], response['values'])

    def test_process_parse_error_location(self):
        result = subprocess.run([sys.executable, str(ROOT / 'src/quelyt/worker.py')],
            input=json.dumps({'path': str(self.csv), 'sql': 'SELECT *\nFROM dataset WHERE ('}), text=True, capture_output=True)
        response = json.loads(result.stdout)
        self.assertFalse(response['ok'])
        self.assertEqual(response['kind'], 'ParseError')
        self.assertEqual(response['location']['line'], 2)
        self.assertGreater(response['location']['column'], 0)

    def test_csv_aggregate_and_source_unchanged(self):
        before = self.csv.read_bytes()
        r = query({'path': str(self.csv), 'sql': 'SELECT region, sum(amount) revenue FROM dataset GROUP BY region ORDER BY region'})
        self.assertEqual(r['rows'], [['East', '20'], ['West', '15']])
        self.assertEqual(r['values'], [['East', 20], ['West', 15]])
        self.assertEqual(r['column_kinds'], ['text', 'number'])
        self.assertEqual(r['chart']['kind'], 'bar')
        self.assertEqual(r['dataset_rows'], 3)
        self.assertEqual(self.csv.read_bytes(), before)

    def test_parquet(self):
        p = self.root / 'data.parquet'
        c = duckdb.connect()
        c.execute('COPY (SELECT 42 answer) TO ? (FORMAT PARQUET)', [str(p)])
        c.close()
        self.assertEqual(query({'path': str(p)})['rows'], [['42']])

    def test_denied_queries(self):
        for sql in ["DELETE FROM dataset", "SELECT 1; SELECT 2", "COPY dataset TO '/tmp/leak'", "SELECT * FROM read_csv('/etc/passwd')", "SELECT * FROM 'secret.csv'", "SELECT getenv('HOME')", 'INSTALL httpfs', 'LOAD httpfs', 'SET enable_external_access=true', 'SELECT * FROM information_schema.tables', 'SELECT * FROM other', 'SELECT * INTO stolen FROM dataset', 'WITH a AS (SELECT * FROM dataset) SELECT * FROM a', 'SELECT * FROM dataset UNION SELECT 1,2', 'SELECT * FROM query(\'DELETE FROM dataset\')']:
            with self.subTest(sql=sql):
                with self.assertRaises((PolicyError, ParseError)):
                    validate_sql(sql)

    def test_null_and_quoted_identifiers(self):
        self.csv.write_text('odd column,amount\nhello,\nworld,2\n')
        r = query({'path': str(self.csv), 'sql': 'SELECT "odd column", amount FROM dataset ORDER BY "odd column"'})
        self.assertEqual(r['rows'][0], ['hello', None])
        self.assertEqual(r['values'][0], ['hello', None])
        self.assertEqual(r['column_kinds'], ['text', 'number'])

    def test_result_limit(self):
        self.csv.write_text('id\n' + '\n'.join(str(i) for i in range(3000)))
        r = query({'path': str(self.csv), 'sql': 'SELECT * FROM dataset'})
        self.assertEqual(len(r['rows']), 2000)
        self.assertTrue(r['truncated'])

    def test_cell_limit(self):
        self.csv.write_text('text\n' + 'x' * 5000)
        r = query({'path': str(self.csv)})
        self.assertTrue(r['cells_truncated'])
        self.assertEqual(len(r['rows'][0][0]), 4097)

    def test_timeout(self):
        self.csv.write_text('id\n' + '\n'.join(str(i) for i in range(2000)))
        with self.assertRaises(duckdb.InterruptException):
            query({'path': str(self.csv), 'sql': 'SELECT sum(a.id*b.id*c.id) FROM dataset a CROSS JOIN dataset b CROSS JOIN dataset c', 'timeout_seconds': .05})

    def test_missing_and_invalid_file(self):
        with self.assertRaises(FileNotFoundError): query({'path': str(self.root/'missing.csv')})
        p=self.root/'bad.parquet';p.write_text('not parquet')
        with self.assertRaises(duckdb.InvalidInputException): query({'path':str(p)})

    def test_output_byte_limit(self):
        self.csv.write_text('text\n' + '\n'.join('x' * 4000 for _ in range(1000)))
        r = query({'path': str(self.csv), 'sql': 'SELECT * FROM dataset'})
        self.assertTrue(r['truncated'])
        self.assertLess(len(json.dumps(r).encode()), 2200000)

    def test_exact_wire_budget_with_unicode_and_metadata(self):
        self.csv.write_text('text\n' + '\n'.join('😀' * 4000 for _ in range(200)))
        r = query({'path': str(self.csv), 'sql': 'SELECT text AS "Unicode result" FROM dataset'})
        self.assertTrue(r['truncated'])
        self.assertLessEqual(len(json.dumps(r, ensure_ascii=True).encode()), 2 * 1024 * 1024)
        self.assertEqual(r['rows'][0][0], '😀' * 4000)

    def test_column_limits(self):
        self.csv.write_text(','.join('c' + str(i) for i in range(101)) + '\n' + ','.join('1' for _ in range(101)))
        with self.assertRaises(PolicyError): query({'path': str(self.csv)})
        self.csv.write_text('x' * 513 + '\n1')
        with self.assertRaises(PolicyError): query({'path': str(self.csv)})

    def test_external_access_is_blocked_by_engine(self):
        # Independently test engine defense, even if an AST policy check were bypassed.
        c = duckdb.connect(config={'enable_external_access': False})
        c.execute('SET lock_configuration=true')
        try:
            with self.assertRaises(duckdb.PermissionException):
                c.execute('SELECT * FROM read_csv(?)', [str(self.csv)])
            with self.assertRaises(duckdb.InvalidInputException):
                c.execute('SET enable_external_access=true')
        finally: c.close()

    def test_process_protocol_errors_and_success(self):
        for payload,expected in [(json.dumps({'path':str(self.csv)}),True), ('{',False), ('[]',False), ('x'*70000,False)]:
            p=subprocess.run([sys.executable,str(ROOT/'src/quelyt/worker.py')],input=payload,text=True,capture_output=True,timeout=10)
            result=json.loads(p.stdout)
            self.assertEqual(result['ok'],expected)
            self.assertEqual(p.returncode,0 if expected else 1)

    def test_profile_stats_and_source_unchanged(self):
        self.csv.write_text('region,amount\nWest,10\nEast,\nWest,5\n')
        before = self.csv.read_bytes()
        r = query({'path': str(self.csv), 'action': 'profile'})
        self.assertEqual(self.csv.read_bytes(), before)
        self.assertEqual(r['action'], 'profile')
        self.assertEqual(r['dataset_rows'], 3)
        self.assertIn('FROM dataset', r['sql'])
        by_name = {column['name']: column for column in r['profile']}
        self.assertEqual(by_name['amount']['null_count'], 1)
        self.assertEqual(by_name['amount']['null_pct'], 33.33)
        self.assertEqual(by_name['amount']['distinct_count'], 2)
        self.assertEqual(by_name['amount']['min'], 5)
        self.assertEqual(by_name['amount']['max'], 10)
        self.assertEqual(by_name['region']['null_count'], 0)
        self.assertEqual(by_name['region']['distinct_count'], 2)
        self.assertEqual(by_name['region']['min'], 'East')
        self.assertEqual(by_name['region']['max'], 'West')
        self.assertEqual(r['chart']['kind'], 'none')
        self.assertEqual(len(r['rows']), 2)

    def test_profile_unknown_action_and_deadline(self):
        with self.assertRaises(PolicyError):
            query({'path': str(self.csv), 'action': 'write'})
        with self.assertRaises(PolicyError):
            query({'path': str(self.csv), 'action': 'profile', 'timeout_seconds': 0})

    def test_chart_heuristic_bar_line_none(self):
        bar = suggest_chart('SELECT region, revenue FROM dataset', [{'name': 'region', 'type': 'VARCHAR'}, {'name': 'revenue', 'type': 'BIGINT'}],
                            [['East', 20], ['West', 15]], ['text', 'number'], False)
        self.assertEqual(bar['kind'], 'bar')
        line = suggest_chart('SELECT day, revenue FROM dataset', [{'name': 'day', 'type': 'DATE'}, {'name': 'revenue', 'type': 'DOUBLE'}],
                             [['2024-01-01', 10], ['2024-01-02', 20]], ['text', 'number'], False)
        self.assertEqual(line['kind'], 'line')
        numeric = suggest_chart('SELECT id, amount FROM dataset', [{'name': 'id', 'type': 'INTEGER'}, {'name': 'amount', 'type': 'INTEGER'}],
                                [[1, 10], [2, 20]], ['number', 'number'], False)
        self.assertEqual(numeric['kind'], 'line')
        none = suggest_chart('SELECT * FROM dataset', [{'name': 'region', 'type': 'VARCHAR'}, {'name': 'amount', 'type': 'INTEGER'}],
                             [['West', 10]], ['text', 'number'], False)
        self.assertEqual(none['kind'], 'none')
        self.csv.write_text('day,amount\n2024-01-01,10\n2024-01-02,20\n')
        r = query({'path': str(self.csv), 'sql': 'SELECT day, SUM(amount) AS revenue FROM dataset GROUP BY day ORDER BY day'})
        self.assertEqual(r['chart']['kind'], 'line')
        self.assertEqual(r['chart']['sql'], 'SELECT day, SUM(amount) AS revenue FROM dataset GROUP BY day ORDER BY day')


if __name__ == '__main__': unittest.main()
