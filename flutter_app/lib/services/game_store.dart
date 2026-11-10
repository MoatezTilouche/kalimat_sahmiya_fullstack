import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/puzzle.dart';
import 'api_service.dart';
import 'learning_store.dart';

class GameStore {
  // Public parameter names keep constructor injection compatible with Dart 3.6.
  // Tests pass factory: explicitly; device builds use sqflite's databaseFactory.
  GameStore(
      {ApiService? api,
      DatabaseFactory? factory,
      String? databasePath,
      AssetBundle? bundle})
      : api = api ?? ApiService(),
        _factory = factory,
        _path = databasePath,
        _bundle = bundle ?? rootBundle;
  static final GameStore instance = GameStore();
  final ApiService api;
  late final learning = LearningStore(api: api);
  final DatabaseFactory? _factory;
  final String? _path;
  final AssetBundle _bundle;
  late Database _db;
  Future<void>? _opening;
  bool _closed = false;
  Map<int, Puzzle>? _starter;
  final Map<int, Future<Puzzle>> _pendingLevels = {};
  Future<int>? _syncing;
  Future<void> _writes = Future.value();

  Future<void> init() => _opening ??= _open().catchError((Object error) {
        _opening = null;
        throw error;
      });
  Future<void> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ??
        p.join(await factory.getDatabasesPath(), 'jawhar_arrowwords.db');
    _db = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, version) async {
              await db.execute(
                  'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
              await db.execute(
                  '''CREATE TABLE levels (level INTEGER PRIMARY KEY, puzzle_json TEXT NOT NULL,
          answers_json TEXT NOT NULL DEFAULT '{}', solved_json TEXT NOT NULL DEFAULT '[]',
          completed INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL, hints_used INTEGER NOT NULL DEFAULT 0)''');
              await db.execute(
                  '''CREATE TABLE word_cache (id INTEGER PRIMARY KEY, answer TEXT NOT NULL,
          clue TEXT NOT NULL, length INTEGER NOT NULL, difficulty TEXT, origin TEXT)''');
              await LearningStore.migrate(db);
            },
            onUpgrade: (db, old, version) async {
              if (old < 2) {
                await db.execute(
                    'ALTER TABLE levels ADD COLUMN hints_used INTEGER NOT NULL DEFAULT 0');
                await db.execute(
                    'ALTER TABLE word_cache ADD COLUMN difficulty TEXT');
                await db
                    .execute('ALTER TABLE word_cache ADD COLUMN origin TEXT');
              }
              if (old < 3) await LearningStore.migrate(db);
            }));
    await learning.attach(_db);
    await learning.loadLibrary(_bundle);
  }

  Future<String?> _setting(String key) async {
    final rows = await _db.query('settings',
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _set(String key, String value) => _db
      .insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<bool> get hasSeenIntro async => await _setting('intro_shown') == 'yes';
  Future<void> markIntroSeen() => _set('intro_shown', 'yes');
  Future<int> get coins async =>
      int.tryParse(await _setting('coins') ?? '') ?? 120;
  Future<void> setCoins(int value) => _set('coins', '${value < 0 ? 0 : value}');
  Future<Set<int>> get completedLevels async =>
      (await _db.query('levels', columns: ['level'], where: 'completed = 1'))
          .map((r) => r['level'] as int)
          .toSet();
  Future<int> get unlockedLevel async {
    final completed = await completedLevels;
    return completed.isEmpty
        ? 1
        : completed.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<int> get currentLevel async =>
      (int.tryParse(await _setting('current_level') ?? '') ??
              await unlockedLevel)
          .clamp(1, await unlockedLevel);
  Future<int> get completedCount async => (await completedLevels).length;
  Future<int> get hintsUsed async => (await _db
          .rawQuery('SELECT COALESCE(SUM(hints_used),0) AS n FROM levels'))
      .first['n'] as int;

  Future<Map<int, Puzzle>> _bundled() async {
    if (_starter != null) return _starter!;
    final data = jsonDecode(
        await _bundle.loadString('assets/puzzles/starter_levels.json')) as List;
    return _starter = {
      for (final item in data)
        (item as Map)['level'] as int:
            Puzzle.fromJson(Map<String, dynamic>.from(item))
    };
  }

  Future<Puzzle> puzzleForLevel(int level) =>
      _pendingLevels.putIfAbsent(level, () async {
        try {
          final saved = await _db.query('levels',
              where: 'level = ?', whereArgs: [level], limit: 1);
          if (saved.isNotEmpty) {
            return Puzzle.fromString(saved.first['puzzle_json'] as String);
          }
          final puzzle =
              (await _bundled())[level] ?? await api.fetchPuzzle(level);
          await _db.insert(
              'levels',
              {
                'level': level,
                'puzzle_json': jsonEncode(puzzle.toJson()),
                'answers_json': '{}',
                'solved_json': '[]',
                'completed': 0,
                'updated_at': DateTime.now().toIso8601String()
              },
              conflictAlgorithm: ConflictAlgorithm.ignore);
          // Return the canonical saved version if another caller inserted first.
          final canonical =
              await _db.query('levels', where: 'level = ?', whereArgs: [level]);
          return Puzzle.fromString(canonical.first['puzzle_json'] as String);
        } finally {
          _pendingLevels.remove(level);
        }
      });

  Future<void> resumeAt(int level) => _set('current_level', '$level');
  Future<LevelSave> savedLevel(int level) async {
    final rows = await _db.query('levels',
        where: 'level = ?', whereArgs: [level], limit: 1);
    if (rows.isEmpty) {
      return const LevelSave(answers: {}, solved: {}, completed: false);
    }
    final row = rows.first;
    return LevelSave(
        answers: (jsonDecode(row['answers_json'] as String) as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        solved: (jsonDecode(row['solved_json'] as String) as List)
            .map((e) => e.toString())
            .toSet(),
        completed: row['completed'] == 1,
        hintsUsed: row['hints_used'] as int);
  }

  Future<T> _queue<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<bool> saveLevel(
      int level, Map<String, String> answers, Set<String> solved,
      {bool completed = false}) {
    final answerJson = jsonEncode(Map<String, String>.of(answers));
    final solvedJson = jsonEncode(solved.toList());
    return _queue(() => _db.transaction((txn) async {
          final rows = await txn.query('levels',
              where: 'level = ?', whereArgs: [level], limit: 1);
          if (rows.isEmpty) {
            throw StateError('Level must be cached before saving');
          }
          final wasCompleted = rows.first['completed'] == 1;
          await txn.update(
              'levels',
              {
                'answers_json': answerJson,
                'solved_json': solvedJson,
                'completed': wasCompleted || completed ? 1 : 0,
                'updated_at': DateTime.now().toIso8601String()
              },
              where: 'level = ?',
              whereArgs: [level]);
          if (completed && !wasCompleted) {
            final coinRows = await txn
                .query('settings', where: 'key = ?', whereArgs: ['coins']);
            final balance = coinRows.isEmpty
                ? 120
                : int.parse(coinRows.first['value'] as String);
            await txn.insert(
                'settings', {'key': 'coins', 'value': '${balance + 60}'},
                conflictAlgorithm: ConflictAlgorithm.replace);
            await txn.insert(
                'settings', {'key': 'current_level', 'value': '${level + 1}'},
                conflictAlgorithm: ConflictAlgorithm.replace);
            return true;
          }
          return false;
        }));
  }

  // Debit, hint count and revealed letter commit together, including across crashes.
  Future<int?> useHint(int level, Map<String, String> answers,
      Set<String> solved, String cell, String letter) {
    final updated = Map<String, String>.of(answers)..[cell] = letter;
    final solvedJson = jsonEncode(solved.toList());
    return _queue(() => _db.transaction((txn) async {
          final rows = await txn
              .query('settings', where: 'key = ?', whereArgs: ['coins']);
          final balance =
              rows.isEmpty ? 120 : int.parse(rows.first['value'] as String);
          if (balance < 25) return null;
          final levels =
              await txn.query('levels', where: 'level = ?', whereArgs: [level]);
          if (levels.isEmpty || levels.first['completed'] == 1) return null;
          await txn.insert(
              'settings', {'key': 'coins', 'value': '${balance - 25}'},
              conflictAlgorithm: ConflictAlgorithm.replace);
          await txn.rawUpdate(
              '''UPDATE levels SET answers_json=?,solved_json=?,hints_used=hints_used+1,
        updated_at=? WHERE level=?''',
              [
                jsonEncode(updated),
                solvedJson,
                DateTime.now().toIso8601String(),
                level
              ]);
          return balance - 25;
        }));
  }

  Future<int> syncWords({GameDifficulty? difficulty}) =>
      _syncing ??= _syncWords(difficulty).whenComplete(() => _syncing = null);
  Future<int> _syncWords(GameDifficulty? difficulty) async {
    final key = 'word_cursor_${difficulty?.code ?? 'all'}';
    final offset = int.tryParse(await _setting(key) ?? '') ?? 0;
    final items = await api.fetchWords(
        limit: 300, offset: offset, difficulty: difficulty);
    await _db.transaction((txn) async {
      for (final item in items) {
        await txn.insert(
            'word_cache',
            {
              for (final field in [
                'id',
                'answer',
                'clue',
                'length',
                'difficulty',
                'origin'
              ])
                field: item[field]
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert(
          'settings', {'key': key, 'value': '${offset + items.length}'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return items.length;
  }

  Future<int> get cachedWordCount async =>
      (await _db.rawQuery('SELECT COUNT(*) AS n FROM word_cache')).first['n']
          as int;
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _writes;
    await learning.flush();
    await _db.close();
    api.close();
  }
}
