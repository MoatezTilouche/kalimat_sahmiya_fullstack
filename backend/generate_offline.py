"""Generate and validate an atomic offline release; never edits phone progress."""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
import hashlib
import json
from pathlib import Path
from app.db import setup, all_entries, counts
from app.difficulty import difficulty_for_level, size_for_level
from app.generator import generate_puzzle, validate_puzzle


def build(level, usage=None):
    size = size_for_level(level)
    entries = all_entries(size, difficulty=difficulty_for_level(level), level=level, reviewed_only=True)
    cap = {'easy': 3, 'medium': 7, 'hard': 8}[difficulty_for_level(level)]
    entries = [e for e in entries if (usage or {}).get(e.answer, 0) < cap]
    puzzle = generate_puzzle(entries, level=level, size=size, attempts=5, pool_size=110, usage=usage)
    puzzle['source'] = 'reviewed-offline-v2'
    validate_puzzle(puzzle)
    return puzzle


def build_chapter(levels):
    usage = Counter()
    puzzles = []
    for level in levels:
        puzzle = build(level, usage)
        usage.update(w['answer'] for w in puzzle['words'])
        puzzles.append(puzzle)
        print(f"Validated level {level}: {puzzle['difficulty']}, {len(puzzle['words'])} words", flush=True)
    return puzzles


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--levels', type=int, default=75)
    parser.add_argument('--workers', type=int, default=2)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] /
                        'flutter_app/assets/puzzles/starter_levels.json')
    args = parser.parse_args()
    if args.levels < 51:
        parser.error('Package at least 51 levels to cover all difficulties')
    setup()
    puzzles = []
    chapters = [list(range(1,21)), list(range(21,51)), list(range(51,args.levels + 1))]
    with ProcessPoolExecutor(max_workers=args.workers) as executor:
        for chapter in executor.map(build_chapter, chapters):
            puzzles.extend(chapter)
    payload = json.dumps(puzzles, ensure_ascii=False, separators=(',', ':'))
    temporary = args.output.with_suffix('.json.tmp')
    temporary.write_text(payload, encoding='utf-8')
    temporary.replace(args.output)
    usage = Counter(w['answer'] for p in puzzles for w in p['words'])
    report = {'levels': len(puzzles), 'sha256': hashlib.sha256(payload.encode()).hexdigest(),
              'counts': counts(), 'uniqueAnswersUsed': len(usage), 'maxAnswerUses': max(usage.values()),
              'levelsByDifficulty': dict(Counter(p['difficulty'] for p in puzzles)),
              'minimumWordsPerLevel': min(len(p['words']) for p in puzzles)}
    args.output.with_name('validation_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
