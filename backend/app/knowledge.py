"""Source-preserving dictionary cards. No generated facts or semantic guesses.

Imported definitions are explicitly not human-reviewed facts. Quizzes include an
orthographic cue; distractors cannot match that cue, even for synonymous entries.
"""
import random
from .db import connect

CATEGORIES = {
    'language': 'اللغة العربية', 'history': 'التاريخ', 'geography': 'الجغرافيا',
    'science': 'العلوم', 'literature': 'الأدب العربي', 'civilizations': 'الحضارات',
    'nature': 'الطبيعة', 'culture': 'الثقافة العامة', 'inventions': 'الاختراعات',
}
WORDNET_URL = 'https://github.com/Salah-Sal/arabic-wordnet-v4'


def migrate_knowledge(db):
    db.execute('''CREATE TABLE IF NOT EXISTS knowledge (
        id INTEGER PRIMARY KEY, word_id INTEGER NOT NULL UNIQUE REFERENCES words(id),
        word TEXT NOT NULL, definition TEXT NOT NULL, explanation TEXT, fact TEXT,
        category TEXT NOT NULL DEFAULT 'language', difficulty TEXT NOT NULL,
        source_name TEXT NOT NULL, source_url TEXT, source_ref TEXT,
        source_license TEXT, review_status TEXT NOT NULL DEFAULT 'unreviewed',
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
        UNIQUE(word, definition))''')
    db.execute('CREATE INDEX IF NOT EXISTS idx_knowledge_category ON knowledge(category,difficulty,id)')
    db.execute('CREATE INDEX IF NOT EXISTS idx_knowledge_difficulty ON knowledge(difficulty,id)')
    db.execute('CREATE INDEX IF NOT EXISTS idx_knowledge_review ON knowledge(review_status,id)')
    db.execute('''INSERT OR IGNORE INTO knowledge
        (word_id,word,definition,difficulty,source_name,source_url,source_ref,
         source_license,review_status)
        SELECT id,answer,clue,difficulty,
            CASE WHEN origin='Arabic WordNet 4.0' THEN 'ووردنت العربية ٤.٠ — صلاح عبده'
                 ELSE 'معجم اللعبة الأصلي' END,
            CASE WHEN origin='Arabic WordNet 4.0' THEN ? END,source_ref,
            CASE WHEN origin='Arabic WordNet 4.0' THEN 'CC BY 4.0' END,
            CASE WHEN origin='Arabic WordNet 4.0' THEN 'dictionary_import' ELSE 'unreviewed' END
        FROM words WHERE eligible=1''', (WORDNET_URL,))


def serialize(row):
    return {
        'id': row['id'], 'wordId': row['word_id'], 'word': row['word'],
        'definition': row['definition'], 'explanation': row['explanation'],
        'fact': row['fact'] if row['review_status'] == 'reviewed' else None,
        'category': row['category'], 'categoryLabel': CATEGORIES.get(row['category'], 'اللغة العربية'),
        'difficulty': row['difficulty'], 'sourceName': row['source_name'],
        'sourceUrl': row['source_url'], 'sourceRef': row['source_ref'],
        'sourceLicense': row['source_license'], 'dataLicense': 'CC BY-SA 4.0',
        'reviewStatus': row['review_status'],
        'createdAt': row['created_at'], 'updatedAt': row['updated_at'],
    }


def get_card(word_id):
    with connect() as db:
        row = db.execute('SELECT * FROM knowledge WHERE word_id=?', (word_id,)).fetchone()
    return serialize(row) if row else None


def list_cards(category=None, difficulty=None, limit=20, offset=0, random_one=False):
    where, args = [], []
    for column, value in [('category', category), ('difficulty', difficulty)]:
        if value:
            where.append(f'{column}=?')
            args.append(value)
    clause = ' WHERE ' + ' AND '.join(where) if where else ''
    with connect() as db:
        if random_one:
            count = db.execute('SELECT COUNT(*) FROM knowledge' + clause, args).fetchone()[0]
            if not count:
                return []
            offset, limit = random.randrange(count), 1
        rows = db.execute('SELECT * FROM knowledge' + clause + ' ORDER BY review_status,id LIMIT ? OFFSET ?',
                          [*args, limit, offset]).fetchall()
    return [serialize(row) for row in rows]


def categories():
    with connect() as db:
        counts = dict(db.execute('SELECT category,COUNT(*) FROM knowledge GROUP BY category'))
    return [{'id': key, 'label': label, 'count': counts.get(key, 0)} for key, label in CATEGORIES.items()]


def quiz(word_id):
    card = get_card(word_id)
    if not card or card['reviewStatus'] not in ('dictionary_import', 'reviewed'):
        return None
    answer = card['word']
    with connect() as db:
        rows = db.execute('''SELECT MIN(word_id) AS word_id,word FROM knowledge
            WHERE review_status IN ('dictionary_import','reviewed')
              AND difficulty=? AND word<>? AND substr(word,1,1)<>?
            GROUP BY word ORDER BY word_id LIMIT 2''',
            (card['difficulty'], answer, answer[0])).fetchall()
    if len(rows) != 2:
        return None
    choices = [answer, *(r['word'] for r in rows)]
    random.Random(word_id).shuffle(choices)
    return {'id': f'dictionary-{word_id}-v1', 'wordId': word_id,
            'kind': 'definition_with_spelling_cue', 'question': card['definition'],
            'cue': {'firstLetter': answer[0], 'length': len(answer)},
            'choices': choices, 'correctIndex': choices.index(answer),
            'sourceName': card['sourceName'], 'sourceUrl': card['sourceUrl'],
            'sourceLicense': card['sourceLicense']}
