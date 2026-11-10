"""Export source definitions, not generated content; keep every existing puzzle intact."""
import hashlib
import json
from pathlib import Path
from app.db import setup, connect
from app.knowledge import serialize


def main():
    setup()
    root = Path(__file__).resolve().parents[1] / 'flutter_app/assets'
    with connect() as db:
        cards, seen = [], set()
        for row in db.execute('''SELECT k.* FROM knowledge k JOIN words w ON w.id=k.word_id
            WHERE k.review_status='dictionary_import' AND w.eligible=1 AND w.frequency_rank IS NOT NULL
              AND k.source_ref LIKE '%-n' AND length(w.answer)>=3 AND length(k.definition) BETWEEN 12 AND 180
            ORDER BY w.frequency_rank,k.id LIMIT 2000'''):
            if row['word'] in seen:
                continue
            seen.add(row['word'])
            cards.append(serialize(row))
            if len(cards) == 60:
                break
        folder = root / 'knowledge'
        folder.mkdir(exist_ok=True)
        (folder / 'cards.json').write_text(json.dumps(cards, ensure_ascii=False, indent=2), encoding='utf-8')
        path = root / 'puzzles/starter_levels.json'
        puzzles = json.loads(path.read_text(encoding='utf-8'))
        for puzzle in puzzles:
            for word in puzzle['words']:
                row = db.execute('SELECT id FROM words WHERE answer=? AND clue=?',
                                 (word['answer'], word['clue'])).fetchone()
                if row:
                    word['wordId'] = row['id']
        payload = json.dumps(puzzles, ensure_ascii=False, separators=(',', ':'))
        path.write_text(payload, encoding='utf-8')
        report_path = path.with_name('validation_report.json')
        report = json.loads(report_path.read_text(encoding='utf-8'))
        report['sha256'] = hashlib.sha256(payload.encode()).hexdigest()
        report_path.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Exported {len(cards)} attributed definitions; enriched {len(puzzles)} existing puzzles with word IDs.')


if __name__ == '__main__':
    main()
