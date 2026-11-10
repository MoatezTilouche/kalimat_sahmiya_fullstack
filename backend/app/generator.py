"""Deterministic, validated arrowword grid packing with LEFT / DOWN arrows.

A clue uses a dedicated cell immediately before the first answer letter.
Each solution cell can belong to at most one horizontal and one vertical word.
"""
from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Sequence
from .arabic import valid_pair
from .difficulty import difficulty_for_level, LABELS

DIRECTIONS = {"left": (0, -1), "down": (1, 0)}


@dataclass(frozen=True)
class Entry:
    answer: str
    clue: str
    difficulty: str | None = None
    origin: str = 'starter'
    word_id: int | None = None


class Board:
    def __init__(self, size: int):
        self.size = size
        self.grid: list[list[str | None]] = [[None] * size for _ in range(size)]
        self.used: list[list[set[str]]] = [[set() for _ in range(size)] for _ in range(size)]
        self.words: list[dict] = []
        self.answer_set: set[str] = set()
        self.required_stops: set[tuple[int, int]] = set()

    def inside(self, row: int, col: int) -> bool:
        return 0 <= row < self.size and 0 <= col < self.size

    def try_candidate(self, answer: str, r: int, c: int, direction: str):
        dr, dc = DIRECTIONS[direction]
        qr, qc = r - dr, c - dc
        if not self.inside(qr, qc) or self.grid[qr][qc] is not None:
            return None
        after_r, after_c = r + dr * len(answer), c + dc * len(answer)
        if self.inside(after_r, after_c) and self.grid[after_r][after_c] not in (None, '#'):
            return None
        path, crossing = [], 0
        for i, ch in enumerate(answer):
            rr, cc = r + i * dr, c + i * dc
            if not self.inside(rr, cc):
                return None
            current = self.grid[rr][cc]
            if (current == '#' or (rr, cc) in self.required_stops
                    or (current is not None and current != ch) or direction in self.used[rr][cc]):
                return None
            if current is not None:
                crossing += 1
            else:
                # Prevent adjacent parallel answers from creating unintended runs.
                for nr, nc in ((rr + dc, cc + dr), (rr - dc, cc - dr)):
                    if self.inside(nr, nc) and self.grid[nr][nc] not in (None, '#'):
                        return None
            path.append([rr, cc])
        return [qr, qc], path, crossing

    def add(self, entry: Entry, clue_cell, path, direction: str):
        qr, qc = clue_cell
        self.grid[qr][qc] = '#'
        uid = f'w{len(self.words)}'
        for (r, c), ch in zip(path, entry.answer):
            self.grid[r][c] = ch
            self.used[r][c].add(direction)
        self.words.append({
            'id': uid, 'answer': entry.answer, 'clue': entry.clue,
            'direction': direction, 'clueCell': clue_cell, 'cells': path,
            'difficulty': entry.difficulty, 'source': entry.origin,
            'wordId': entry.word_id,
        })
        self.answer_set.add(entry.answer)
        dr, dc = DIRECTIONS[direction]
        end_r, end_c = path[-1][0] + dr, path[-1][1] + dc
        if self.inside(end_r, end_c):
            self.required_stops.add((end_r, end_c))

    def export(self, level: int, origin: str = 'generated') -> dict:
        clue_map = {tuple(w['clueCell']): w for w in self.words}
        cells = []
        for r in range(self.size):
            line = []
            for c in range(self.size):
                v = self.grid[r][c]
                if v == '#':
                    w = clue_map[(r, c)]
                    line.append({'type': 'clue', 'wordId': w['id'], 'text': w['clue'], 'direction': w['direction']})
                elif v is not None:
                    line.append({'type': 'letter', 'solution': v})
                else:
                    line.append({'type': 'block'})
            cells.append(line)
        return {'id': f'level_{level:04d}', 'level': level, 'size': self.size,
                'title': f'المستوى {level}', 'source': origin,
                'difficulty': difficulty_for_level(level),
                'difficultyLabel': LABELS[difficulty_for_level(level)],
                'generatorVersion': 2,
                'cells': cells, 'words': self.words}


