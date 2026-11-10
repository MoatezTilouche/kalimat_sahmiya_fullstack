from contextlib import asynccontextmanager
from functools import lru_cache
from typing import Literal
from fastapi import FastAPI, HTTPException, Query, Path
from fastapi.middleware.cors import CORSMiddleware
from .db import all_entries, connect, counts, fetch_pairs, setup, SCHEMA_VERSION
from .difficulty import difficulty_for_level, size_for_level, LABELS
from .generator import generate_puzzle
from . import knowledge as education


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup()
    yield


app = FastAPI(title='كلمات سهمية | Arabic Arrowwords API', version='2.0.0', lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_credentials=False,
                   allow_methods=['GET'], allow_headers=['*'])


@app.get('/api/health')
def health():
    vocabulary = counts()
    with connect() as db:
        sources = [dict(r) for r in db.execute('SELECT origin,COUNT(*) AS pairs FROM words WHERE eligible=1 GROUP BY origin')]
        measured = db.execute('SELECT COUNT(*) FROM words WHERE frequency_rank IS NOT NULL AND eligible=1').fetchone()[0]
    return {'ok': True, 'words': sum(v['pairs'] for v in vocabulary.values()),
            'difficultyCounts': vocabulary, 'sources': sources, 'measuredFrequencyPairs': measured,
            'schemaVersion': SCHEMA_VERSION,
            'classification': 'corpus ranks with reviewed familiarity; documented heuristic for unmatched words'}


@app.get('/api/words')
def words(limit: int = Query(100, ge=1, le=500), offset: int = Query(0, ge=0),
          length: int | None = Query(None, ge=2, le=10), seed: int = Query(1, ge=0),
          difficulty: Literal['easy', 'medium', 'hard'] | None = None):
    items = fetch_pairs(limit=limit, offset=offset, length=length, seed=seed, difficulty=difficulty)
    return {'items': items, 'limit': limit, 'offset': offset,
            'nextOffset': offset + len(items), 'difficulty': difficulty,
            'difficultyLabel': LABELS.get(difficulty), 'pagination': 'stable-id'}


Category = Literal['language', 'history', 'geography', 'science', 'literature',
                   'civilizations', 'nature', 'culture', 'inventions']
Difficulty = Literal['easy', 'medium', 'hard']


@app.get('/api/knowledge/categories')
def knowledge_categories():
    return {'items': education.categories()}


@app.get('/api/knowledge/random')
def random_knowledge(difficulty: Difficulty | None = None):
    items = education.list_cards(difficulty=difficulty, random_one=True)
    if not items:
        raise HTTPException(404, 'لا تتوفر بطاقة معرفة بهذه الصعوبة بعد.')
    return items[0]


@app.get('/api/knowledge')
def knowledge_list(category: Category | None = None, difficulty: Difficulty | None = None,
                   limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0)):
    items = education.list_cards(category, difficulty, limit, offset)
    return {'items': items, 'nextOffset': offset + len(items)}


@app.get('/api/knowledge/{word_id}/quiz')
def knowledge_quiz(word_id: int = Path(ge=1)):
    if not education.get_card(word_id):
        raise HTTPException(404, 'لم نجد هذه الكلمة في المعجم.')
    result = education.quiz(word_id)
    if result is None:
        raise HTTPException(404, 'لا يتوفر اختبار موثوق لهذه الكلمة. يمكنك قراءة تعريفها.')
    return result


@app.get('/api/knowledge/{word_id}')
def knowledge_card(word_id: int = Path(ge=1)):
    result = education.get_card(word_id)
    if result is None:
        raise HTTPException(404, 'لم نجد هذه الكلمة في المعجم.')
    return result


@lru_cache(maxsize=128)
def cached_puzzle(level, size, signature, database):
    difficulty = difficulty_for_level(level)
    candidates = all_entries(size, difficulty=difficulty, level=level)
    return generate_puzzle(candidates, level=level, size=size, attempts=5, pool_size=100)


@app.get('/api/puzzles/generate')
def puzzle(level: int = Query(1, ge=1, le=999999), size: int | None = Query(None, ge=6, le=12)):
    with connect() as db:
        signature = tuple(db.execute('SELECT COUNT(*),MAX(id),SUM(difficulty_score),SUM(eligible) FROM words').fetchone())
        database = db.execute('PRAGMA database_list').fetchone()[2]
    try:
        return cached_puzzle(level, size or size_for_level(level), signature, database)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail={
            'message': 'لا تتوفر كلمات كافية لهذا التحدي. يرجى تحديث القاموس.',
            'difficulty': difficulty_for_level(level), 'reason': str(exc)}) from exc
