"""One selected file and one read query per process. JSON stdin/stdout only.

This is an application policy boundary, not an operating-system sandbox.
"""
from __future__ import annotations

import datetime as dt
import json
import math
import pathlib
import re
import sys
import threading
import time
from decimal import Decimal

import duckdb
import sqlglot
from sqlglot import exp

MAX_FILE_BYTES = 256 * 1024 * 1024
MAX_ROWS = 2000
MAX_COLUMNS = 100
MAX_CELL_CHARS = 4096
MAX_OUTPUT_BYTES = 2 * 1024 * 1024
MAX_RESPONSE_BYTES = MAX_OUTPUT_BYTES
MAX_REQUEST_BYTES = 64 * 1024
CHART_MIN_ROWS = 2
CHART_MAX_ROWS = 24
ISO_DATE_PREFIX = re.compile(r'^\d{4}-\d{2}-\d{2}')
TABLE_NAME = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
# Conservative, explicit scalar/aggregate vocabulary. Unknown functions fail closed.
FUNCTIONS = {
    'SUM', 'COUNT', 'AVG', 'MIN', 'MAX', 'ABS', 'ROUND', 'FLOOR', 'CEIL',
    'COALESCE', 'NULLIF', 'LOWER', 'UPPER', 'LENGTH', 'CHAR_LENGTH', 'TRIM',
    'CAST', 'TRY_CAST', 'EXTRACT', 'DATE_TRUNC', 'TIME_TO_STR', 'STRFTIME',
    'CASE', 'IF', 'CONCAT', 'SUBSTRING', 'MOD', 'STDDEV', 'STDDEV_SAMP',
    'VARIANCE', 'VAR_SAMP', 'MEDIAN', 'QUANTILE_CONT', 'QUANTILE_DISC',
}
NUMBER_TYPE_MARKERS = (
    'INT', 'DOUBLE', 'FLOAT', 'DECIMAL', 'NUMERIC', 'REAL', 'HUGEINT',
)
INCOMPARABLE_TYPE_MARKERS = (
    'LIST', 'STRUCT', 'MAP', 'ARRAY', 'UNION', 'JSON', 'BLOB', 'BIT',
)


class PolicyError(ValueError):
    pass


def validate_sql(sql: str) -> None:
    if not isinstance(sql, str) or len(sql) > 32000:
        raise PolicyError('SQL must be text of at most 32,000 characters.')
    statements = sqlglot.parse(sql, read='duckdb')
    if len(statements) != 1 or not isinstance(statements[0], exp.Select):
        raise PolicyError('Read mode accepts exactly one SELECT query.')
    tree = statements[0]
    forbidden = (exp.Insert, exp.Update, exp.Delete, exp.Create, exp.Drop,
                 exp.Alter, exp.Command, exp.Into, exp.Union)
    if any(isinstance(node, forbidden) for node in tree.walk()):
        raise PolicyError('This statement is outside the supported read-query subset.')
    if tree.args.get('with_'):
        raise PolicyError('Common table expressions are not supported in this milestone.')
    for table in tree.find_all(exp.Table):
        if not isinstance(table.this, exp.Identifier) or table.name.lower() != 'dataset' or table.db or table.catalog:
            raise PolicyError('Queries can read only the selected table: dataset.')
    for node in tree.walk():
        if isinstance(node, exp.With):
            raise PolicyError('Common table expressions are not supported in this milestone.')
        if isinstance(node, exp.Func):
            name = node.name.upper() if isinstance(node, exp.Anonymous) else node.sql_name()
            if name not in FUNCTIONS:
                raise PolicyError(f'Function {name} is not enabled in read mode.')


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def sql_literal(value: str) -> str:
    if '\x00' in value:
        raise PolicyError('Choose a local DuckDB file.')
    return "'" + value.replace("'", "''") + "'"


def type_name(value: str) -> str:
    return value.upper().split('(')[0].strip()


def is_number_type(duckdb_type: str) -> bool:
    text = type_name(duckdb_type)
    if 'INTERVAL' in text:
        return False
    return any(marker in text for marker in NUMBER_TYPE_MARKERS)


def is_temporal_type(duckdb_type: str) -> bool:
    text = type_name(duckdb_type)
    return 'DATE' in text or 'TIME' in text


def is_comparable_type(duckdb_type: str) -> bool:
    text = type_name(duckdb_type)
    return not any(marker in text for marker in INCOMPARABLE_TYPE_MARKERS)


