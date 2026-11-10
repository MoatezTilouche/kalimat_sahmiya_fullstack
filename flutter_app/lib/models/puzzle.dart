import 'dart:convert';

enum GameDifficulty {
  easy('easy', 'سهل', 'بدايات جميلة', 1, 20),
  medium('medium', 'متوسط', 'آفاق أوسع', 21, 50),
  hard('hard', 'صعب', 'لأهل الفصاحة', 51, null);

  const GameDifficulty(
      this.code, this.label, this.subtitle, this.firstLevel, this.lastLevel);
  final String code;
  final String label;
  final String subtitle;
  final int firstLevel;
  final int? lastLevel;
  static GameDifficulty forLevel(int level) => level <= 20
      ? easy
      : level <= 50
          ? medium
          : hard;
  static GameDifficulty parse(String code) =>
      values.firstWhere((d) => d.code == code);
}

String arabicNumber(num number) => number.toString();

class GridPosition {
  const GridPosition(this.row, this.column);
  final int row;
  final int column;
  String get key => '$row,$column';
  factory GridPosition.fromJson(dynamic data) =>
      GridPosition((data as List)[0] as int, data[1] as int);
}

class PuzzleWord {
  const PuzzleWord(
      {required this.id,
      required this.answer,
      required this.clue,
      required this.direction,
      required this.clueCell,
      required this.cells,
      this.source,
      this.wordId,
      this.difficulty});
  final String id;
  final String answer;
  final String clue;
  final String direction;
  final GridPosition clueCell;
  final List<GridPosition> cells;
  final String? source;
  final int? wordId;
  final GameDifficulty? difficulty;
  factory PuzzleWord.fromJson(Map<String, dynamic> data) => PuzzleWord(
      id: data['id'] as String,
      answer: data['answer'] as String,
      clue: data['clue'] as String,
      direction: data['direction'] as String,
      source: data['source'] as String?,
      wordId: data['wordId'] as int?,
      difficulty: data['difficulty'] == null
          ? null
          : GameDifficulty.parse(data['difficulty'] as String),
      clueCell: GridPosition.fromJson(data['clueCell']),
      cells: (data['cells'] as List).map(GridPosition.fromJson).toList());
  Map<String, dynamic> toJson() => {
        'id': id,
        'answer': answer,
        'clue': clue,
        'direction': direction,
        if (source != null) 'source': source,
        if (wordId != null) 'wordId': wordId,
        if (difficulty != null) 'difficulty': difficulty!.code,
        'clueCell': [clueCell.row, clueCell.column],
        'cells': cells.map((p) => [p.row, p.column]).toList()
      };
}

class Puzzle {
  const Puzzle(
      {required this.id,
      required this.level,
      required this.size,
      required this.cells,
      required this.words,
      this.declaredDifficulty,
      this.source = 'saved',
      this.generatorVersion});
  final String id;
  final int level;
  final int size;
  final List<List<Map<String, dynamic>>> cells;
  final List<PuzzleWord> words;
  final GameDifficulty? declaredDifficulty;
  final String source;
  final int? generatorVersion;
  GameDifficulty get difficulty =>
      declaredDifficulty ?? GameDifficulty.forLevel(level);
  // Legacy puzzles are kept exactly as saved; the tag only describes their level band.
  bool get isLegacy => declaredDifficulty == null;

  factory Puzzle.fromJson(Map<String, dynamic> data) {
    final puzzle = Puzzle(
        id: data['id'] as String,
        level: data['level'] as int,
        size: data['size'] as int,
        source: data['source'] as String? ?? 'saved',
        generatorVersion: data['generatorVersion'] as int?,
        declaredDifficulty: data['difficulty'] == null
            ? null
            : GameDifficulty.parse(data['difficulty'] as String),
        cells: (data['cells'] as List)
            .map((row) => (row as List)
                .map((cell) => Map<String, dynamic>.from(cell as Map))
                .toList())
            .toList(),
        words: (data['words'] as List)
            .map(
                (w) => PuzzleWord.fromJson(Map<String, dynamic>.from(w as Map)))
            .toList());
    puzzle.validate();
    return puzzle;
  }
  factory Puzzle.fromString(String data) =>
      Puzzle.fromJson(jsonDecode(data) as Map<String, dynamic>);
  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'size': size,
        if (declaredDifficulty != null) 'difficulty': declaredDifficulty!.code,
        'source': source,
        if (generatorVersion != null) 'generatorVersion': generatorVersion,
        'cells': cells,
        'words': words.map((w) => w.toJson()).toList()
      };

  void validate() {
    void check(bool ok) {
      if (!ok) throw const FormatException('بيانات اللغز غير صالحة');
    }

    check(level > 0 && size >= 6 && size <= 12 && words.isNotEmpty);
    check(cells.length == size && cells.every((row) => row.length == size));
    final ids = <String>{};
    final answers = <String>{};
    final occupancy = <String>{};
    for (final word in words) {
      check(ids.add(word.id) && answers.add(word.answer));
      check(word.answer.length >= 2 &&
          word.answer.length <= 10 &&
          word.clue.trim().isNotEmpty);
      check(word.difficulty == null ||
          declaredDifficulty == null ||
          word.difficulty == declaredDifficulty);
      check(word.direction == 'left' || word.direction == 'down');
      check(word.answer.length == word.cells.length);
      final q = word.clueCell;
      check(q.row >= 0 && q.row < size && q.column >= 0 && q.column < size);
      check(cells[q.row][q.column]['type'] == 'clue' &&
          cells[q.row][q.column]['wordId'] == word.id);
      for (var i = 0; i < word.cells.length; i++) {
        final p = word.cells[i];
        check(p.row >= 0 && p.row < size && p.column >= 0 && p.column < size);
        check(p.row == q.row + (word.direction == 'down' ? i + 1 : 0));
        check(p.column == q.column - (word.direction == 'left' ? i + 1 : 0));
        check(cells[p.row][p.column]['type'] == 'letter' &&
            cells[p.row][p.column]['solution'] == word.answer[i]);
        check(occupancy.add('${p.key}:${word.direction}'));
      }
    }
  }
}

class LevelSave {
  const LevelSave(
      {required this.answers,
      required this.solved,
      required this.completed,
      this.hintsUsed = 0});
  final Map<String, String> answers;
  final Set<String> solved;
  final bool completed;
  final int hintsUsed;
}
