import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../models/learning.dart';
import '../models/puzzle.dart';
import 'api_service.dart';

/// Same learning logic for SQLite on phones and the temporary in-memory Edge preview.
class LearningStore extends ChangeNotifier {
  LearningStore({required this.api, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final ApiService api;
  final DateTime Function() _clock;
  Database? _db;
  final _words = <String, LearnedWord>{};
  final _cards = <String, KnowledgeCard>{};
  final _schedules = <String, ReviewSchedule>{};
  final _events = <String>{};
  final _stats = <String, int>{};
  final _preferences = <String, String>{};
  final _fetching = <String, Future<KnowledgeCard>>{};
  final _library = <String, KnowledgeCard>{};
  List<KnowledgeCard> get library => {..._library, ..._cards}.values.toList();
  Future<void>? _pending;
  List<LearnedWord> get words => List.unmodifiable(_words.values);
  LearnedWord? word(String key) => _words[key];
  ReviewSchedule? schedule(String key) => _schedules[key];
  int get discovered => _words.length;
  int get mastered => _words.values.where((w) => w.mastered).length;
  int get reviewCount => _stats['reviews'] ?? 0;
  int get quizCount => _stats['quizzes'] ?? 0;
  int get sessions => _stats['sessions'] ?? 0;
  int get openedCards => _stats['cards'] ?? 0;
  double get accuracy =>
      reviewCount == 0 ? 0 : (_stats['review_correct'] ?? 0) / reviewCount;
  int get exploredCategories =>
      _words.values.map((w) => w.category).toSet().length;
  double get fontScale =>
      double.tryParse(_preferences['font_scale'] ?? '') ?? 1;
  bool get focusMode => _preferences['focus_mode'] == 'true';
  bool get reducedMotion => _preferences['reduced_motion'] == 'true';
  int get sessionSize => int.tryParse(_preferences['session_size'] ?? '') ?? 5;
  List<LearningAchievement> get achievements => [
        LearningAchievement('مكتشف الكلمات', 10, discovered, 'explore'),
        LearningAchievement('عاشق اللغة', 50, discovered, 'book'),
        LearningAchievement('موسوعة صغيرة', 100, discovered, 'library'),
        LearningAchievement('ذاكرة قوية', 25, mastered, 'star'),
        LearningAchievement('رحلة المعرفة', 20, quizCount, 'school'),
      ];
  List<LearnedWord> get dueWords {
    final now = _clock().toUtc();
    final result = _words.values
        .where((w) => !(_schedules[w.key]?.nextReview ?? now).isAfter(now))
        .toList();
    result.sort((a, b) {
      final ad = _schedules[a.key]?.nextReview ?? a.firstLearned;
      final bd = _schedules[b.key]?.nextReview ?? b.firstLearned;
      final date = ad.compareTo(bd);
      return date != 0
          ? date
          : (b.incorrect * 3 + b.hints - b.mastery)
              .compareTo(a.incorrect * 3 + a.hints - a.mastery);
    });
    return result;
  }

  static Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS learned_words (
      word_key TEXT PRIMARY KEY, word_id INTEGER, answer TEXT NOT NULL, clue TEXT NOT NULL,
      definition TEXT NOT NULL, category TEXT NOT NULL, source TEXT NOT NULL, difficulty TEXT NOT NULL,
      first_learned TEXT NOT NULL, last_reviewed TEXT NOT NULL, encounters INTEGER NOT NULL,
      correct INTEGER NOT NULL, incorrect INTEGER NOT NULL, hints INTEGER NOT NULL,
      mastery INTEGER NOT NULL, favorite INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS knowledge_cards (
      word_key TEXT PRIMARY KEY, content TEXT NOT NULL, cached_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS review_schedule (
      word_key TEXT PRIMARY KEY, next_review TEXT NOT NULL, interval INTEGER NOT NULL,
      consecutive INTEGER NOT NULL, last_correct INTEGER NOT NULL)''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_review_due ON review_schedule(next_review)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS learning_stats (key TEXT PRIMARY KEY,value INTEGER NOT NULL)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS learning_events (id TEXT PRIMARY KEY,created_at TEXT NOT NULL)');
  }

  Future<void> attach(Database db) async {
    _db = db;
    for (final row in await db.query('learned_words')) {
      final word = LearnedWord.fromRow(row);
      _words[word.key] = word;
    }
    for (final row in await db.query('knowledge_cards')) {
      _cards[row['word_key'] as String] = KnowledgeCard.fromJson(
          jsonDecode(row['content'] as String) as Map<String, dynamic>);
    }
    for (final row in await db.query('review_schedule')) {
      _schedules[row['word_key'] as String] = ReviewSchedule(
          nextReview: DateTime.parse(row['next_review'] as String),
          interval: row['interval'] as int,
          consecutive: row['consecutive'] as int,
          lastCorrect: row['last_correct'] == 1);
    }
    for (final row in await db.query('learning_events')) {
      _events.add(row['id'] as String);
    }
    for (final row in await db.query('learning_stats')) {
      _stats[row['key'] as String] = row['value'] as int;
    }
    for (final row in await db
        .query('settings', where: 'key LIKE ?', whereArgs: ['learning_%'])) {
      _preferences[(row['key'] as String).substring(9)] =
          row['value'] as String;
    }
    notifyListeners();
  }

  Future<T> _queue<T>(Future<T> Function() fn) {
    final result = _pending == null
        ? Future<T>.microtask(fn)
        : _pending!.then((_) => fn());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    return result;
  }

  Future<void> flush() => _pending ?? SynchronousFuture<void>(null);
  Future<void> loadLibrary(AssetBundle bundle) async {
    final data =
        jsonDecode(await bundle.loadString('assets/knowledge/cards.json'))
            as List;
    for (final item in data) {
      final card =
          KnowledgeCard.fromJson(Map<String, dynamic>.from(item as Map));
      _library[wordKey(card.word, card.definition)] = card;
    }
  }

  Future<void> refreshLibrary() async {
    final cards = await api.knowledgeCards();
    await _queue(() async {
      for (final card in cards) {
        final key = wordKey(card.word, card.definition);
        if (_db != null) {
          await _db!.insert(
              'knowledge_cards',
              {
                'word_key': key,
                'content': jsonEncode(card.toJson()),
                'cached_at': _clock().toUtc().toIso8601String()
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        _cards[key] = card;
      }
      notifyListeners();
    });
  }

  Future<void> rememberCard(KnowledgeCard card) => _queue(() async {
        final key = wordKey(card.word, card.definition);
        final now = _clock().toUtc();
        final old = _words[key];
        final word = old?.copyWith(favorite: !old.favorite, card: card) ??
            LearnedWord(
                key: key,
                wordId: card.wordId,
                answer: card.word,
                clue: card.definition,
                definition: card.definition,
                firstLearned: now,
                lastReviewed: now,
                category: card.category,
                source: card.sourceName,
                difficulty: card.difficulty,
                favorite: true);
        await _commit(
            word: word,
            card: card,
            schedule: _schedules[key] ?? ReviewSchedule(nextReview: now));
      });

  Future<void> setPreference(String key, String value) => _queue(() async {
        if (!{'font_scale', 'focus_mode', 'reduced_motion', 'session_size'}
            .contains(key)) {
          return;
        }
        if (key == 'font_scale' && !{'1', '1.2', '1.4'}.contains(value)) return;
        if (key == 'session_size' && !{'5', '10', '15'}.contains(value)) return;
        if (_db != null) {
          await _db!.insert(
              'settings', {'key': 'learning_$key', 'value': value},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        _preferences[key] = value;
        notifyListeners();
      });

  Future<void> _commit(
      {LearnedWord? word,
      ReviewSchedule? schedule,
      String? event,
      Map<String, int> increments = const {},
      KnowledgeCard? card}) async {
    final now = _clock().toUtc();
    Future<void> write(DatabaseExecutor db) async {
      if (word != null) {
        await db.insert('learned_words', word.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        if (schedule != null) {
          await db.insert(
              'review_schedule',
              {
                'word_key': word.key,
                'next_review': schedule.nextReview.toIso8601String(),
                'interval': schedule.interval,
                'consecutive': schedule.consecutive,
                'last_correct': schedule.lastCorrect ? 1 : 0
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (card != null) {
          await db.insert(
              'knowledge_cards',
              {
                'word_key': word.key,
                'content': jsonEncode(card.toJson()),
                'cached_at': now.toIso8601String()
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (event != null) {
        await db.insert('learning_events',
            {'id': event, 'created_at': now.toIso8601String()},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final entry in increments.entries) {
        await db.insert('learning_stats',
            {'key': entry.key, 'value': (_stats[entry.key] ?? 0) + entry.value},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    if (_db != null) await _db!.transaction(write);
    if (word != null) {
      _words[word.key] = word;
      if (schedule != null) _schedules[word.key] = schedule;
      if (card != null) _cards[word.key] = card;
    }
    if (event != null) _events.add(event);
    for (final entry in increments.entries) {
      _stats.update(entry.key, (v) => v + entry.value,
          ifAbsent: () => entry.value);
    }
    notifyListeners();
  }

  Future<void> encounterPuzzle(Puzzle puzzle) async {
    for (final word in puzzle.words) {
      await activity(word, puzzle.level, 'encounter',
          difficulty: puzzle.difficulty);
    }
  }

  Future<void> activity(PuzzleWord word, int level, String kind,
          {GameDifficulty? difficulty, String? uniqueId}) =>
      _queue(() async {
        final event = uniqueId ?? '$kind:$level:${word.id}';
        if (_events.contains(event)) return;
        final now = _clock().toUtc();
        final key = wordKey(word.answer, word.clue);
        final old = _words[key];
        var updated = old ??
            LearnedWord.fromWord(
                word, now, difficulty ?? GameDifficulty.forLevel(level));
        var schedule = _schedules[key] ?? ReviewSchedule(nextReview: now);
        if (kind == 'encounter') {
          if (old != null) {
            updated = updated.copyWith(encounters: old.encounters + 1);
          }
        } else if (kind == 'solved') {
          updated = updated.copyWith(
              correct: updated.correct + 1,
              mastery: (updated.mastery + 20).clamp(0, 100));
        } else if (kind == 'incorrect' || kind == 'hint') {
          updated = updated.copyWith(
              incorrect: updated.incorrect + (kind == 'incorrect' ? 1 : 0),
              hints: updated.hints + (kind == 'hint' ? 1 : 0),
              mastery: (updated.mastery - 10).clamp(0, 100));
          schedule = ReviewSchedule(nextReview: now);
        }
        await _commit(word: updated, schedule: schedule, event: event);
      });

  Future<void> favorite(String key) => _queue(() async {
        final word = _words[key];
        if (word == null) return;
        await _commit(word: word.copyWith(favorite: !word.favorite));
      });

  KnowledgeCard fallback(LearnedWord word) => KnowledgeCard(
      difficulty: word.difficulty,
      wordId: word.wordId,
      word: word.answer,
      definition: word.definition.isEmpty ? word.clue : word.definition,
      sourceName: word.source.contains('WordNet')
          ? 'ووردنت العربية 4.0 — صلاح عبده'
          : 'معجم اللعبة الأصلي',
      sourceUrl: word.source.contains('WordNet')
          ? 'https://github.com/Salah-Sal/arabic-wordnet-v4'
          : null,
      sourceLicense: word.source.contains('WordNet') ? 'CC BY 4.0' : null);

  Future<KnowledgeCard> cardFor(LearnedWord word,
      {bool refresh = false}) async {
    if (!refresh && _cards.containsKey(word.key)) return _cards[word.key]!;
    if (!refresh && _library.containsKey(word.key)) return _library[word.key]!;
    return _fetching.putIfAbsent(word.key, () async {
      var card = fallback(word);
      try {
        if (word.wordId != null) {
          final fetched = await api.fetchKnowledge(word.wordId!);
          // Old saved puzzles may refer to another dictionary release: never replace their meaning.
          if (fetched.word == word.answer && fetched.definition == word.clue) {
            card = fetched;
          }
        }
      } catch (_) {
        /* Cache the offline definition; refresh remains an explicit action. */
      }
      try {
        await _queue(() => _commit(
            word: (_words[word.key] ?? word).copyWith(card: card), card: card));
        return card;
      } finally {
        _fetching.remove(word.key);
      }
    });
  }

  Future<LearningQuiz> quizFor(KnowledgeCard card) async {
    final key =
        'quiz:${base64Url.encode(utf8.encode(wordKey(card.word, card.definition)))}';
    final cached = _preferences[key];
    if (cached != null) {
      return LearningQuiz.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    if (card.wordId == null) {
      throw const FormatException('لا يتوفر اختبار لهذه الكلمة');
    }
    final quiz = await api.fetchQuiz(card.wordId!);
    if (quiz.choices[quiz.correctIndex] != card.word ||
        quiz.question != card.definition) {
      throw const FormatException('بيانات الاختبار غير متطابقة');
    }
    await _queue(() async {
      final json = jsonEncode(quiz.toJson());
      if (_db != null) {
        await _db!.insert('settings', {'key': 'learning_$key', 'value': json},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      _preferences[key] = json;
    });
    return quiz;
  }

  Future<void> openedCard() => _queue(() => _commit(increments: {'cards': 1}));

  Future<bool> quizResult(String id, String key, bool correct) =>
      _queue(() async {
        final event = 'quiz:$id';
        if (_events.contains(event) || !_words.containsKey(key)) return false;
        final old = _words[key]!;
        await _commit(
            word: old.copyWith(
                correct: old.correct + (correct ? 1 : 0),
                incorrect: old.incorrect + (correct ? 0 : 1),
                mastery: (old.mastery + (correct ? 10 : -10)).clamp(0, 100)),
            event: event,
            increments: {'quizzes': 1});
        return true;
      });
  Future<void> review(String key, bool correct, String sessionId) =>
      _queue(() async {
        final event = 'review:$sessionId:$key';
        final old = _words[key];
        if (_events.contains(event) || old == null) return;
        final now = _clock().toUtc();
        final schedule = (_schedules[key] ?? ReviewSchedule(nextReview: now))
            .answer(correct, now);
        await _commit(
            word: old.copyWith(
                correct: old.correct + (correct ? 1 : 0),
                incorrect: old.incorrect + (correct ? 0 : 1),
                lastReviewed: now,
                mastery: (old.mastery + (correct ? 20 : -20)).clamp(0, 100)),
            schedule: schedule,
            event: event,
            increments: {'reviews': 1, 'review_correct': correct ? 1 : 0});
      });
  Future<void> finishSession(String id) => _queue(() async {
        if (!_events.contains('session:$id')) {
          await _commit(event: 'session:$id', increments: {'sessions': 1});
        }
      });
}
