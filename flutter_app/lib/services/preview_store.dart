import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/puzzle.dart';
import 'game_store.dart';

/// Temporary browser preview for development. Phone builds keep SQLite.
/// Nothing here survives a full browser reload or hot restart.
class PreviewStore extends GameStore {
  PreviewStore({super.api});
  final _puzzles = <int, Puzzle>{};
  final _saves = <int, LevelSave>{};
  final _words = <int, Map<String, dynamic>>{};
  var _introSeen = false;
  var _coins = 120;
  var _current = 1;

  @override
  Future<void> init() async {
    await learning.loadLibrary(rootBundle);
    final bundled = jsonDecode(
            await rootBundle.loadString('assets/puzzles/starter_levels.json'))
        as List;
    for (final item in bundled) {
      final puzzle = Puzzle.fromJson(Map<String, dynamic>.from(item as Map));
      _puzzles[puzzle.level] = puzzle;
    }
  }

  @override
  Future<bool> get hasSeenIntro async => _introSeen;
  @override
  Future<void> markIntroSeen() async {
    _introSeen = true;
  }

  @override
  Future<int> get coins async => _coins;
  @override
  Future<void> setCoins(int value) async {
    _coins = value < 0 ? 0 : value;
  }

  @override
  Future<Set<int>> get completedLevels async =>
      _saves.entries.where((e) => e.value.completed).map((e) => e.key).toSet();
  @override
  Future<int> get unlockedLevel async {
    final done = await completedLevels;
    return done.isEmpty ? 1 : done.reduce((a, b) => a > b ? a : b) + 1;
  }

  @override
  Future<int> get currentLevel async => _current.clamp(1, await unlockedLevel);
  @override
  Future<void> resumeAt(int level) async {
    _current = level;
  }

  @override
  Future<int> get completedCount async => (await completedLevels).length;
  @override
  Future<int> get hintsUsed async =>
      _saves.values.fold<int>(0, (sum, save) => sum + save.hintsUsed);
  @override
  Future<Puzzle> puzzleForLevel(int level) async =>
      _puzzles[level] ??= await api.fetchPuzzle(level);
  @override
  Future<LevelSave> savedLevel(int level) async {
    final save = _saves[level];
    return LevelSave(
        answers: Map.of(save?.answers ?? {}),
        solved: Set.of(save?.solved ?? {}),
        completed: save?.completed ?? false,
        hintsUsed: save?.hintsUsed ?? 0);
  }

  @override
  Future<bool> saveLevel(
      int level, Map<String, String> answers, Set<String> solved,
      {bool completed = false}) async {
    final old = _saves[level];
    _saves[level] = LevelSave(
        answers: Map.of(answers),
        solved: Set.of(solved),
        completed: completed || (old?.completed ?? false),
        hintsUsed: old?.hintsUsed ?? 0);
    final reward = completed && !(old?.completed ?? false);
    if (reward) {
      _coins += 60;
      _current = level + 1;
    }
    return reward;
  }

  @override
  Future<int?> useHint(int level, Map<String, String> answers,
      Set<String> solved, String cell, String letter) async {
    final old = _saves[level];
    if (_coins < 25 || (old?.completed ?? false)) return null;
    _coins -= 25;
    _saves[level] = LevelSave(
        answers: {...answers, cell: letter},
        solved: Set.of(solved),
        completed: false,
        hintsUsed: (old?.hintsUsed ?? 0) + 1);
    return _coins;
  }

  @override
  Future<int> syncWords({GameDifficulty? difficulty}) async {
    final items = await api.fetchWords(difficulty: difficulty);
    for (final item in items) {
      _words[item['id'] as int] = item;
    }
    return items.length;
  }

  @override
  Future<int> get cachedWordCount async => _words.length;
  @override
  Future<void> close() async {
    await learning.flush();
    api.close();
  }
}
