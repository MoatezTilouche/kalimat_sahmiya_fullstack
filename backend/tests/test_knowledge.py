from fastapi.testclient import TestClient
from app.db import connect, setup, SCHEMA_VERSION
from app.knowledge import migrate_knowledge
from app.main import app


def imported_cards():
    # Dictionary fixtures only, not a fabricated cultural-fact corpus.
    with connect() as db:
        for answer, definition in [('قمر', 'تابع طبيعي للأرض'), ('بحر', 'مسطح واسع من الماء المالح'),
                                   ('نهر', 'مجرى طبيعي للماء')]:
            db.execute('''INSERT OR IGNORE INTO words
                (answer,clue,length,origin,difficulty,source_ref)
                VALUES (?,?,?,'Arabic WordNet 4.0','easy','awn4:test')''',
                       (answer, definition, len(answer)))
            db.execute("UPDATE words SET origin='Arabic WordNet 4.0',source_ref='awn4:test',difficulty='easy',classification_method='fixture' WHERE answer=? AND clue=?", (answer, definition))
            db.execute('DELETE FROM knowledge WHERE word_id IN (SELECT id FROM words WHERE answer=? AND clue=?)', (answer, definition))
        migrate_knowledge(db)
        return db.execute("SELECT word_id FROM knowledge WHERE review_status='dictionary_import' ORDER BY id").fetchall()


def test_knowledge_endpoints_sources_and_validation():
    ids = imported_cards()
    with TestClient(app) as client:
        word_id = ids[0][0]
        card = client.get(f'/api/knowledge/{word_id}').json()
        assert card['definition'] and card['word']
        assert card['sourceLicense'] == 'CC BY 4.0'
        assert card['sourceRef'] == 'awn4:test'
        assert card['fact'] is None and card['reviewStatus'] == 'dictionary_import'
        assert card['createdAt'] and card['updatedAt']
        assert client.get('/api/knowledge/categories').json()['items'][0]['id'] == 'language'
        assert len(client.get('/api/knowledge?category=language&limit=2').json()['items']) == 2
        assert client.get('/api/knowledge?category=history').json()['items'] == []
        assert client.get('/api/knowledge/random?difficulty=easy').json()['difficulty'] == 'easy'
        for path in ['/api/knowledge?limit=0', '/api/knowledge?category=invalid',
                     '/api/knowledge/random?difficulty=invalid', '/api/knowledge/-1']:
            assert client.get(path).status_code == 422
        assert client.get('/api/knowledge/999999999').status_code == 404


def test_quiz_has_exactly_one_demonstrably_correct_choice():
    ids = imported_cards()
    with TestClient(app) as client:
        for row in ids:
            quiz = client.get(f'/api/knowledge/{row[0]}/quiz').json()
            assert len(set(quiz['choices'])) == 3
            matches = [choice for choice in quiz['choices']
                       if choice[0] == quiz['cue']['firstLetter'] and len(choice) == quiz['cue']['length']]
            assert matches == [quiz['choices'][quiz['correctIndex']]]
        with connect() as db:
            unreviewed = db.execute("SELECT word_id FROM knowledge WHERE review_status='unreviewed' LIMIT 1").fetchone()[0]
        assert client.get(f'/api/knowledge/{unreviewed}/quiz').status_code == 404


def test_migration_is_additive_and_preserves_editorial_content(isolated_dictionary):
    ids = imported_cards()
    with connect() as db:
        before = [tuple(row) for row in db.execute('SELECT * FROM words ORDER BY id')]
        count = db.execute('SELECT COUNT(*) FROM knowledge').fetchone()[0]
        db.execute("UPDATE knowledge SET fact='محتوى المراجعة',review_status='reviewed' WHERE word_id=?", (ids[0][0],))
        db.execute('PRAGMA user_version=2')
    setup(isolated_dictionary)
    setup(isolated_dictionary)
    with connect() as db:
        assert before == [tuple(row) for row in db.execute('SELECT * FROM words ORDER BY id')]
        assert db.execute('SELECT COUNT(*) FROM knowledge').fetchone()[0] == count
        assert db.execute('PRAGMA user_version').fetchone()[0] == SCHEMA_VERSION
        assert db.execute('SELECT fact FROM knowledge WHERE word_id=?', (ids[0][0],)).fetchone()[0] == 'محتوى المراجعة'