def generate_puzzle(entries: Sequence[Entry], level: int = 1, size: int = 8,
                    attempts: int = 8, pool_size: int = 90, usage: dict[str, int] | None = None) -> dict:
    if not (6 <= size <= 12):
        raise ValueError('Grid size should be between 6 and 12')
    difficulty = difficulty_for_level(level)
    valid = list({e.answer: e for e in entries
                  if 2 <= len(e.answer) <= min(size - 1, 10)
                  and valid_pair(e.answer, e.clue)
                  and e.difficulty in (None, difficulty)}.values())
    if len(valid) < 8:
        raise ValueError(f'Insufficient {difficulty} vocabulary: need at least eight eligible unique answers')
    if not 1 <= attempts <= 30:
        raise ValueError('Attempts must be between 1 and 30')
    best, best_score = None, float('-inf')
    for trial in range(attempts):
        rand = random.Random(level * 1009 + size * 173 + trial * 7919)
        board = Board(size)
        candidates = rand.sample(valid, min(pool_size, len(valid)))
        vocabulary_priority = {e.answer: rand.random() * 6 for e in candidates}
        placed = 0
        while candidates and placed < size * 2:
            best_option = None
            # With each step, find the best feasible clue/answer placement.
            for entry in candidates:
                for direction, (dr, dc) in DIRECTIONS.items():
                    for qr in range(size):
                        for qc in range(size):
                            r, c = qr + dr, qc + dc
                            result = board.try_candidate(entry.answer, r, c, direction)
                            if result is None:
                                continue
                            clue_cell, path, crosses = result
                            # Prioritize crossings and cell coverage; prefer compact layouts.
                            dist = sum(abs(rr - (size - 1) / 2) + abs(cc - (size - 1) / 2)
                                       for rr, cc in path) / len(path)
                            score = (crosses * 12 + len(path) * .30 - dist * .16
                                     - len(entry.clue) * .025 + rand.random() * 3.5
                                     + vocabulary_priority[entry.answer]
                                     - (usage or {}).get(entry.answer, 0) * 1.8)
                            if not board.words:
                                score += len(path) * 0.4
                            elif crosses == 0:
                                score -= 6
                            if best_option is None or score > best_option[0]:
                                best_option = (score, entry, clue_cell, path, direction)
            if best_option is None:
                break
            # Prefer connected words; allow adding new groups only when needed.
            _, chosen, clue_cell, path, direction = best_option
            board.add(chosen, clue_cell, path, direction)
            candidates.remove(chosen)
            placed += 1
        covered = sum(v is not None for row in board.grid for v in row)
        score = len(board.words) * 7 + covered + sum(
            4 for row in board.used for used in row if len(used) == 2)
        if score > best_score:
            best, best_score = board, score
    if best is None or len(best.words) < 6:
        raise ValueError(f'Could not construct a sufficiently dense {difficulty} puzzle; add vocabulary or retry with a larger grid')
    puzzle = best.export(level)
    validate_puzzle(puzzle)
    return puzzle


def validate_puzzle(puzzle: dict) -> None:
    """Validate production puzzles even when Python runs with -O."""
    try:
        _validate(puzzle)
    except (AssertionError, KeyError, IndexError, TypeError, ValueError) as exc:
        raise ValueError(f'Invalid arrowword puzzle: {exc}') from exc


def require(condition, message='invalid grid'):
    if not condition:
        raise ValueError(message)


def _validate(puzzle: dict) -> None:
    size = puzzle['size']
    cells = puzzle['cells']
    require(6 <= size <= 12 and len(cells) == size and all(len(row) == size for row in cells))
    occupancy: dict[tuple[int, int, str], str] = {}
    clue_cells = set()
    answers, ids, letter_cells = set(), set(), set()
    for word in puzzle['words']:
        require(word['answer'] not in answers, 'duplicate answer')
        require(word['id'] not in ids, 'duplicate word id')
        answers.add(word['answer'])
        ids.add(word['id'])
        require(valid_pair(word['answer'], word['clue']), 'invalid word/clue')
        if word.get('difficulty'):
            require(word['difficulty'] == puzzle['difficulty'], 'wrong vocabulary difficulty')
        dr, dc = DIRECTIONS[word['direction']]
        cr, cc = word['clueCell']
        require(0 <= cr < size and 0 <= cc < size, 'clue out of bounds')
        require((cr, cc) not in clue_cells)
        clue_cells.add((cr, cc))
        require(cells[cr][cc]['type'] == 'clue')
        require(cells[cr][cc]['wordId'] == word['id'])
        require(cells[cr][cc]['text'] == word['clue'] and cells[cr][cc]['direction'] == word['direction'])
        require(len(word['answer']) == len(word['cells']))
        for i, ((r, c), char) in enumerate(zip(word['cells'], word['answer'])):
            require(0 <= r < size and 0 <= c < size, 'letter out of bounds')
            require((r, c) == (cr + dr * (i + 1), cc + dc * (i + 1)))
            require(cells[r][c]['type'] == 'letter' and cells[r][c]['solution'] == char, 'crossing mismatch')
            require((r, c, word['direction']) not in occupancy)
            occupancy[(r, c, word['direction'])] = word['id']
            letter_cells.add((r, c))
    for word in puzzle['words']:
        dr, dc = DIRECTIONS[word['direction']]
        r, c = word['cells'][-1]
        r, c = r + dr, c + dc
        if 0 <= r < size and 0 <= c < size:
            require(cells[r][c]['type'] != 'letter', 'unbounded answer')
    require(len(puzzle['words']) >= 1)
    for r, row in enumerate(cells):
        for c, cell in enumerate(row):
            require(cell['type'] in ('letter', 'clue', 'block'), 'unknown cell')
            require((cell['type'] != 'letter') or (r, c) in letter_cells, 'orphan letter')
            require((cell['type'] != 'clue') or (r, c) in clue_cells, 'orphan clue')
            if cell['type'] != 'letter':
                continue
            # Every adjacent pair of letters must belong to the same answer.
            for direction, (dr, dc) in DIRECTIONS.items():
                nr, nc = r + dr, c + dc
                if 0 <= nr < size and 0 <= nc < size and cells[nr][nc]['type'] == 'letter':
                    require(occupancy.get((r, c, direction)) is not None
                            and occupancy.get((r, c, direction)) == occupancy.get((nr, nc, direction)),
                            'unintended adjacent letter run')
