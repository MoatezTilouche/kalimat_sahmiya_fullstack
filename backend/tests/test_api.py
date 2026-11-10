from fastapi.testclient import TestClient
from app.main import app
from app.generator import validate_puzzle


def test_endpoints():
    with TestClient(app) as client:
        health = client.get('/api/health')
        assert health.status_code == 200
        assert health.json()['words'] > 150
        words = client.get('/api/words?length=3&limit=10')
        assert words.status_code == 200
        assert 0 < len(words.json()['items']) <= 10
        assert all(it['length'] == 3 for it in words.json()['items'])
        puzzle = client.get('/api/puzzles/generate?level=5&size=8')
        assert puzzle.status_code == 200
        assert puzzle.json()['level'] == 5
        validate_puzzle(puzzle.json())
        assert len(puzzle.json()['words']) >= 3


def test_deterministic():
    with TestClient(app) as client:
        a = client.get('/api/puzzles/generate?level=2').json()
        b = client.get('/api/puzzles/generate?level=2').json()
        assert a == b


def test_packaged_levels_have_valid_arrows():
    import json
    from pathlib import Path
    filename = Path(__file__).resolve().parents[2] / 'flutter_app/assets/puzzles/starter_levels.json'
    puzzles = json.loads(filename.read_text(encoding='utf-8'))
    assert len(puzzles) >= 51
    for i, puzzle in enumerate(puzzles, start=1):
        assert puzzle['level'] == i
        assert len(puzzle['words']) >= 6
        validate_puzzle(puzzle)
        from app.difficulty import difficulty_for_level
        assert puzzle['difficulty'] == difficulty_for_level(i)
        assert all(w['difficulty'] == puzzle['difficulty'] for w in puzzle['words'])
