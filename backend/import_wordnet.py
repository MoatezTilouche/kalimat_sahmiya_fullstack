"""Stream only the supplied AWN4 WN-LMF file. No wn cache or LLM dependency."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import gzip
import hashlib
import json
from pathlib import Path
import sqlite3
from defusedxml.ElementTree import iterparse
from app.arabic import normalize_answer, normalize_clue, valid_pair
from app.db import connect, counts, setup
from app.difficulty import classify, load_frequencies


def file_hash(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def read_wordnet(source: Path):
    opener = gzip.open if source.suffix == '.gz' else open
    definitions, entries, lexicons = {}, [], []
    with opener(source, 'rb') as stream:
        for event, node in iterparse(stream, events=('start', 'end')):
            tag = node.tag.rsplit('}', 1)[-1]
            if event == 'start' and tag == 'Lexicon':
                lexicons.append((node.get('id', ''), node.get('language', ''), node.get('version', '')))
            if event != 'end':
                continue
            if tag == 'Synset':
                values = [normalize_clue(''.join(child.itertext())) for child in node
                          if child.tag.rsplit('}', 1)[-1] == 'Definition']
                definitions[node.get('id')] = [v for v in values if v]
                node.clear()
            elif tag == 'LexicalEntry':
                lemma, senses = None, []
                for child in node:
                    child_tag = child.tag.rsplit('}', 1)[-1]
                    if child_tag == 'Lemma':
                        lemma = normalize_answer(child.get('writtenForm', ''))
                    elif child_tag == 'Sense':
                        senses.append(child.get('synset'))
                if lemma:
                    entries.append((lemma, senses))
                node.clear()
    if not lexicons or any(name != 'awn4' or lang not in ('ar', 'arb') for name, lang, _ in lexicons):
        raise ValueError('Expected an Arabic awn4 lexicon, not another WordNet dataset')
    if not entries or not definitions:
        raise ValueError('WordNet file contains no lexical entries or definitions')
    version = lexicons[0][2]
    for lemma, senses in entries:
        for sense in senses:
            for definition in definitions.get(sense, []):
                yield lemma, definition, f'awn4:{version}:{sense}'


def import_wordnet(source: Path, db_file=None, frequency_file: Path | None = None) -> dict:
    if not source.is_file():
        raise FileNotFoundError(f'WordNet file not found: {source}. Run python fetch_wordnet.py first.')
    digest = file_hash(source)
    pairs = list(read_wordnet(source))  # validate entire XML before changing the DB
    frequencies = load_frequencies(frequency_file, {a for a, _, _ in pairs}) if frequency_file else {}
    frequency_source = f'{frequency_file.name}:{file_hash(frequency_file)}' if frequency_file else None
    setup(db_file)
    report = Counter(scanned=len(pairs), inserted=0, duplicates=0, rejected=0, measured=0)
    with connect(db_file) as db:
        for a, q, ref in pairs:
            if not valid_pair(a, q):
                report['rejected'] += 1
                continue
            metadata = classify(a, q, frequencies.get(a), frequency_source).metadata()
            if a in frequencies:
                report['measured'] += 1
            cursor = db.execute('''INSERT OR IGNORE INTO words
                (answer,clue,length,origin,source_ref,difficulty,difficulty_score,
                 classification_method,frequency_rank,frequency_count,frequency_source)
                 VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
                (a, q, len(a), 'Arabic WordNet 4.0', ref, *metadata.values()))
            report['inserted' if cursor.rowcount else 'duplicates'] += 1
            if not cursor.rowcount:
                db.execute('''UPDATE words SET source_ref=COALESCE(source_ref,?),
                    difficulty=?,difficulty_score=?,classification_method=?,frequency_rank=?,
                    frequency_count=?,frequency_source=? WHERE answer=? AND clue=?''',
                    (ref, *metadata.values(), a, q))
        db.execute('INSERT OR REPLACE INTO imports VALUES (?,?,?,?)',
                   (digest, source.name, datetime.now(timezone.utc).isoformat(), json.dumps(report)))
        from app.knowledge import migrate_knowledge
        migrate_knowledge(db)
    return {**report, 'sha256': digest, 'frequency_source': frequency_source, 'counts': counts(db_file)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--db', type=Path)
    parser.add_argument('--frequency-file', type=Path)
    args = parser.parse_args()
    try:
        report = import_wordnet(args.source, args.db, args.frequency_file)
    except Exception as exc:
        parser.exit(1, f'WordNet import failed: {exc}\n')
    print(json.dumps(report, indent=2, ensure_ascii=True))


if __name__ == '__main__':
    main()
