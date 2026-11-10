import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat_sahmiya/models/puzzle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('75 shipped levels contain valid Arabic arrowword paths and difficulty',
      () async {
    final json = jsonDecode(
            await rootBundle.loadString('assets/puzzles/starter_levels.json'))
        as List;
    expect(json.length, 75);
    for (var index = 0; index < json.length; index++) {
      final puzzle =
          Puzzle.fromJson(Map<String, dynamic>.from(json[index] as Map));
      expect(puzzle.level, index + 1);
      expect(puzzle.words.length, greaterThanOrEqualTo(6));
      expect(puzzle.difficulty, GameDifficulty.forLevel(index + 1));
      expect(puzzle.cells.length, puzzle.size);
      for (final word in puzzle.words) {
        expect(word.answer.split('').length, word.cells.length);
        final dr = word.direction == 'down' ? 1 : 0;
        final dc = word.direction == 'left' ? -1 : 0;
        expect(puzzle.cells[word.clueCell.row][word.clueCell.column]['type'],
            'clue');
        for (var i = 0; i < word.cells.length; i++) {
          final point = word.cells[i];
          expect(point.row, word.clueCell.row + dr * (i + 1));
          expect(point.column, word.clueCell.column + dc * (i + 1));
          expect(puzzle.cells[point.row][point.column]['solution'],
              word.answer[i]);
        }
      }
    }
  });
  test('difficulty boundaries and Arabic labels', () {
    for (final entry in {
      1: GameDifficulty.easy,
      20: GameDifficulty.easy,
      21: GameDifficulty.medium,
      50: GameDifficulty.medium,
      51: GameDifficulty.hard,
      75: GameDifficulty.hard
    }.entries) {
      expect(GameDifficulty.forLevel(entry.key), entry.value);
    }
    expect(GameDifficulty.values.map((d) => d.label), ['سهل', 'متوسط', 'صعب']);
    expect(arabicNumber(123), '123');
  });
}
