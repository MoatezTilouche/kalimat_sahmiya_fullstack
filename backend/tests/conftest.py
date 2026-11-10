import pytest
from app.db import setup


@pytest.fixture(autouse=True)
def isolated_dictionary(tmp_path, monkeypatch):
    """Tests never mutate the shipped dictionary."""
    path = tmp_path / 'words.db'
    monkeypatch.setenv('WORDS_DB', str(path))
    setup(path)
    return path
