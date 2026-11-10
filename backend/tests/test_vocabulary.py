import gzip
import sqlite3
from pathlib import Path
import pytest
from app.arabic import normalize_answer, normalize_clue, valid_pair
from app.db import setup, counts, connect, fetch_pairs, SCHEMA_VERSION
from app.difficulty import classify, difficulty_for_level, load_frequencies
from import_wordnet import import_wordnet


@pytest.mark.parametrize('level,expected', [(1,'easy'),(20,'easy'),(21,'medium'),(50,'medium'),(51,'hard'),(75,'hard')])
def test_boundaries(level, expected):
    assert difficulty_for_level(level) == expected


@pytest.mark.parametrize('answer,clue,expected', [
    ('قمر','تابع طبيعي للأرض','easy'),('بحر','مسطح مائي مالح','easy'),
    ('وجيب','خفقان القلب','medium'),('سهاد','الأرق وقلة النوم','medium'),
    ('ديجور','الظلام الشديد','hard'),('عسجد','اسم من أسماء الذهب','hard')])
def test_reviewed_familiarity(answer, clue, expected):
    result = classify(answer, clue)
    assert result.difficulty == expected
    assert result.frequency_rank is None
    assert result.classification_method.startswith('fallback')


def test_real_rank_and_unknown_frequency():
    assert classify('مجهول','وصف عام لمعنى قابل للفهم').difficulty == 'medium'
    assert classify('مجهول','وصف عام لمعنى قابل للفهم', (500, 1234), 'fixture').difficulty == 'easy'
    assert classify('مجهول','وصف عام لمعنى قابل للفهم', (100000, 2), 'fixture').difficulty == 'hard'
    assert classify('مجهول','مصطلح في علم الكيمياء وفيزياء الجزيء').difficulty == 'hard'


def test_cleanup_and_leaks():
    assert normalize_answer('أَسَد') == 'أسد'
    assert normalize_answer('رؤيا') != normalize_answer('رويا')
    assert valid_pair('قمر', normalize_clue('تابعٌ طبيعي للأرض'))
    for a, q in [('قمر','القَمَر جرم مضيء'),('أسد','الاسد حيوان مفترس'),('كلمة سيئة','تعريف طويل مناسب'),
                 ('كتاب','English definition'),('كتاب','هذا <b>تعريف</b>')]:
        assert not valid_pair(a, normalize_clue(q))


def test_additive_legacy_migration(tmp_path):
    path = tmp_path / 'legacy.db'
    with sqlite3.connect(path) as db:
        db.execute("CREATE TABLE words(id INTEGER PRIMARY KEY, answer TEXT, clue TEXT, length INTEGER, origin TEXT, UNIQUE(answer,clue))")
        db.execute("INSERT INTO words VALUES(8000,'قديم','وصف تراثي من مصدر محفوظ',4,'legacy')")
    setup(path)
    setup(path)
    with connect(path) as db:
        row = db.execute('SELECT * FROM words WHERE id=8000').fetchone()
        assert row['answer'] == 'قديم' and row['origin'] == 'legacy'
        assert db.execute('PRAGMA user_version').fetchone()[0] == SCHEMA_VERSION
    assert all(v['answers'] >= 80 for v in counts(path).values())


def test_frequency_file(tmp_path):
    path = tmp_path / 'frequency.tsv'
    path.write_text('word\tcount\nقَمَر\t900\nغريب\t2\n', encoding='utf-8')
    assert load_frequencies(path, {'قمر'}) == {'قمر': (1,900)}
    path.write_text('قمر\t2\nبحر\t900', encoding='utf-8')
    with pytest.raises(ValueError):
        load_frequencies(path)


def xml_data():
    return '''<?xml version="1.0" encoding="utf-8"?>
    <LexicalResource><Lexicon id="awn4" language="arb" version="4.0">
    <LexicalEntry id="a"><Lemma writtenForm="سَفَر"/><Sense synset="s1"/></LexicalEntry>
    <LexicalEntry id="b"><Lemma writtenForm="قمر"/><Sense synset="s2"/></LexicalEntry>
    <Synset id="s1"><Definition>انتقال بعيد عن مكان الإقامة</Definition></Synset>
    <Synset id="s2"><Definition>القمر تابع مضيء في السماء</Definition></Synset>
    </Lexicon></LexicalResource>'''


def test_import_idempotent_and_scoped(tmp_path, isolated_dictionary):
    source = tmp_path / 'awn.xml.gz'
    with gzip.open(source, 'wb') as out:
        out.write(xml_data().encode())
    a = import_wordnet(source)
    b = import_wordnet(source)
    assert a['inserted'] == 1 and a['rejected'] == 1
    assert b['inserted'] == 0 and b['duplicates'] == 1
    with connect() as db:
        row = db.execute("SELECT * FROM words WHERE source_ref='awn4:4.0:s1'").fetchone()
        assert row['answer'] == 'سفر'
        assert row['origin'] == 'Arabic WordNet 4.0'


def test_failed_import_preserves_database(tmp_path):
    before = counts()
    with pytest.raises(FileNotFoundError):
        import_wordnet(tmp_path / 'missing.xml')
    path = tmp_path / 'invalid.xml'
    path.write_text('<not-xml', encoding='utf-8')
    with pytest.raises(Exception):
        import_wordnet(path)
    assert counts() == before
