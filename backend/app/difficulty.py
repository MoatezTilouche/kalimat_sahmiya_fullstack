"""Explainable classification: measured corpus ranks, or clearly marked heuristics."""
from dataclasses import dataclass, asdict
from pathlib import Path
import csv
import io
import zipfile
from .arabic import normalize_answer
from .curated import MEDIUM, HARD
from .seed_data import PAIRS

LABELS = {'easy': 'سهل', 'medium': 'متوسط', 'hard': 'صعب'}
CURATED = {normalize_answer(a): 'easy' for a, _ in PAIRS}
CURATED.update({a: 'medium' for a, _ in MEDIUM})
CURATED.update({a: 'hard' for a, _ in HARD})
SPECIALIZED = ('كيمياء', 'فيزياء', 'تشريح', 'رياضي', 'فلسف', 'بلاغ', 'طبي', 'خلوي', 'جزيء', 'عضوي', 'وراث', 'لاهوت', 'جيولوج')
LITERARY = ('اللغة القديمة', 'أدبي', 'الشعر', 'الفصيحة', 'قديم الاستعمال')


def difficulty_for_level(level: int) -> str:
    if level < 1:
        raise ValueError('Level must be positive')
    return 'easy' if level <= 20 else 'medium' if level <= 50 else 'hard'


def size_for_level(level: int) -> int:
    return {'easy': 8, 'medium': 9, 'hard': 10}[difficulty_for_level(level)]


@dataclass(frozen=True)
class Classification:
    difficulty: str
    difficulty_score: float
    classification_method: str
    frequency_rank: int | None = None
    frequency_count: int | None = None
    frequency_source: str | None = None

    def metadata(self):
        return asdict(self)


def load_frequencies(path: Path, answers: set[str] | None = None) -> dict[str, tuple[int, int]]:
    """Read CAMeL word<TAB>count (descending count); retain only requested words.

    Ranking is the actual row position in the supplied corpus, never a guessed rank.
    No affix stripping or hamza folding is used to invent a match.
    """
    def read(stream):
        result = {}
        previous = float('inf')
        rank = 0
        for row in csv.reader(stream, delimiter='\t'):
            if len(row) < 2:
                continue
            try:
                count = int(row[1])
            except ValueError:
                if rank:
                    raise ValueError('Malformed frequency count')
                continue  # optional header
            if count < 0 or count > previous:
                raise ValueError('Frequency list must be sorted by descending count')
            previous = count
            rank += 1
            word = normalize_answer(row[0])
            if (answers is None or word in answers) and word not in result:
                result[word] = (rank, count)
        if not rank:
            raise ValueError('Frequency file has no valid records')
        return result
    if not path.is_file():
        raise FileNotFoundError(f'Frequency file not found: {path}')
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as archive:
            names = [n for n in archive.namelist() if n.endswith('.tsv') and not n.startswith('__MACOSX')]
            if len(names) != 1:
                raise ValueError('Expected one TSV in frequency archive')
            with archive.open(names[0]) as raw:
                return read(io.TextIOWrapper(raw, encoding='utf-8-sig'))
    with path.open(encoding='utf-8-sig') as stream:
        return read(stream)


def classify(answer: str, clue: str, frequency: tuple[int, int] | None = None,
             frequency_source: str | None = None) -> Classification:
    tokens = clue.split()
    complexity = min(.9, max(0, len(answer) - 4) * .12)
    complexity += min(.7, max(0, len(tokens) - 8) * .055)
    complexity += .2 if clue.count(' أو ') >= 2 else 0
    specialty = any(term in clue for term in SPECIALIZED)
    literary = any(term in clue for term in LITERARY)
    if frequency:
        rank, count = frequency
        base = .4 if rank <= 3000 else 1.4 if rank <= 30000 else 2.5
        method = 'corpus-rank-v1'
    else:
        rank = count = None
        base = 1.45  # unknown familiarity is medium, not assumed rare
        method = 'fallback-heuristic-v1'
    score = base + complexity + (1.1 if specialty else 0) + (.7 if literary else 0)
    difficulty = 'easy' if score < 1.3 else 'medium' if score < 2.5 else 'hard'
    if answer in CURATED:
        difficulty = CURATED[answer]
        score = {'easy': .5, 'medium': 1.7, 'hard': 2.9}[difficulty]
        method += '+reviewed-familiarity'
    return Classification(difficulty, round(score, 3), method, rank, count,
                          frequency_source if frequency else None)
