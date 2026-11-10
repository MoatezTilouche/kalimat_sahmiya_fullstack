import 'puzzle.dart';

String wordKey(String answer, String clue) => '$answer\u001f$clue';
String normalizeAnswer(String value) =>
    value.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '').trim();

const knowledgeCategories = {
  'language': 'اللغة العربية',
  'history': 'التاريخ',
  'geography': 'الجغرافيا',
  'science': 'العلوم',
  'literature': 'الأدب العربي',
  'civilizations': 'الحضارات',
  'nature': 'الطبيعة',
  'culture': 'الثقافة العامة',
  'inventions': 'الاختراعات',
};

String normalizeArabic(String value) => value
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll('أ', 'ا')
    .replaceAll('إ', 'ا')
    .replaceAll('آ', 'ا')
    .trim();

class KnowledgeCard {
  const KnowledgeCard(
      {required this.word,
      required this.definition,
      required this.sourceName,
      this.wordId,
      this.fact,
      this.explanation,
      this.sourceUrl,
      this.sourceRef,
      this.sourceLicense,
      this.dataLicense,
      this.category = 'language',
      this.reviewStatus = 'unreviewed',
      this.difficulty = GameDifficulty.easy});
  final GameDifficulty difficulty;
  final int? wordId;
  final String word, definition, sourceName, category, reviewStatus;
  final String? fact,
      explanation,
      sourceUrl,
      sourceRef,
      sourceLicense,
      dataLicense;
  factory KnowledgeCard.fromJson(Map<String, dynamic> data) => KnowledgeCard(
      wordId: data['wordId'] as int?,
      word: data['word'] as String,
      difficulty: GameDifficulty.parse(data['difficulty'] as String? ?? 'easy'),
      definition: data['definition'] as String,
      sourceName: data['sourceName'] as String,
      category: data['category'] as String? ?? 'language',
      reviewStatus: data['reviewStatus'] as String? ?? 'unreviewed',
      fact: data['reviewStatus'] == 'reviewed' ? data['fact'] as String? : null,
      explanation: data['explanation'] as String?,
      sourceUrl: data['sourceUrl'] as String?,
      sourceRef: data['sourceRef'] as String?,
      sourceLicense: data['sourceLicense'] as String?,
      dataLicense: data['dataLicense'] as String?);
  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'word': word,
        'definition': definition,
        'sourceName': sourceName,
        'category': category,
        'reviewStatus': reviewStatus,
        'fact': fact,
        'explanation': explanation,
        'difficulty': difficulty.code,
        'sourceUrl': sourceUrl,
        'sourceRef': sourceRef,
        'sourceLicense': sourceLicense,
        'dataLicense': dataLicense
      };
}