def json_value(value):
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return None if math.isnan(value) or math.isinf(value) else value
    if isinstance(value, Decimal):
        if not value.is_finite():
            return None
        # Preserve decimal precision in JSON; column type retains the numeric semantics.
        return str(value)
    if isinstance(value, (dt.date, dt.time, dt.datetime, dt.timedelta)):
        return str(value)
    text = str(value)
    if len(text) > MAX_CELL_CHARS:
        text = text[:MAX_CELL_CHARS] + '…'
    return text


def display_cell(value):
    typed = json_value(value)
    if typed is None:
        return None
    text = str(typed)
    if len(text) > MAX_CELL_CHARS:
        return text[:MAX_CELL_CHARS] + '…'
    return text


def column_kind(duckdb_type: str, values: list) -> str:
    if values and all(item is None for item in values):
        return 'null'
    return 'number' if is_number_type(duckdb_type) else 'text'


def looks_like_date(value) -> bool:
    if isinstance(value, (dt.date, dt.datetime)):
        return True
    if not isinstance(value, str):
        return False
    return ISO_DATE_PREFIX.match(value) is not None


def suggest_chart(sql: str, columns: list[dict], values: list[list], kinds: list[str], truncated: bool) -> dict:
    suggestion = {'kind': 'none', 'sql': sql}
    if truncated or len(columns) != 2 or not (CHART_MIN_ROWS <= len(values) <= CHART_MAX_ROWS):
        return suggestion
    if len(kinds) != 2 or kinds[1] != 'number':
        return suggestion
    y_values = [row[1] if len(row) > 1 else None for row in values]
    if any(not isinstance(item, (int, float)) or isinstance(item, bool) for item in y_values):
        return suggestion
    x_values = [row[0] if row else None for row in values]
    x_type = columns[0].get('type', '')
    if kinds[0] == 'number' or is_temporal_type(x_type) or all(item is None or looks_like_date(item) for item in x_values):
        suggestion['kind'] = 'line'
        return suggestion
    if kinds[0] == 'text':
        suggestion['kind'] = 'bar'
    return suggestion


def profile_sql(schema: list[dict]) -> str:
    parts = ['count(*) AS "__rows"']
    for index, field in enumerate(schema):
        quoted = quote_ident(field['name'])
        alias = str(index)
        parts.append(f'count({quoted}) AS "{alias}__nn"')
        parts.append(f'count(DISTINCT {quoted}) AS "{alias}__d"')
        if is_comparable_type(field['type']):
            parts.append(f'min({quoted}) AS "{alias}__min"')
            parts.append(f'max({quoted}) AS "{alias}__max"')
    return 'SELECT ' + ', '.join(parts) + '\nFROM dataset'


def profile_from_row(schema: list[dict], row: tuple | list | None) -> list[dict]:
    if not row:
        return []
    total = int(row[0] or 0)
    offset = 1
    columns = []
    for index, field in enumerate(schema):
        non_null = int(row[offset] or 0)
        distinct = int(row[offset + 1] or 0)
        offset += 2
        null_count = max(total - non_null, 0)
        stats = {
            'name': field['name'],
            'type': field['type'],
            'null_count': null_count,
            'null_pct': 0.0 if total == 0 else round(100.0 * null_count / total, 2),
            'distinct_count': distinct,
        }
        if is_comparable_type(field['type']):
            lowest, highest = json_value(row[offset]), json_value(row[offset + 1])
            offset += 2
            if lowest is not None:
                stats['min'] = lowest
            if highest is not None:
                stats['max'] = highest
        columns.append(stats)
    return columns


def profile_table(profile: list[dict]) -> tuple[list[dict], list[list], list[list], list[str]]:
    columns = [
        {'name': 'column', 'type': 'VARCHAR'},
        {'name': 'type', 'type': 'VARCHAR'},
        {'name': 'null_count', 'type': 'BIGINT'},
        {'name': 'null_pct', 'type': 'DOUBLE'},
        {'name': 'distinct_count', 'type': 'BIGINT'},
        {'name': 'min', 'type': 'VARCHAR'},
        {'name': 'max', 'type': 'VARCHAR'},
    ]
    rows = []
    values = []
    for stats in profile:
        typed = [
            stats['name'], stats['type'], stats['null_count'], stats['null_pct'],
            stats['distinct_count'], stats.get('min'), stats.get('max'),
        ]
        values.append(typed)
        rows.append([display_cell(item) for item in typed])
    kinds = ['text', 'text', 'number', 'number', 'number', 'text', 'text']
    return columns, rows, values, kinds


