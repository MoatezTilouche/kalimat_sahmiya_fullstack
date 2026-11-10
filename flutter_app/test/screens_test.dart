import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat_sahmiya/main.dart';
import 'package:kalimat_sahmiya/models/puzzle.dart';
import 'package:kalimat_sahmiya/screens/game_screen.dart';
import 'package:kalimat_sahmiya/screens/home_screen.dart';
import 'package:kalimat_sahmiya/screens/intro_screen.dart';
import 'package:kalimat_sahmiya/services/api_service.dart';
import 'package:kalimat_sahmiya/services/game_store.dart';
import 'package:kalimat_sahmiya/theme.dart';
import 'package:kalimat_sahmiya/widgets/game_components.dart';
import 'package:kalimat_sahmiya/widgets/puzzle_board.dart';
import 'package:kalimat_sahmiya/widgets/arabic_keyboard.dart';

// Storage itself is covered against real SQLite in game_store_test.dart.
class MemoryStore extends GameStore {
  MemoryStore(this.puzzle);
  final Puzzle puzzle;
  bool seen = false, offline = false;
  int requests = 0;
  int balance = 120;
  bool rewarded = false;
  Set<String> solvedWords = {};
  Map<String, String> entered = {};
  @override
  Future<bool> get hasSeenIntro async => seen;
  @override
  Future<void> markIntroSeen() async {
    seen = true;
  }

  @override
  Future<int> get unlockedLevel async => 1;
  @override
  Future<int> get currentLevel async => 1;
  @override
  Future<int> get coins async => balance;
  @override
  Future<Set<int>> get completedLevels async => {};
  @override
  Future<int> get cachedWordCount async => 0;
  @override
  Future<Puzzle> puzzleForLevel(int level) async {
    requests++;
    if (offline) {
      throw const ApiException(
          'تعذر الاتصال بالإنترنت. المستويات المحفوظة متاحة دائما.');
    }
    return puzzle;
  }

  @override
  Future<void> resumeAt(int level) async {}
  @override
  Future<LevelSave> savedLevel(int level) async =>
      LevelSave(answers: Map.of(entered), solved: {}, completed: false);
  @override
  Future<bool> saveLevel(
      int level, Map<String, String> answers, Set<String> solved,
      {bool completed = false}) async {
    entered = Map.of(answers);
    solvedWords = Set.of(solved);
    if (completed && !rewarded) {
      rewarded = true;
      balance += 60;
      return true;
    }
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Puzzle puzzle;
  setUp(() async {
    final json = jsonDecode(
            await rootBundle.loadString('assets/puzzles/starter_levels.json'))
        as List;
    puzzle = Puzzle.fromJson(Map<String, dynamic>.from(json.first as Map));
  });
  Widget shell(Widget child, {bool reduced = false}) => MaterialApp(
      theme: gameTheme(),
      home: Builder(
          builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Directionality(
                  textDirection: TextDirection.rtl, child: child))));

  testWidgets(
      'solving intersecting words completes the puzzle and shows the earned reward',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryStore(puzzle);
    await tester.pumpWidget(shell(GameScreen(level: 1, store: store)));
    await tester.pumpAndSettle();
    for (final word in puzzle.words) {
      if (store.solvedWords.contains(word.id)) continue;
      tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).onSelectWord(word);
      await tester.pumpAndSettle();
      for (var i = 0; i < word.cells.length; i++) {
        if (store.entered[word.cells[i].key] == word.answer[i]) continue;
        tester
            .widget<ArabicKeyboard>(find.byType(ArabicKeyboard))
            .onLetter(word.answer[i]);
        await tester.pumpAndSettle();
      }
    }
    expect(store.solvedWords.length, puzzle.words.length);
    expect(store.balance, 180);
    expect(find.byType(VictoryDialog), findsOneWidget);
    expect(find.text('+60 قطعة ذهبية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding explains all controls and appears only once',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryStore(puzzle);
    await tester.pumpWidget(ArabicArrowwordsApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('إلى أبي الغالي جوهر، بكل الحب والتقدير'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('استخدم التلميح'), findsOneWidget);
    await tester.tap(find.text('ابدأ رحلتك'));
    await tester.pumpAndSettle();
    expect(store.seen, true);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ArabicArrowwordsApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(IntroScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('level cards distinguish current, completed and locked levels',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(shell(Row(children: [
      for (var i = 1; i <= 3; i++)
        Expanded(
            child: SizedBox(
                height: 100,
                child: LevelTile(
                    level: i,
                    difficulty: GameDifficulty.easy,
                    completed: i == 1,
                    current: i == 2,
                    locked: i == 3,
                    onTap: () => tapped = i))),
    ])));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    await tester.tap(find.text('3'));
    expect(tapped, 0);
    await tester.tap(find.text('2'));
    expect(tapped, 2);
  });

  testWidgets('home chapters show exact level bands and allow selecting hard',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        shell(HomeScreen(store: MemoryStore(puzzle)), reduced: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المستويات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1–20'), findsOneWidget);
    expect(find.textContaining('21–50'), findsOneWidget);
    await tester.ensureVisible(find.text('لأهل الفصاحة'));
    await tester.tap(find.text('لأهل الفصاحة'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('level_51')), 300);
    expect(find.byKey(const ValueKey('level_51')), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
  });

  testWidgets(
      'game errors offer retry and an offline bundled game accepts letters',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryStore(puzzle)..offline = true;
    await tester.pumpWidget(shell(GameScreen(level: 1, store: store)));
    await tester.pumpAndSettle();
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    store.offline = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(store.requests, 2);
    expect(
        find.byWidgetPredicate((w) =>
            w is Icon &&
            w.icon == Icons.arrow_back_rounded &&
            w.textDirection == TextDirection.ltr),
        findsWidgets);
    expect(find.byType(PuzzleBoard), findsOneWidget);
    expect(find.text('سهل'), findsOneWidget);
    // The keyboard callback remains available while selection animations run.
    await tester.ensureVisible(find.text('ض'));
    await tester.tap(find.text('ض'));
    await tester.pumpAndSettle();
    expect(store.entered.values, contains('ض'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'premium victory and grid fit compact screens with reduced motion',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        shell(GameScreen(level: 1, store: MemoryStore(puzzle)), reduced: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(shell(
        Center(
            child: VictoryDialog(
                level: 51, reward: 60, onNext: () {}, onHome: () {})),
        reduced: true));
    await tester.pumpAndSettle();
    expect(find.text('صعب'), findsOneWidget);
    expect(find.text('+60 قطعة ذهبية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
