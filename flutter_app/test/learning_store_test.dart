import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kalimat_sahmiya/models/learning.dart';
import 'package:kalimat_sahmiya/models/puzzle.dart';
import 'package:kalimat_sahmiya/services/api_service.dart';
import 'package:kalimat_sahmiya/services/game_store.dart';
import 'package:kalimat_sahmiya/services/learning_store.dart';
import 'package:kalimat_sahmiya/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  ApiService offline() => ApiService(
      client: MockClient((_) async => throw http.ClientException('offline')));
  late Puzzle puzzle;
  setUp(() async {
    final data = jsonDecode(
            await rootBundle.loadString('assets/puzzles/starter_levels.json'))
        as List;
    puzzle = Puzzle.fromJson(Map<String, dynamic>.from(data.first as Map));
  });
  test(
      'dictionary, cards, favorites, review events and comfort settings survive SQLite restart',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('learning_persistence_');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/progress.db';
    GameStore create() => GameStore(
        factory: databaseFactoryFfi, databasePath: path, api: offline());
    var store = create();
    await store.init();
    final before = await store.puzzleForLevel(1);
    final word = before.words.first,
        key = wordKey(before.words.first.answer, before.words.first.clue);
    await store.saveLevel(1, {word.cells.first.key: word.answer[0]}, {});
    await store.setCoins(77);
    await store.markIntroSeen();
    await store.learning.encounterPuzzle(before);
    await store.learning.encounterPuzzle(before);
    expect(store.learning.word(key)!.encounters, 1);
    await store.learning.activity(word, 1, 'solved');
    await store.learning.activity(word, 1, 'solved');
    expect(store.learning.word(key)!.correct, 1);
    await store.learning.favorite(key);
    final card = await store.learning.cardFor(store.learning.word(key)!);
    expect(card.definition, word.clue);
    await store.learning.review(key, true, 'session-1');
    await store.learning.review(key, true, 'session-1');
    await store.learning.quizResult('quiz-1', key, true);
    expect(await store.learning.quizResult('quiz-1', key, true), false);
    await store.learning.finishSession('session-1');
    await store.learning.finishSession('session-1');
    await store.learning.setPreference('font_scale', '1.4');
    await store.learning.setPreference('focus_mode', 'true');
    await store.learning.setPreference('reduced_motion', 'true');
    await store.learning.setPreference('session_size', '10');
    final next = store.learning.schedule(key)!.nextReview;
    await store.close();
    store = create();
    await store.init();
    expect(store.learning.discovered, before.words.length);
    expect(store.learning.word(key)!.favorite, true);
    expect(
        store.learning.word(key)!.correct, 3); // solve, review, optional quiz
    expect(store.learning.reviewCount, 1);
    expect(store.learning.quizCount, 1);
    expect(store.learning.sessions, 1);
    expect(store.learning.accuracy, 1);
    expect(store.learning.schedule(key)!.nextReview, next);
    expect(store.learning.fontScale, 1.4);
    expect(store.learning.focusMode, true);
    expect(store.learning.reducedMotion, true);
    expect(store.learning.sessionSize, 10);
    expect((await store.learning.cardFor(store.learning.word(key)!)).definition,
        word.clue);
    expect(await store.coins, 77);
    expect(await store.hasSeenIntro, true);
    expect((await store.savedLevel(1)).answers[word.cells.first.key],
        word.answer[0]);
    expect((await store.puzzleForLevel(1)).toJson(), before.toJson());
    await store.close();
  });
  test(
      'spaced repetition is deterministic, idempotent, and shortens after a miss',
      () async {
    var now = DateTime.utc(2026, 1, 1);
    final store = LearningStore(api: offline(), clock: () => now);
    await store.encounterPuzzle(puzzle);
    final word = puzzle.words.first;
    final key = wordKey(word.answer, word.clue);
    expect(store.dueWords, isNotEmpty);
    for (var i = 0; i < 6; i++) {
      await store.review(key, true, 'review-$i');
      final days = [1, 3, 7, 14, 30, 30][i];
      expect(store.schedule(key)!.interval, days);
      expect(store.schedule(key)!.nextReview, now.add(Duration(days: days)));
      expect(store.dueWords.any((w) => w.key == key), false);
      now = now.add(Duration(days: days));
      expect(store.dueWords.any((w) => w.key == key), true);
    }
    expect(store.word(key)!.mastered, true);
    await store.review(key, false, 'miss');
    expect(store.schedule(key)!.interval, 1);
    expect(store.schedule(key)!.consecutive, 0);
    await store.review(key, false, 'miss');
    expect(store.reviewCount, 7);
    await store.activity(word, 1, 'hint');
    expect(store.dueWords.any((w) => w.key == key), true);
  });
  test('quiz cache works offline and malformed ambiguous quizzes are rejected',
      () async {
    var requests = 0;
    final card = KnowledgeCard(
        wordId: 17,
        word: 'قمر',
        definition: 'تابع طبيعي للأرض',
        sourceName: 'معجم الاختبار');
    final api = ApiService(client: MockClient((_) async {
      requests++;
      return http.Response(
          jsonEncode({
            'id': 'q17',
            'question': card.definition,
            'choices': ['بحر', 'قمر', 'نهر'],
            'correctIndex': 1,
            'cue': {'firstLetter': 'ق', 'length': 3}
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final learning = LearningStore(api: api);
    expect((await learning.quizFor(card)).choices.length, 3);
    await learning.quizFor(card);
    expect(requests, 1);
    expect(
        () => LearningQuiz.fromJson({
              'id': 'bad',
              'question': 'معنى',
              'choices': ['قمر', 'قمر', 'قلم'],
              'correctIndex': 0,
              'cue': {'firstLetter': 'ق', 'length': 3}
            }),
        throwsFormatException);
    expect(normalizeAnswer('أَسَد'), 'أسد');
    expect(normalizeAnswer('أسد'), isNot(normalizeAnswer('اسد')));
    expect(normalizeAnswer('رؤيا'), isNot(normalizeAnswer('رويا')));
  });
  test('missing Arabic voice returns a quiet fallback', () async {
    const channel = MethodChannel('kalimat_sahmiya/speech');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    expect(await SpeechService().speak('قمر'), false);
    await SpeechService().stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await SpeechService().speak('قمر'), false);
  });
}
