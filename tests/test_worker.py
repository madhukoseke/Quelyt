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
from quelyt.worker import query, validate_sql, PolicyError


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.csv = self.root / "sales ' quoted.csv"
        self.csv.write_text('region,amount\nWest,10\nEast,20\nWest,5\n')

    def tearDown(self):
        self.tmp.cleanup()

    def test_csv_aggregate_and_source_unchanged(self):
        before = self.csv.read_bytes()
        r = query({'path': str(self.csv), 'sql': 'SELECT region, sum(amount) revenue FROM dataset GROUP BY region ORDER BY region'})
        self.assertEqual(r['rows'], [['East', '20'], ['West', '15']])
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


if __name__ == '__main__': unittest.main()
