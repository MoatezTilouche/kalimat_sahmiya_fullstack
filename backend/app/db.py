"""Versioned, additive SQLite migrations; dictionaries never contain player data."""
from pathlib import Path
import os
import sqlite3
from .arabic import normalize_answer, normalize_clue, valid_pair
from .seed_data import PAIRS
from .curated import MEDIUM, HARD
from .difficulty import classify

DB_FILE = Path(__file__).resolve().parents[1] / 'words.db'
SCHEMA_VERSION = 3


class ClosingConnection(sqlite3.Connection):
    def __exit__(self, *args):
        try:
            return super().__exit__(*args)
        finally:
            self.close()


def connect(db_file: Path | str | None = None) -> sqlite3.Connection:
    connection = sqlite3.connect(db_file or os.getenv('WORDS_DB') or DB_FILE, timeout=30,
                                 factory=ClosingConnection)
    connection.row_factory = sqlite3.Row
    connection.execute('PRAGMA foreign_keys=ON')
    return connection


def setup(db_file: Path | str | None = None) -> None:
    with connect(db_file) as db:
        if db.execute('PRAGMA user_version').fetchone()[0] > SCHEMA_VERSION:
            raise ValueError('Dictionary schema is newer than this application; update the backend')
        db.execute('PRAGMA journal_mode=WAL')
        db.execute('BEGIN IMMEDIATE')
        db.execute('''CREATE TABLE IF NOT EXISTS words (
            id INTEGER PRIMARY KEY, answer TEXT NOT NULL, clue TEXT NOT NULL,
            length INTEGER NOT NULL, origin TEXT NOT NULL DEFAULT 'starter',
            UNIQUE(answer, clue))''')
        columns = {row['name'] for row in db.execute('PRAGMA table_info(words)')}
        additions = {
            'difficulty': "TEXT NOT NULL DEFAULT 'medium'",
            'difficulty_score': 'REAL NOT NULL DEFAULT 1.5',
            'classification_method': "TEXT NOT NULL DEFAULT 'unclassified'",
            'frequency_rank': 'INTEGER', 'frequency_count': 'INTEGER',
            'frequency_source': 'TEXT', 'source_ref': 'TEXT',
            'eligible': 'INTEGER NOT NULL DEFAULT 1',
        }
        for name, declaration in additions.items():
            if name not in columns:
                db.execute(f'ALTER TABLE words ADD COLUMN {name} {declaration}')
        db.execute('''CREATE TABLE IF NOT EXISTS imports (
            sha256 TEXT PRIMARY KEY, source TEXT NOT NULL, imported_at TEXT NOT NULL,
            report_json TEXT NOT NULL)''')
        db.execute('CREATE INDEX IF NOT EXISTS idx_length ON words(length)')
        db.execute('CREATE INDEX IF NOT EXISTS idx_words_pool ON words(difficulty, eligible, id)')
        db.execute('CREATE INDEX IF NOT EXISTS idx_words_size ON words(difficulty, eligible, length, id)')
        curated = set(MEDIUM + HARD)
        for answer, clue in [*PAIRS, *MEDIUM, *HARD]:
            a, q = normalize_answer(answer), normalize_clue(clue)
            if valid_pair(a, q):
                metadata = classify(a, q).metadata()
                db.execute('''INSERT OR IGNORE INTO words
                    (answer,clue,length,origin,difficulty,difficulty_score,classification_method)
                    VALUES (?,?,?,?,?,?,?)''',
                    (a, q, len(a), 'curated' if (answer, clue) in curated else 'starter',
                     metadata['difficulty'], metadata['difficulty_score'], metadata['classification_method']))
        # Retain legacy rows; exclude malformed pairs only from new puzzles.
        for row in db.execute("SELECT * FROM words WHERE classification_method='unclassified'").fetchall():
            a, q = normalize_answer(row['answer']), normalize_clue(row['clue'])
            metadata = classify(a, q).metadata()
            db.execute('''UPDATE words SET difficulty=?, difficulty_score=?,
                classification_method=?, eligible=? WHERE id=?''',
                (metadata['difficulty'], metadata['difficulty_score'], metadata['classification_method'],
                 int(valid_pair(a, q) and a == row['answer']), row['id']))
        from .knowledge import migrate_knowledge
        migrate_knowledge(db)
        db.execute(f'PRAGMA user_version={SCHEMA_VERSION}')


def counts(db_file=None) -> dict:
    result = {d: {'pairs': 0, 'answers': 0} for d in ('easy', 'medium', 'hard')}
    with connect(db_file) as db:
        for row in db.execute('''SELECT difficulty, COUNT(*) AS pairs,
                COUNT(DISTINCT answer) AS answers FROM words WHERE eligible=1 GROUP BY difficulty'''):
            result[row['difficulty']] = {'pairs': row['pairs'], 'answers': row['answers']}
    return result


def fetch_pairs(limit: int = 200, offset: int = 0, length: int | None = None,
                seed: int = 1, db_file=None, difficulty: str | None = None) -> list[dict]:
    # Indexed stable pagination; seed stays accepted for compatible clients.
    where, args = ['eligible=1'], []
    if difficulty:
        where.append('difficulty=?')
        args.append(difficulty)
    if length is not None:
        where.append('length=?')
        args.append(length)
    with connect(db_file) as db:
        rows = db.execute(f'''SELECT id,answer,clue,length,origin,difficulty,
            classification_method,frequency_rank,frequency_source FROM words
            WHERE {' AND '.join(where)} ORDER BY id LIMIT ? OFFSET ?''',
            [*args, limit, offset]).fetchall()
    return [dict(row) for row in rows]


def all_entries(size: int | None = None, db_file=None, difficulty: str | None = None,
                level: int = 1, limit: int = 600, reviewed_only: bool = False):
    """Indexed wraparound windows avoid full-table random sorting.

    A prime stride rotates candidate windows. The generator seed shuffles small
    pools. One clue is selected per answer; no easier category is substituted.
    """
    from .generator import Entry
    where, args = ['eligible=1', 'length BETWEEN 2 AND ?'], [min((size or 9) - 1, 10)]
    if difficulty:
        where.append('difficulty=?')
        args.append(difficulty)
    if reviewed_only:
        where.append("origin IN ('starter','curated')")
    clause = ' AND '.join(where)
    with connect(db_file) as db:
        total = db.execute(f'SELECT COUNT(*) FROM words WHERE {clause}', args).fetchone()[0]
        offset = ((level - 1) * 137) % max(total, 1)
        query = f'SELECT id,answer,clue,difficulty,origin FROM words WHERE {clause} ORDER BY id LIMIT ? OFFSET ?'
        rows = db.execute(query, [*args, limit, offset]).fetchall()
        if offset and len(rows) < min(limit, total):
            rows += db.execute(query, [*args, min(limit, total) - len(rows), 0]).fetchall()
    unique = {}
    for row in rows:
        if row['answer'] not in unique and valid_pair(row['answer'], row['clue']):
            unique[row['answer']] = Entry(row['answer'], row['clue'], row['difficulty'], row['origin'], row['id'])
    return list(unique.values())
