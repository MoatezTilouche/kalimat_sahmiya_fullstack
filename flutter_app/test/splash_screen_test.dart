import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat_sahmiya/screens/splash_screen.dart';
import 'package:kalimat_sahmiya/theme.dart';

Widget splash(Future<void> Function() warmUp, VoidCallback onReady) =>
    MaterialApp(
      theme: gameTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: SplashScreen(warmUp: warmUp, onReady: onReady),
      ),
    );

void main() {
  testWidgets('ready backend still shows the logo for three seconds',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(splash(() async {}, () => opened++));
    await tester.pump(const Duration(seconds: 2));
    expect(opened, 0);
    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keeps loading through a minute-long backend cold start',
      (tester) async {
    final ready = Completer<void>();
    var opened = 0;
    await tester.pumpWidget(splash(() => ready.future, () => opened++));
    await tester.pump(const Duration(seconds: 65));
    expect(opened, 0);
    expect(find.text('ننتظر الاتصال…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready.complete();
    await tester.pump();
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offers retry after failure and continues once it succeeds',
      (tester) async {
    var attempts = 0, opened = 0;
    await tester.pumpWidget(splash(() async {
      if (++attempts == 1) throw Exception('offline');
    }, () => opened++));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('تعذر الاتصال الآن'), findsOneWidget);
    expect(opened, 0);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(attempts, 2);
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline continuation ignores a late backend response',
      (tester) async {
    final ready = Completer<void>();
    var opened = 0;
    await tester.pumpWidget(splash(() => ready.future, () => opened++));
    await tester.tap(find.text('المتابعة دون إنترنت'));
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
    ready.completeError(Exception('connection lost'));
    await tester.pump(const Duration(seconds: 10));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and large text keep offline access visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ready = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      theme: gameTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
            disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SplashScreen(warmUp: () => ready.future, onReady: () {}),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 9));
    await tester.ensureVisible(find.text('المتابعة دون إنترنت'));
    await tester.tap(find.text('المتابعة دون إنترنت'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    ready.complete();
    await tester.pump();
  });
}