def collect_rows(cursor) -> tuple[list[list], list[list], bool, bool]:
    rows = []
    values = []
    truncated = False
    cells_truncated = False
    output_bytes = 0
    for index in range(MAX_ROWS + 1):
        row = cursor.fetchone()
        if row is None:
            break
        if index == MAX_ROWS:
            truncated = True
            break
        typed = []
        display = []
        for item in row:
            if item is not None and len(str(item)) > MAX_CELL_CHARS:
                cells_truncated = True
            typed.append(json_value(item))
            display.append(display_cell(item))
        size = len(json.dumps(display, ensure_ascii=True).encode('utf-8'))
        size += len(json.dumps(typed, ensure_ascii=True).encode('utf-8'))
        if output_bytes + size > MAX_OUTPUT_BYTES:
            truncated = True
            break
        output_bytes += size
        rows.append(display)
        values.append(typed)
    return rows, values, truncated, cells_truncated


def fit_response(result: dict) -> dict:
    rows = result['rows']
    values = result['values']
    while True:
        result['rows'] = rows
        result['values'] = values
        result['chart'] = suggest_chart(
            result['sql'], result['columns'], values, result['column_kinds'], result['truncated'],
        )
        encoded = json.dumps(result, ensure_ascii=True).encode('utf-8')
        if len(encoded) <= MAX_RESPONSE_BYTES:
            return result
        if not rows:
            raise PolicyError('Result metadata exceeds the response size limit.')
        rows.pop()
        values.pop()
        result['truncated'] = True


def local_duckdb_path(request: dict, *, must_exist: bool) -> pathlib.Path:
    raw = request.get('path')
    if not isinstance(raw, str) or not raw or len(raw) > 4096:
        raise PolicyError('Choose a local DuckDB file.')
    source = pathlib.Path(raw).expanduser()
    if source.suffix.lower() != '.duckdb':
        raise PolicyError('Choose a local DuckDB file.')
    if must_exist:
        source = source.resolve(strict=True)
        if not source.is_file():
            raise PolicyError('Choose a local DuckDB file.')
        if source.stat().st_size > MAX_FILE_BYTES:
            raise PolicyError('This development build accepts files up to 256 MiB.')
        return source
    parent = source.parent.resolve(strict=True)
    return parent / source.name


def create_database(request: dict) -> dict:
    target = local_duckdb_path(request, must_exist=False)
    if target.exists():
        raise PolicyError('That database file already exists.')
    connection = duckdb.connect(str(target))
    connection.close()
    return {'ok': True, 'action': 'create_database', 'source': target.name, 'path': str(target), 'tables': []}


def inspect_database(request: dict) -> dict:
    source = local_duckdb_path(request, must_exist=True)
    connection = duckdb.connect(str(source), read_only=True)
    try:
        names = [
            row[0] for row in connection.execute(
                "SELECT table_name FROM information_schema.tables "
                "WHERE table_schema = 'main' AND table_type = 'BASE TABLE' ORDER BY table_name"
            ).fetchall()
        ]
        tables = []
        for name in names:
            if not isinstance(name, str) or TABLE_NAME.fullmatch(name) is None:
                continue
            columns = [
                {'name': row[0], 'type': row[1]}
                for row in connection.execute(f'DESCRIBE {quote_ident(name)}').fetchall()
            ]
            tables.append({'name': name, 'columns': columns})
        return {'ok': True, 'action': 'inspect_database', 'source': source.name, 'path': str(source), 'tables': tables}
    finally:
        connection.close()


