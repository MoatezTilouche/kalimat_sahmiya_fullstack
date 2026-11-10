import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat_sahmiya/theme.dart';
import 'package:kalimat_sahmiya/widgets/game_components.dart';

Widget victory({
  bool reduced = true,
  double scale = 1,
  VoidCallback? onNext,
  VoidCallback? onHome,
}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: gameTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: VictoryDialog(
                  level: 51,
                  reward: 60,
                  onNext: onNext ?? () {},
                  onHome: onHome ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kalimat_sahmiya/speech');
  final calls = <MethodCall>[];
  var voiceAvailable = true;
  setUpAll(() async {
    if (!const bool.fromEnvironment('GENERATE_VICTORY_PREVIEW')) return;
    await (FontLoader('NotoArabic')
          ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() {
    calls.clear();
    voiceAvailable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'speak' ? voiceAvailable : null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Arabic thanks speaks on request and stops when dismissed',
      (tester) async {
    await tester.pumpWidget(victory());
    await tester.pumpAndSettle();
    expect(find.text('شكراً يا أبي جوهر!'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.ensureVisible(find.text('اسمع رسالة الشكر'));
    await tester.tap(find.text('اسمع رسالة الشكر'));
    await tester.pump();
    final spoken = calls.where((call) => call.method == 'speak');
    expect(spoken, hasLength(1));
    expect(spoken.single.arguments,
        'شكراً يا أبي جوهر! هذا الإنجاز لك، بكل الحب والتقدير.');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls.where((call) => call.method == 'stop'), hasLength(1));
  });

  testWidgets('unavailable Arabic voice leaves readable feedback',
      (tester) async {
    voiceAvailable = false;
    await tester.pumpWidget(victory());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('اسمع رسالة الشكر'));
    await tester.tap(find.text('اسمع رسالة الشكر'));
    await tester.pumpAndSettle();
    expect(find.text('الصوت العربي غير متاح على هذا الجهاز.'), findsOneWidget);
    expect(find.text('شكراً يا أبي جوهر!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('celebration keeps looping and stops for reduced motion',
      (tester) async {
    await tester.pumpWidget(victory(reduced: false));
    await tester.pump(const Duration(seconds: 7));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(victory());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact screen and large Arabic text keep actions reachable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var next = 0, home = 0;
    await tester.pumpWidget(
        victory(scale: 2, onNext: () => next++, onHome: () => home++));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('التحدي التالي'));
    await tester.tap(find.text('التحدي التالي'));
    await tester.ensureVisible(find.text('العودة إلى رحلتي'));
    await tester.tap(find.text('العودة إلى رحلتي'));
    expect(next, 1);
    expect(home, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export Arabic victory preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester
        .pumpWidget(RepaintBoundary(key: key, child: victory(reduced: false)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('previews/victory.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  }, skip: !const bool.fromEnvironment('GENERATE_VICTORY_PREVIEW'));
}
