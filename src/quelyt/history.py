"""Local SQLite action traces. No credentials, no result grids, no network."""
from __future__ import annotations

import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA_VERSION = 1
MAX_SQL_CHARS = 32000
MAX_ERROR_CHARS = 2000
MAX_LIST = 50
MAX_SOURCES = 12
MAX_TRACES = 500


class HistoryError(ValueError):
    pass


def history_path() -> Path:
    override = os.environ.get('QUELYT_HISTORY_PATH')
    if override:
        path = Path(override).expanduser()
        path.parent.mkdir(parents=True, exist_ok=True)
        return path
    root = Path.home() / 'Library' / 'Application Support' / 'dev.quelyt.desktop'
    root.mkdir(parents=True, exist_ok=True)
    return root / 'history.sqlite'


def connect(path: Path | None = None) -> sqlite3.Connection:
    connection = sqlite3.connect(str(path or history_path()))
    connection.row_factory = sqlite3.Row
    connection.execute('PRAGMA foreign_keys=ON')
    migrate(connection)
    return connection


def migrate(connection: sqlite3.Connection) -> None:
    version = connection.execute('PRAGMA user_version').fetchone()[0]
    if version > SCHEMA_VERSION:
        raise HistoryError('History file is newer than this application.')
    if version == 0:
        connection.executescript('''
            CREATE TABLE sources (
              id INTEGER PRIMARY KEY,
              path TEXT NOT NULL UNIQUE,
              name TEXT NOT NULL,
              opened_at TEXT NOT NULL
            );
            CREATE TABLE traces (
              id INTEGER PRIMARY KEY,
              source_id INTEGER NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
              sql TEXT NOT NULL,
              action TEXT NOT NULL,
              ok INTEGER NOT NULL,
              error TEXT,
              kind TEXT,
              row_count INTEGER,
              dataset_rows INTEGER,
              elapsed_ms REAL,
              truncated INTEGER,
              chart_kind TEXT,
              created_at TEXT NOT NULL
            );
            CREATE INDEX traces_created ON traces(created_at DESC);
        ''')
        connection.execute(f'PRAGMA user_version={SCHEMA_VERSION}')
        connection.commit()


def _now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def touch_source(connection: sqlite3.Connection, path: str) -> int:
    if not isinstance(path, str) or not path or len(path) > 4096:
        raise HistoryError('Source path is missing or too long.')
    resolved = str(Path(path).expanduser())
    name = Path(resolved).name
    now = _now()
    connection.execute(
        'INSERT INTO sources(path, name, opened_at) VALUES (?, ?, ?) '
        'ON CONFLICT(path) DO UPDATE SET name=excluded.name, opened_at=excluded.opened_at',
        (resolved, name, now),
    )
    row = connection.execute('SELECT id FROM sources WHERE path=?', (resolved,)).fetchone()
    return int(row['id'])


def record(payload: dict, path: Path | None = None) -> dict:
    sql = payload.get('sql') or ''
    if not isinstance(sql, str) or not sql.strip() or len(sql) > MAX_SQL_CHARS:
        raise HistoryError('SQL must be stored text of at most 32,000 characters.')
    action = payload.get('action') or 'query'
    if action not in {'query', 'profile'}:
        action = 'query'
    error = payload.get('error')
    if isinstance(error, str) and len(error) > MAX_ERROR_CHARS:
        error = error[:MAX_ERROR_CHARS]
    connection = connect(path)
    try:
        source_id = touch_source(connection, payload.get('path') or '')
        cursor = connection.execute(
            'INSERT INTO traces(source_id, sql, action, ok, error, kind, row_count, '
            'dataset_rows, elapsed_ms, truncated, chart_kind, created_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            (
                source_id, sql, action, 1 if payload.get('ok') else 0,
                error, payload.get('kind'), payload.get('row_count'),
                payload.get('dataset_rows'), payload.get('elapsed_ms'),
                1 if payload.get('truncated') else 0, payload.get('chart_kind'), _now(),
            ),
        )
        extra = connection.execute('SELECT COUNT(*) FROM traces').fetchone()[0]
        overflow = extra - MAX_TRACES
        if overflow > 0:
            connection.execute(
                'DELETE FROM traces WHERE id IN (SELECT id FROM traces ORDER BY id ASC LIMIT ?)',
                (overflow,),
            )
        connection.commit()
        return {'ok': True, 'id': cursor.lastrowid}
    finally:
        connection.close()


def _trace_row(row: sqlite3.Row) -> dict:
    return {
        'id': row['id'], 'path': row['path'], 'name': row['name'], 'sql': row['sql'],
        'action': row['action'], 'ok': bool(row['ok']), 'error': row['error'],
        'kind': row['kind'], 'row_count': row['row_count'], 'dataset_rows': row['dataset_rows'],
        'elapsed_ms': row['elapsed_ms'], 'truncated': bool(row['truncated']),
        'chart_kind': row['chart_kind'], 'created_at': row['created_at'],
    }


def list_traces(path: Path | None = None, limit: int = MAX_LIST) -> dict:
    connection = connect(path)
    try:
        traces = connection.execute(
            'SELECT traces.*, sources.path, sources.name FROM traces '
            'JOIN sources ON sources.id = traces.source_id '
            'ORDER BY traces.id DESC LIMIT ?',
            (max(1, min(limit, MAX_LIST)),),
        ).fetchall()
        sources = connection.execute(
            'SELECT path, name, opened_at FROM sources ORDER BY opened_at DESC LIMIT ?',
            (MAX_SOURCES,),
        ).fetchall()
        return {
            'ok': True,
            'traces': [_trace_row(row) for row in traces],
            'sources': [{'path': row['path'], 'name': row['name'], 'opened_at': row['opened_at']} for row in sources],
        }
    finally:
        connection.close()


def delete_trace(trace_id: int, path: Path | None = None) -> dict:
    connection = connect(path)
    try:
        connection.execute('DELETE FROM traces WHERE id=?', (trace_id,))
        connection.commit()
        return {'ok': True}
    finally:
        connection.close()


def clear(path: Path | None = None) -> dict:
    connection = connect(path)
    try:
        connection.execute('DELETE FROM traces')
        connection.execute('DELETE FROM sources')
        connection.commit()
        return {'ok': True}
    finally:
        connection.close()


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else 'list'
    try:
        if command == 'record':
            payload = json.loads(sys.stdin.read())
            if not isinstance(payload, dict):
                raise HistoryError('Record payload must be a JSON object.')
            result = record(payload)
        elif command == 'list':
            result = list_traces()
        elif command == 'delete':
            if len(sys.argv) < 3:
                raise HistoryError('Delete requires a trace id.')
            result = delete_trace(int(sys.argv[2]))
        elif command == 'clear':
            result = clear()
        else:
            raise HistoryError('Unknown history command.')
    except Exception as exc:
        result = {'ok': False, 'error': str(exc)[:2000], 'kind': type(exc).__name__}
    print(json.dumps(result, ensure_ascii=True))
    return 0 if result.get('ok') else 1


if __name__ == '__main__':
    raise SystemExit(main())
