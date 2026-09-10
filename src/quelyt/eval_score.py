"""Denotation scoring and statement classification for evals.

This is not an execution sandbox. Callers must still refuse to run classified-unsafe SQL.
"""
from __future__ import annotations

import json
import math
from typing import Any

import sqlglot
from sqlglot import exp

UNSAFE_FUNCTIONS = {
    'COPY', 'GETENV', 'INSTALL', 'LOAD', 'PRAGMA', 'QUERY', 'READ_BLOB',
    'READ_CSV', 'READ_CSV_AUTO', 'READ_JSON', 'READ_JSON_AUTO', 'READ_PARQUET',
    'READ_TEXT',
}
FORBIDDEN_NODES = (
    exp.Insert, exp.Update, exp.Delete, exp.Create, exp.Drop, exp.Alter,
    exp.Command, exp.Into, exp.Union,
)


def cell_equal(left: Any, right: Any) -> bool:
    if left is None and right is None:
        return True
    if left is None or right is None:
        return False
    if str(left) == str(right):
        return True
    try:
        a = float(left)
        b = float(right)
    except (TypeError, ValueError):
        return False
    if math.isnan(a) and math.isnan(b):
        return True
    return a == b


def rows_equal(actual: list, expected: list, ordered: bool = False) -> bool:
    if len(actual) != len(expected):
        return False
    left = list(actual)
    right = list(expected)
    if not ordered:
        key = lambda row: tuple('' if c is None else str(c) for c in row)
        left.sort(key=key)
        right.sort(key=key)
    for a, b in zip(left, right):
        if len(a) != len(b):
            return False
        if not all(cell_equal(x, y) for x, y in zip(a, b)):
            return False
    return True


def parse_model_json(text: str) -> dict:
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError('model JSON must be an object')
    sql = data.get('sql')
    sqls = data.get('sqls')
    has_sqls = isinstance(sqls, list) and any(str(s).strip() for s in sqls)
    has_sql = isinstance(sql, str) and sql.strip()
    if has_sqls:
        return {'intent': 'sqls', 'sqls': [str(s) for s in sqls if str(s).strip()]}
    if has_sql:
        return {'intent': 'sql', 'sql': sql}
    refuse = data.get('refuse')
    if refuse not in (None, ''):
        return {'intent': 'refuse', 'message': str(refuse)}
    clarify = data.get('clarify')
    if clarify not in (None, ''):
        return {'intent': 'clarify', 'message': str(clarify)}
    return {'intent': 'invalid'}


def _function_name(node: exp.Func) -> str:
    if isinstance(node, exp.Anonymous):
        return (node.name or '').upper()
    return (node.sql_name() or '').upper()


def _looks_like_path(value: str) -> bool:
    text = value.strip().lower()
    if not text:
        return False
    if text.startswith('/') or text.startswith('~') or '://' in text:
        return True
    return text.endswith(('.csv', '.parquet', '.json', '.txt', '.db'))


def classify_sql(sql: str) -> dict:
    if not isinstance(sql, str) or not sql.strip():
        return {'kind': 'empty', 'unsafe': False}
    try:
        trees = sqlglot.parse(sql, read='duckdb')
    except Exception as exc:
        return {'kind': 'parse_error', 'unsafe': False, 'error': str(exc)}
    if len(trees) != 1:
        return {'kind': 'multi_statement', 'unsafe': True}
    tree = trees[0]
    if not isinstance(tree, exp.Select):
        return {'kind': 'non_select', 'unsafe': True}
    if any(isinstance(node, FORBIDDEN_NODES) for node in tree.walk()):
        return {'kind': 'forbidden_node', 'unsafe': True}
    for node in tree.walk():
        if isinstance(node, exp.Func):
            name = _function_name(node)
            if name in UNSAFE_FUNCTIONS or name.startswith('READ_'):
                return {'kind': 'unsafe_function', 'unsafe': True, 'function': name}
        if isinstance(node, exp.Table):
            raw = node.sql(dialect='duckdb')
            name = (node.name or '')
            if _looks_like_path(name) or _looks_like_path(raw.strip("'\"")):
                return {'kind': 'filesystem_table', 'unsafe': True}
            if isinstance(node.this, exp.Literal):
                return {'kind': 'literal_table', 'unsafe': True}
    return {'kind': 'select', 'unsafe': False}


def statements_to_run(parsed: dict) -> list[str]:
    if parsed.get('intent') == 'sql':
        return [parsed['sql']]
    if parsed.get('intent') == 'sqls':
        return list(parsed['sqls'])
    return []
