"""Audit the shipped SQLite dictionary and emit reproducible source/count metadata."""
import argparse
import json
from pathlib import Path
from app.db import connect, counts, setup
from app.arabic import valid_pair


def report():
    setup()
    with connect() as db:
        invalid = [row['id'] for row in db.execute('SELECT id,answer,clue FROM words WHERE eligible=1')
                   if not valid_pair(row['answer'], row['clue'])]
        result = {'difficultyCounts': counts(), 'eligiblePairs': db.execute('SELECT COUNT(*) FROM words WHERE eligible=1').fetchone()[0],
                  'distinctAnswers': db.execute('SELECT COUNT(DISTINCT answer) FROM words WHERE eligible=1').fetchone()[0],
                  'sources': [dict(row) for row in db.execute('SELECT origin,COUNT(*) AS pairs FROM words WHERE eligible=1 GROUP BY origin')],
                  'measuredFrequencyPairs': db.execute('SELECT COUNT(*) FROM words WHERE eligible=1 AND frequency_rank IS NOT NULL').fetchone()[0],
                  'heuristicPairs': db.execute('SELECT COUNT(*) FROM words WHERE eligible=1 AND frequency_rank IS NULL').fetchone()[0],
                  'imports': [dict(row) for row in db.execute('SELECT * FROM imports')], 'invalidEligibleIds': invalid}
    if invalid:
        raise ValueError(f'{len(invalid)} invalid eligible pairs')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    payload = json.dumps(report(), indent=2, ensure_ascii=False)
    if args.output:
        args.output.write_text(payload, encoding='utf-8')
    print(json.dumps(json.loads(payload), indent=2, ensure_ascii=True))
