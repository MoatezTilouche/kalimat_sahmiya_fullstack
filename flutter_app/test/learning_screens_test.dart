import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kalimat_sahmiya/main.dart';
import 'package:kalimat_sahmiya/screens/dictionary_screen.dart';
import 'package:kalimat_sahmiya/screens/knowledge_screen.dart';
import 'package:kalimat_sahmiya/screens/review_screen.dart';
import 'package:kalimat_sahmiya/screens/game_screen.dart';
import 'package:kalimat_sahmiya/screens/home_screen.dart';
import 'package:kalimat_sahmiya/models/learning.dart';
import 'package:kalimat_sahmiya/services/api_service.dart';
import 'package:kalimat_sahmiya/services/preview_store.dart';
import 'package:kalimat_sahmiya/theme.dart';
import 'package:kalimat_sahmiya/widgets/knowledge_sheet.dart';
import 'package:kalimat_sahmiya/widgets/puzzle_board.dart';
import 'package:kalimat_sahmiya/widgets/arabic_keyboard.dart';
import 'package:kalimat_sahmiya/widgets/puzzle_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreviewStore store;
  setUp(() async {
    store = PreviewStore(
        api: ApiService(
            client: MockClient((_) async => http.Response('{}', 404))));
    await store.init();
    await store.markIntroSeen();
  });
  tearDown(() => store.close());
  Widget shell(Widget child, {double scale = 1}) => MaterialApp(
      theme: gameTheme(),
      home: Builder(
          builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: Directionality(
                  textDirection: TextDirection.rtl, child: child))));
  testWidgets(
      'dictionary search, favorites, optional knowledge and offline library work',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final puzzle = await store.puzzleForLevel(1);
    await store.learning.encounterPuzzle(puzzle);
    await tester.pumpWidget(shell(DictionaryScreen(store: store)));
    await tester.pumpAndSettle();
    final word = puzzle.words.first;
    await tester.enterText(find.byType(TextField), word.answer);
    await tester.pumpAndSettle();
    expect(find.byType(WordLibraryCard), findsOneWidget);
    await tester.tap(find.byTooltip('أضف إلى المفضلة').first);
    await tester.pumpAndSettle();
    expect(
        store.learning.word(wordKey(word.answer, word.clue))!.favorite, true);
    await tester.tap(find.text('اكتشف المعنى').first);
    await tester.pumpAndSettle();
    expect(find.byType(KnowledgeSheet), findsOneWidget);
    expect(find.text('هل تعلم؟'), findsOneWidget);
    await tester.ensureVisible(find.text('متابعة اللعب'));
    await tester.tap(find.text('متابعة اللعب'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(shell(KnowledgeScreen(store: store)));
    await tester.pumpAndSettle();
    expect(store.learning.library.length, greaterThanOrEqualTo(60));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
  testWidgets('review saves answers once and shows a gentle summary',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1200);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await store.learning.encounterPuzzle(await store.puzzleForLevel(1));
    final words = store.learning.dueWords.take(5).toList();
    await tester.pumpWidget(shell(ReviewScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ابدأ جلسة'));
    await tester.pumpAndSettle();
    for (var i = 0; i < words.length; i++) {
      await tester.ensureVisible(find.text(words[i].answer).first);
      await tester.tap(find.text(words[i].answer).first);
      await tester.pumpAndSettle();
      final next = i + 1 == words.length ? 'ملخص الجلسة' : 'الكلمة التالية';
      await tester.ensureVisible(find.text(next));
      await tester.tap(find.text(next));
      await tester.pumpAndSettle();
    }
    expect(find.text('خطوة جميلة في رحلتك'), findsOneWidget);
    expect(store.learning.reviewCount, 5);
    expect(store.learning.sessions, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'rapid input, crossing selection, zoom, deletion and rotation preserve progress',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(shell(GameScreen(level: 1, store: store)));
    await tester.pumpAndSettle();
    final puzzle = await store.puzzleForLevel(1),
        word = (await store.puzzleForLevel(1)).words.first;
    tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).onSelectWord(word);
    await tester.pump();
    final keyboard = tester.widget<ArabicKeyboard>(find.byType(ArabicKeyboard));
    for (final letter in word.answer.split('')) {
      keyboard.onLetter(letter);
    }
    await tester.pumpAndSettle();
    expect((await store.savedLevel(1)).solved, contains(word.id));
    expect(find.byType(KnowledgeSheet),
        findsNothing); // discovery never interrupts gameplay
    final viewer = tester
        .widget<InteractiveViewer>(find.byKey(const ValueKey('puzzle_zoom')));
    final scale = viewer.transformationController!.value.getMaxScaleOnAxis();
    await tester.ensureVisible(find.byTooltip('تكبير الشبكة'));
    await tester.tap(find.byTooltip('تكبير الشبكة'));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(scale));
    await tester.drag(
        find.byKey(const ValueKey('puzzle_zoom')), const Offset(-50, -30));
    await tester.pumpAndSettle();
    expect((await store.savedLevel(1)).solved, contains(word.id));
    final crossing = <String, List<dynamic>>{};
    for (final w in puzzle.words) {
      for (final p in w.cells) {
        crossing.putIfAbsent(p.key, () => []).add(w);
      }
    }
    final pointKey = crossing.keys.firstWhere((k) => crossing[k]!.length > 1);
    final pair = crossing[pointKey]!;
    final point = puzzle.words
        .expand((w) => w.cells)
        .firstWhere((p) => p.key == pointKey);
    tester
        .widget<PuzzleBoard>(find.byType(PuzzleBoard))
        .onSelectWord(pair.first);
    await tester.pump();
    tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).onSelectCell(point);
    await tester.pump();
    tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).onSelectCell(point);
    await tester.pumpAndSettle();
    expect(tester.widget<PuzzleBoard>(find.byType(PuzzleBoard)).cursor!.key,
        pointKey);
    await tester.binding.setSurfaceSize(const Size(900, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 390);
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleViewport), findsOneWidget);
    expect((await store.savedLevel(1)).solved, contains(word.id));
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text and focus preference work on a small RTL screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await store.learning.setPreference('font_scale', '1.4');
    await store.learning.setPreference('focus_mode', 'true');
    await tester.pumpWidget(ArabicArrowwordsApp(store: store));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester
        .pumpWidget(shell(GameScreen(level: 1, store: store), scale: 2));
    await tester.pumpAndSettle();
    expect(find.text('السؤال الحالي'), findsOneWidget);
    expect(find.byType(ArabicKeyboard), findsOneWidget);
    expect(find.byType(PuzzleBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(shell(DictionaryScreen(store: store), scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(shell(ReviewScreen(store: store), scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'focus keeps clue and keyboard visible and saves through pause and resume',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await store.learning.setPreference('focus_mode', 'true');
    await tester.pumpWidget(shell(GameScreen(level: 1, store: store)));
    await tester.pumpAndSettle();
    final screen = Rect.fromLTWH(0, 0, 430, 1100);
    expect(screen.contains(tester.getCenter(find.text('السؤال الحالي'))), true);
    expect(tester.getRect(find.byType(ArabicKeyboard)).bottom,
        lessThanOrEqualTo(1100));
    final word = (await store.puzzleForLevel(1)).words.first;
    tester.widget<ArabicKeyboard>(find.byType(ArabicKeyboard)).onLetter('ض');
    await tester.pumpAndSettle();
    expect((await store.savedLevel(1)).answers[word.cells.first.key], 'ض');
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(
        (await store.savedLevel(1)).answers.containsKey(word.cells.first.key),
        false);
    tester
        .widget<ArabicKeyboard>(find.byType(ArabicKeyboard))
        .onLetter(word.answer[0]);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect((await store.savedLevel(1)).answers[word.cells.first.key],
        word.answer[0]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'comfort controls update Arabic type size and reduce motion immediately',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ArabicArrowwordsApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إعدادات الراحة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كبير جداً'));
    await tester.pumpAndSettle();
    expect(store.learning.fontScale, 1.4);
    final home = tester.element(find.byType(HomeScreen));
    expect(MediaQuery.textScalerOf(home).scale(20), closeTo(28, .01));
    await tester.ensureVisible(find.text('وضع التركيز'));
    await tester.tap(find.text('وضع التركيز'));
    await tester.pumpAndSettle();
    expect(store.learning.focusMode, true);
    expect(MediaQuery.disableAnimationsOf(home), true);
    expect(tester.takeException(), isNull);
  });
}
