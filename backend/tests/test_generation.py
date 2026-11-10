from copy import deepcopy
import pytest
from fastapi.testclient import TestClient
from app.db import all_entries, connect
from app.difficulty import difficulty_for_level, size_for_level
from app.generator import generate_puzzle, validate_puzzle
from app.main import app


@pytest.mark.parametrize('level', [10,20,21,35,50,51,75])
def test_category_and_determinism(level):
    difficulty = difficulty_for_level(level)
    size = size_for_level(level)
    entries = all_entries(size, difficulty=difficulty, level=level)
    a = generate_puzzle(entries, level=level, size=size, attempts=2)
    b = generate_puzzle(entries, level=level, size=size, attempts=2)
    assert a == b
    validate_puzzle(a)
    assert len(a['words']) >= 6
    assert all(w['difficulty'] == difficulty for w in a['words'])
    bad = deepcopy(a)
    r,c = bad['words'][0]['cells'][0]
    bad['cells'][r][c]['solution'] = '!'
    with pytest.raises(ValueError):
        validate_puzzle(bad)


def test_endpoints_filtering_and_validation():
    with TestClient(app) as client:
        for level, difficulty in [(10,'easy'),(35,'medium'),(75,'hard')]:
            words = client.get(f'/api/words?difficulty={difficulty}&limit=100').json()['items']
            assert words and all(w['difficulty'] == difficulty for w in words)
            response = client.get(f'/api/puzzles/generate?level={level}')
            assert response.status_code == 200
            assert response.json()['difficulty'] == difficulty
        for query in ['difficulty=invalid', 'limit=0', 'length=1']:
            assert client.get('/api/words?' + query).status_code == 422
        assert client.get('/api/puzzles/generate?level=0').status_code == 422
        assert set(client.get('/api/health').json()['difficultyCounts']) == {'easy','medium','hard'}


def test_insufficient_hard_vocabulary_has_no_easy_fallback():
    with TestClient(app) as client:
        with connect() as db:
            db.execute("UPDATE words SET eligible=0 WHERE difficulty='hard'")
        response = client.get('/api/puzzles/generate?level=76')
        assert response.status_code == 422
        assert response.json()['detail']['difficulty'] == 'hard'
