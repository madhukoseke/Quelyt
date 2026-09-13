import json
import pathlib
import sys
import unittest

from sqlglot.errors import ParseError

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'src'))
sys.path.insert(0, str(ROOT / 'experiments' / 'discovery'))

from quelyt.eval_score import classify_sql, parse_model_json, rows_equal, cell_equal
from quelyt.worker import PolicyError, validate_sql
import held_out


class EvalScoreTests(unittest.TestCase):
    def test_exact_numeric_and_multiset_regressions(self):
        self.assertFalse(cell_equal(9007199254740992, 9007199254740993))
        self.assertFalse(cell_equal('0.123456789012345678901', '0.123456789012345678902'))
        self.assertFalse(cell_equal(True, 1))
        self.assertTrue(rows_equal([['2'], ['10.00'], ['2.0']], [[2], [2], [10]]))
        self.assertFalse(rows_equal([[2], [2]], [[2], [3]]))
        self.assertFalse(rows_equal([[2], [10]], [[10], [2]], ordered=True))

    def test_suite_shape(self):
        families = {}
        worlds = set()
        for item in held_out.CASES:
            self.assertEqual(item['split'], 'held-out')
            families[item['family']] = families.get(item['family'], 0) + 1
            worlds.add(item['world'])
        self.assertEqual(families, {
            'aggregate': 10, 'join': 10, 'ambiguity': 10, 'attribution': 10, 'safety': 10,
        })
        self.assertGreaterEqual(len(worlds), 5)
        self.assertTrue({'1', '2', '3', 'empty', 'library'}.issubset(worlds))
        questions = [item['question'] for item in held_out.CASES]
        self.assertEqual(len(questions), len(set(questions)))

    def test_gold_sql_executes_and_empty_is_zero(self):
        for item in held_out.CASES:
            if item['expect']['kind'] != 'sql':
                continue
            con = held_out.connect_world(item['world'])
            rows = held_out.gold_rows(con, item['expect']['gold_sql'])
            self.assertIsInstance(rows, list)
            if item['id'] == 'H-A09':
                self.assertEqual(rows, [(0,)])
            if item['id'] == 'H-A07':
                self.assertEqual(rows, [(0,), (1,), (2,)])
            if item['id'] == 'H-T02':
                self.assertEqual(rows[0][0], -300)
            con.close()

    def test_shuffled_seed_does_not_match_id_order(self):
        con = held_out.connect_world('2')
        physical = [row[0] for row in con.execute('SELECT id FROM orders').fetchall()]
        self.assertNotEqual(physical, sorted(physical))
        con.close()

    def test_unicode_and_quoted_and_cell_injection_present(self):
        con = held_out.connect_world('1')
        tokyo = con.execute("SELECT count(*) FROM orders WHERE region = '東京'").fetchone()[0]
        self.assertGreater(tokyo, 0)
        quoted = con.execute('SELECT sum("gross amount") FROM orders').fetchone()[0]
        self.assertGreater(quoted, 0)
        note = con.execute('SELECT note FROM orders WHERE id = 7').fetchone()[0]
        self.assertIn('DROP TABLE', note)
        con.close()

    def test_denotation_numeric_and_order(self):
        self.assertTrue(cell_equal('1.50', 1.5))
        self.assertTrue(rows_equal([(2,), (1,)], [(1,), (2,)], ordered=False))
        self.assertFalse(rows_equal([(2,), (1,)], [(1,), (2,)], ordered=True))

    def test_parse_prefers_sql_over_refuse(self):
        parsed = parse_model_json(json.dumps({'sql': 'DELETE FROM orders', 'refuse': 'no'}))
        self.assertEqual(parsed['intent'], 'sql')
        parsed = parse_model_json(json.dumps({'clarify': 'Which metric?'}))
        self.assertEqual(parsed['intent'], 'clarify')

    def test_classify_and_worker_reject_attacks(self):
        for sql in held_out.ATTACK_SQL:
            with self.subTest(sql=sql):
                info = classify_sql(sql)
                self.assertTrue(info.get('unsafe'), info)
                with self.assertRaises((PolicyError, ParseError)):
                    validate_sql(sql)

    def test_score_clarify_and_refuse_without_executing_unsafe(self):
        con = held_out.connect_world('1')
        item = next(c for c in held_out.CASES if c['id'] == 'H-S01')
        scored = held_out.score_case(item, {'intent': 'refuse', 'message': 'no'}, con)
        self.assertTrue(scored['correct'])
        self.assertFalse(scored['executed'])
        scored = held_out.score_case(item, {'intent': 'sql', 'sql': 'DELETE FROM orders'}, con)
        self.assertFalse(scored['correct'])
        self.assertTrue(scored['unsafe_attempt'])
        self.assertFalse(scored['executed'])
        remaining = con.execute('SELECT count(*) FROM orders').fetchone()[0]
        self.assertEqual(remaining, 80)
        con.close()

    def test_score_sql_denotation(self):
        con = held_out.connect_world('1')
        item = next(c for c in held_out.CASES if c['id'] == 'H-A01')
        scored = held_out.score_case(item, {'intent': 'sql', 'sql': 'SELECT count(*) FROM orders'}, con)
        self.assertTrue(scored['correct'])
        scored = held_out.score_case(item, {'intent': 'sql', 'sql': 'SELECT count(*) FROM orders WHERE status = \'completed\''}, con)
        self.assertFalse(scored['correct'])
        con.close()


if __name__ == '__main__':
    unittest.main()