class LearnedWord {
  const LearnedWord(
      {required this.key,
      required this.answer,
      required this.clue,
      required this.firstLearned,
      required this.lastReviewed,
      this.wordId,
      this.definition = '',
      this.category = 'language',
      this.source = '',
      this.difficulty = GameDifficulty.easy,
      this.encounters = 1,
      this.correct = 0,
      this.incorrect = 0,
      this.hints = 0,
      this.mastery = 0,
      this.favorite = false});
  final String key, answer, clue, definition, category, source;
  final int? wordId;
  final DateTime firstLearned, lastReviewed;
  final GameDifficulty difficulty;
  final int encounters, correct, incorrect, hints, mastery;
  final bool favorite;
  bool get mastered => mastery >= 80;
  factory LearnedWord.fromWord(
          PuzzleWord word, DateTime now, GameDifficulty difficulty) =>
      LearnedWord(
          key: wordKey(word.answer, word.clue),
          wordId: word.wordId,
          answer: word.answer,
          clue: word.clue,
          definition: word.clue,
          source: word.source ?? '',
          difficulty: word.difficulty ?? difficulty,
          firstLearned: now,
          lastReviewed: now);
  LearnedWord copyWith(
          {int? encounters,
          int? correct,
          int? incorrect,
          int? hints,
          int? mastery,
          bool? favorite,
          DateTime? lastReviewed,
          KnowledgeCard? card}) =>
      LearnedWord(
          key: key,
          wordId: card?.wordId ?? wordId,
          answer: answer,
          clue: clue,
          definition: card?.definition ?? definition,
          category: card?.category ?? category,
          source: source,
          difficulty: difficulty,
          firstLearned: firstLearned,
          lastReviewed: lastReviewed ?? this.lastReviewed,
          encounters: encounters ?? this.encounters,
          correct: correct ?? this.correct,
          incorrect: incorrect ?? this.incorrect,
          hints: hints ?? this.hints,
          mastery: mastery ?? this.mastery,
          favorite: favorite ?? this.favorite);
  Map<String, Object?> toRow() => {
        'word_key': key,
        'word_id': wordId,
        'answer': answer,
        'clue': clue,
        'definition': definition,
        'category': category,
        'source': source,
        'difficulty': difficulty.code,
        'first_learned': firstLearned.toIso8601String(),
        'last_reviewed': lastReviewed.toIso8601String(),
        'encounters': encounters,
        'correct': correct,
        'incorrect': incorrect,
        'hints': hints,
        'mastery': mastery,
        'favorite': favorite ? 1 : 0
      };
  factory LearnedWord.fromRow(Map<String, Object?> r) => LearnedWord(
      key: r['word_key'] as String,
      wordId: r['word_id'] as int?,
      answer: r['answer'] as String,
      clue: r['clue'] as String,
      definition: r['definition'] as String,
      category: r['category'] as String,
      source: r['source'] as String,
      difficulty: GameDifficulty.parse(r['difficulty'] as String),
      firstLearned: DateTime.parse(r['first_learned'] as String),
      lastReviewed: DateTime.parse(r['last_reviewed'] as String),
      encounters: r['encounters'] as int,
      correct: r['correct'] as int,
      incorrect: r['incorrect'] as int,
      hints: r['hints'] as int,
      mastery: r['mastery'] as int,
      favorite: r['favorite'] == 1);
}

class ReviewSchedule {
  const ReviewSchedule(
      {required this.nextReview,
      this.interval = 0,
      this.consecutive = 0,
      this.lastCorrect = false});
  static const intervals = [1, 3, 7, 14, 30];
  final DateTime nextReview;
  final int interval, consecutive;
  final bool lastCorrect;
  ReviewSchedule answer(bool correct, DateTime now) {
    final streak = correct ? consecutive + 1 : 0;
    final days =
        correct ? intervals[(streak - 1).clamp(0, intervals.length - 1)] : 1;
    return ReviewSchedule(
        nextReview: now.add(Duration(days: days)),
        interval: days,
        consecutive: streak,
        lastCorrect: correct);
  }
}

class LearningQuiz {
  const LearningQuiz(
      {required this.id,
      required this.question,
      required this.choices,
      required this.correctIndex,
      required this.firstLetter,
      required this.length});
  final String id, question, firstLetter;
  final List<String> choices;
  final int correctIndex, length;
  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'choices': choices,
        'correctIndex': correctIndex,
        'cue': {'firstLetter': firstLetter, 'length': length}
      };
  factory LearningQuiz.fromJson(Map<String, dynamic> data) {
    final choices = (data['choices'] as List).cast<String>();
    final correct = data['correctIndex'] as int;
    final cue = data['cue'] as Map;
    if (choices.length != 3 ||
        choices.toSet().length != 3 ||
        correct < 0 ||
        correct > 2 ||
        choices
                .where((c) =>
                    c.startsWith(cue['firstLetter'] as String) &&
                    c.length == cue['length'])
                .length !=
            1 ||
        !choices[correct].startsWith(cue['firstLetter'] as String) ||
        choices[correct].length != cue['length']) {
      throw const FormatException('بيانات الاختبار غير صالحة');
    }
    return LearningQuiz(
        id: data['id'] as String,
        question: data['question'] as String,
        choices: choices,
        correctIndex: correct,
        firstLetter: cue['firstLetter'] as String,
        length: cue['length'] as int);
  }
}

class LearningAchievement {
  const LearningAchievement(this.label, this.target, this.value, this.symbol);
  final String label, symbol;
  final int target, value;
  bool get unlocked => value >= target;
}