def query(request: dict) -> dict:
    started = time.perf_counter()
    action = request.get('action', 'query')
    if action == 'create_database':
        return create_database(request)
    if action == 'inspect_database':
        return inspect_database(request)
    if action not in {'query', 'profile'}:
        raise PolicyError('Unknown worker action.')
    sql = request.get('sql', 'SELECT * FROM dataset LIMIT 200')
    if action == 'query':
        validate_sql(sql)
    source = pathlib.Path(request['path']).expanduser().resolve(strict=True)
    suffix = source.suffix.lower()
    if not source.is_file() or suffix not in {'.csv', '.parquet', '.duckdb'}:
        raise PolicyError('Choose a local CSV, Parquet, or DuckDB file.')
    if source.stat().st_size > MAX_FILE_BYTES:
        raise PolicyError('This development build accepts files up to 256 MiB.')
    table_name = None
    if suffix == '.duckdb':
        table_name = request.get('table')
        if not isinstance(table_name, str) or TABLE_NAME.fullmatch(table_name) is None:
            raise PolicyError('Choose one table in the local database.')
    deadline = request.get('timeout_seconds', 15)
    if not isinstance(deadline, (int, float)) or not .01 <= deadline <= 30:
        raise PolicyError('Query deadline must be between 0.01 and 30 seconds.')
    connection = duckdb.connect(config={
        'threads': 2, 'memory_limit': '512MB', 'temp_directory': '',
        'autoinstall_known_extensions': False, 'autoload_known_extensions': False,
    })
    timer = threading.Timer(deadline, connection.interrupt)
    timer.start()
    try:
        # Only application code receives a path. Parameter binding avoids path SQL injection.
        if suffix == '.duckdb':
            connection.execute(f'ATTACH {sql_literal(str(source))} AS src (READ_ONLY)')
            connection.execute(f'CREATE TABLE dataset AS SELECT * FROM src.{quote_ident(table_name)}')
            connection.execute('DETACH src')
        else:
            reader = 'read_csv' if suffix == '.csv' else 'read_parquet'
            connection.execute(f'CREATE TABLE dataset AS SELECT * FROM {reader}(?)', [str(source)])
        connection.execute('SET enable_external_access=false')
        connection.execute('SET lock_configuration=true')
        schema = [{'name': row[0], 'type': row[1]} for row in connection.execute('DESCRIBE dataset').fetchall()]
        if any(len(field['name']) > 512 for field in schema):
            raise PolicyError('Column names must be at most 512 characters.')
        if len(schema) > MAX_COLUMNS:
            raise PolicyError('This development build supports at most 100 columns.')
        count = connection.execute('SELECT count(*) FROM dataset').fetchone()[0]
        import_ms = (time.perf_counter() - started) * 1000
        profile = None
        if action == 'profile':
            sql = profile_sql(schema)
        statements = connection.extract_statements(sql)
        if len(statements) != 1 or statements[0].type != duckdb.StatementType.SELECT:
            raise PolicyError('The engine must classify this as one SELECT query.')
        cursor = connection.execute(sql)
        if action == 'profile':
            profile = profile_from_row(schema, cursor.fetchone())
            columns, rows, values, kinds = profile_table(profile)
            truncated = False
            cells_truncated = False
        else:
            columns = [{'name': d[0], 'type': str(d[1])} for d in cursor.description]
            if any(len(column['name']) > 512 for column in columns):
                raise PolicyError('Result column names must be at most 512 characters.')
            if len(columns) > MAX_COLUMNS:
                raise PolicyError('Result exceeds the 100-column display limit.')
            rows, values, truncated, cells_truncated = collect_rows(cursor)
            kinds = [column_kind(column['type'], [row[index] if index < len(row) else None for row in values])
                     for index, column in enumerate(columns)]
        result = {'ok': True, 'action': action, 'source': source.name, 'dataset_rows': count,
                'schema': schema, 'columns': columns, 'rows': rows, 'values': values,
                'column_kinds': kinds, 'truncated': truncated, 'cells_truncated': cells_truncated,
                'sql': sql, 'import_ms': round(import_ms, 2),
                'elapsed_ms': round((time.perf_counter() - started) * 1000, 2)}
        if profile is not None:
            result['profile'] = profile
        return fit_response(result)
    finally:
        timer.cancel()
        timer.join()
        connection.close()


def main() -> int:
    try:
        payload = sys.stdin.buffer.read(MAX_REQUEST_BYTES + 1)
        if len(payload) > MAX_REQUEST_BYTES:
            raise PolicyError('Request is too large.')
        request = json.loads(payload)
        if not isinstance(request, dict):
            raise PolicyError('Request must be a JSON object.')
        result = query(request)
    except Exception as exc:
        result = {'ok': False, 'error': str(exc)[:2000], 'kind': type(exc).__name__}
        if isinstance(exc, sqlglot.errors.ParseError) and exc.errors:
            issue = exc.errors[0]
            result['location'] = {'line': issue.get('line', 1), 'column': issue.get('col', 1)}
    print(json.dumps(result, ensure_ascii=True))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
