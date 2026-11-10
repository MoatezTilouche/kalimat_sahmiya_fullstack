// Export real rendered screens with:
// flutter test --dart-define=GENERATE_PREVIEWS=true test/preview_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat_sahmiya/models/puzzle.dart';
import 'package:kalimat_sahmiya/screens/game_screen.dart';
import 'package:kalimat_sahmiya/screens/home_screen.dart';
import 'package:kalimat_sahmiya/screens/intro_screen.dart';
import 'package:kalimat_sahmiya/screens/splash_screen.dart';
import 'package:kalimat_sahmiya/theme.dart';
import 'package:kalimat_sahmiya/widgets/game_components.dart';
import 'package:kalimat_sahmiya/services/preview_store.dart';
import 'package:kalimat_sahmiya/services/api_service.dart';
import 'package:kalimat_sahmiya/screens/dictionary_screen.dart';
import 'package:kalimat_sahmiya/screens/review_screen.dart';
import 'package:kalimat_sahmiya/screens/knowledge_screen.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Puzzle puzzle;
  late PreviewStore store;
  setUpAll(() async {
    if (!const bool.fromEnvironment('GENERATE_PREVIEWS') &&
        !const bool.fromEnvironment('GENERATE_SPLASH_PREVIEW')) {
      return;
    }
    final font = FontLoader('NotoArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final data = jsonDecode(
            await rootBundle.loadString('assets/puzzles/starter_levels.json'))
        as List;
    puzzle = Puzzle.fromJson(Map<String, dynamic>.from(data.first as Map));
    store = PreviewStore(
        api: ApiService(
            client: MockClient((_) async => http.Response('{}', 404))));
    await store.init();
    await store.learning.encounterPuzzle(puzzle);
  });
  testWidgets('export Arabic UI previews', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    Future<void> capture(String name, Widget child,
        {Future<void> Function()? prepare, bool settle = true}) async {
      debugPrint('Rendering $name');
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: gameTheme(),
              home: Directionality(
                  textDirection: TextDirection.rtl, child: child))));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 400));
      }
      if (prepare != null) {
        await prepare();
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump(const Duration(milliseconds: 400));
        }
      }
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        debugPrint('Exported ${file.path}');
        image.dispose();
      });
    }

    if (const bool.fromEnvironment('GENERATE_SPLASH_PREVIEW')) {
      await capture('splash', SplashScreen(warmUp: () async {}, onReady: () {}),
          settle: false, prepare: () async {
        await tester.runAsync(() => precacheImage(
            const AssetImage('assets/branding/logo.png'),
            tester.element(find.byType(SplashScreen))));
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await store.close();
      return;
    }
    await capture('home', HomeScreen(store: store));
    await capture('levels', HomeScreen(store: store), prepare: () async {
      await tester.tap(find.text('المستويات'));
    });
    await capture('game', GameScreen(level: 1, store: store));
    await capture('dictionary', DictionaryScreen(store: store));
    await capture('review', ReviewScreen(store: store));
    await capture('knowledge', KnowledgeScreen(store: store));
    await capture('knowledge_card', KnowledgeScreen(store: store),
        prepare: () async {
      final word = find.text(store.learning.library.first.word).first;
      await tester.ensureVisible(word);
      await tester.tap(word);
    });
    await tester.ensureVisible(find.text('متابعة اللعب'));
    await tester.tap(find.text('متابعة اللعب'));
    await tester.pumpAndSettle();
    await capture('intro', IntroScreen(onStart: () async {}), settle: false);
    await capture(
        'victory',
        Scaffold(
            body: Center(
                child: VictoryDialog(
                    level: 51, reward: 60, onNext: () {}, onHome: () {}))),
        settle: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await store.learning.setPreference('focus_mode', 'true');
    await capture('focus', GameScreen(level: 1, store: store));
    await tester.pumpWidget(const SizedBox.shrink());
    await store.close();
  },
      timeout: const Timeout(Duration(seconds: 60)),
      skip: !const bool.fromEnvironment('GENERATE_PREVIEWS') &&
          !const bool.fromEnvironment('GENERATE_SPLASH_PREVIEW'));
}
