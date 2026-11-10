import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kalimat_sahmiya/services/api_service.dart';
import 'package:kalimat_sahmiya/services/game_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  GameStore makeStore({http.Client? client}) => GameStore(
      factory: databaseFactoryFfi,
      databasePath: path,
      api: ApiService(
          client: client ??
              MockClient((_) async => throw http.ClientException('offline'))));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jawhar_store_');
    path = '${directory.path}/progress.db';
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
      'bundled progress, hints and rewards survive restart without duplicate rewards',
      () async {
    var store = makeStore();
    await store.init();
    expect(await store.hasSeenIntro, false);
    await store.markIntroSeen();
    final puzzle = await store.puzzleForLevel(1);
    final point = puzzle.words.first.cells.first;
    final letter = puzzle.words.first.answer[0];
    expect(await store.useHint(1, {}, {}, point.key, letter), 95);
    expect((await store.savedLevel(1)).hintsUsed, 1);
    await store.close();
    store = makeStore();
    await store.init();
    expect(await store.hasSeenIntro, true);
    expect(await store.coins, 95);
    expect((await store.savedLevel(1)).answers[point.key], letter);
    final answers = <String, String>{
      for (final w in puzzle.words)
        for (var i = 0; i < w.cells.length; i++) w.cells[i].key: w.answer[i]
    };
    final solved = puzzle.words.map((w) => w.id).toSet();
    final rewards = await Future.wait([
      store.saveLevel(1, answers, solved, completed: true),
      store.saveLevel(1, answers, solved, completed: true)
    ]);
    expect(rewards.where((r) => r).length, 1);
    expect(await store.coins, 155);
    expect(await store.unlockedLevel, 2);
    expect(await store.currentLevel, 2);
    await store.close();
    store = makeStore();
    await store.init();
    expect(await store.saveLevel(1, answers, solved, completed: true), false);
    expect(await store.coins, 155);
    expect(await store.hintsUsed, 1);
    await store.close();
  });

  test(
      'v1 migration preserves saved puzzle bytes, letters, coins, cache and intro',
      () async {
    final puzzles = jsonDecode(
            await rootBundle.loadString('assets/puzzles/starter_levels.json'))
        as List;
    final legacy = Map<String, dynamic>.from(puzzles[0] as Map)
      ..remove('difficulty');
    final serialized = jsonEncode(legacy);
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, v) async {
              await db.execute(
                  'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
              await db.execute(
                  "CREATE TABLE levels(level INTEGER PRIMARY KEY,puzzle_json TEXT NOT NULL,answers_json TEXT NOT NULL DEFAULT '{}',solved_json TEXT NOT NULL DEFAULT '[]',completed INTEGER NOT NULL DEFAULT 0,updated_at TEXT NOT NULL)");
              await db.execute(
                  'CREATE TABLE word_cache(id INTEGER PRIMARY KEY,answer TEXT NOT NULL,clue TEXT NOT NULL,length INTEGER NOT NULL)');
            }));
    await old.insert('settings', {'key': 'coins', 'value': '77'});
    await old.insert('settings', {'key': 'intro_shown', 'value': 'yes'});
    await old.insert('levels', {
      'level': 1,
      'puzzle_json': serialized,
      'answers_json': '{"1,1":"ق"}',
      'solved_json': '[]',
      'completed': 1,
      'updated_at': '2020-01-01'
    });
    await old.insert('word_cache',
        {'id': 500, 'answer': 'قمر', 'clue': 'تابع طبيعي للأرض', 'length': 3});
    await old.close();
    final store = makeStore();
    await store.init();
    expect((await store.puzzleForLevel(1)).isLegacy, true);
    expect((await store.savedLevel(1)).answers, {'1,1': 'ق'});
    expect((await store.savedLevel(1)).completed, true);
    expect(await store.coins, 77);
    expect(await store.cachedWordCount, 1);
    expect(await store.hasSeenIntro, true);
    await store.close();
    final db = await databaseFactoryFfi.openDatabase(path);
    expect((await db.query('levels')).first['puzzle_json'], serialized);
    await db.close();
  });

  test('downloaded puzzles coalesce and reopen offline with the same progress',
      () async {
    final puzzles = jsonDecode(
            await rootBundle.loadString('assets/puzzles/starter_levels.json'))
        as List;
    final payload = Map<String, dynamic>.from(puzzles[74] as Map)
      ..['level'] = 76
      ..['id'] = 'level_0076';
    var requests = 0;
    var store = makeStore(client: MockClient((_) async {
      requests++;
      return http.Response(jsonEncode(payload), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    await store.init();
    final downloaded =
        await Future.wait([store.puzzleForLevel(76), store.puzzleForLevel(76)]);
    expect(requests, 1);
    final word = downloaded.first.words.first;
    await store.saveLevel(76, {word.cells.first.key: word.answer[0]}, {});
    await store.close();
    store = makeStore();
    await store.init();
    expect((await store.puzzleForLevel(76)).id, 'level_0076');
    expect((await store.savedLevel(76)).answers[word.cells.first.key],
        word.answer[0]);
    expect((await store.puzzleForLevel(75)).level,
        75); // Hard bundle works without a request.
    await store.close();
  });

  test('word cache uses stable cursor and deduplicates simultaneous sync',
      () async {
    var requests = 0;
    final store = makeStore(client: MockClient((request) async {
      requests++;
      final offset = request.url.queryParameters['offset'];
      return http.Response(
          jsonEncode({
            'items': offset == '0'
                ? [
                    {
                      'id': 1,
                      'answer': 'قمر',
                      'clue': 'تابع طبيعي للأرض',
                      'length': 3,
                      'difficulty': 'easy',
                      'origin': 'starter'
                    },
                  ]
                : []
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    await store.init();
    await Future.wait([store.syncWords(), store.syncWords()]);
    expect(requests, 1);
    expect(await store.cachedWordCount, 1);
    expect(await store.syncWords(), 0);
    expect(await store.cachedWordCount, 1);
    await store.close();
  });
}
