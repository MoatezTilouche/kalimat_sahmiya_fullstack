import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/splash_screen.dart';
import 'services/game_store.dart';
import 'services/preview_store.dart';
import 'services/speech_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['خط نوتو العربية'],
        await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  try {
    final store = kIsWeb ? PreviewStore() : GameStore.instance;
    await store.init();
    runApp(ArabicArrowwordsApp(store: store));
  } catch (_) {
    runApp(MaterialApp(
        theme: gameTheme(),
        home: Scaffold(
            body: Directionality(
                textDirection: TextDirection.rtl,
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.storage_rounded,
                              size: 48, color: GameColors.primary),
                          const SizedBox(height: 20),
                          const Text(
                              'تعذر فتح الحفظ المحلي. أعد فتح التطبيق للمحاولة مجددا.',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: main,
                              child: const Text('إعادة المحاولة'))
                        ])))))));
  }
}

class ArabicArrowwordsApp extends StatefulWidget {
  const ArabicArrowwordsApp({super.key, this.store});
  final GameStore? store;
  @override
  State<ArabicArrowwordsApp> createState() => _ArabicArrowwordsAppState();
}

class _ArabicArrowwordsAppState extends State<ArabicArrowwordsApp>
    with WidgetsBindingObserver {
  bool? introSeen;
  bool _splashFinished = false;
  late final _store = widget.store ?? GameStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.hasSeenIntro.then((value) {
      if (mounted) setState(() => introSeen = value);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(SpeechService().stop());
    }
  }

  Future<void> finishIntro() async {
    await _store.markIntroSeen();
    if (mounted) setState(() => introSeen = true);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'كلمات سهمية',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: gameTheme(),
        builder: (context, child) => ListenableBuilder(
          listenable: _store.learning,
          builder: (context, _) {
            final media = MediaQuery.of(context);
            final learning = _store.learning;
            return MediaQuery(
                data: media.copyWith(
                    textScaler:
                        ComfortTextScaler(media.textScaler, learning.fontScale),
                    disableAnimations: media.disableAnimations ||
                        learning.reducedMotion ||
                        learning.focusMode),
                child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: child ?? const SizedBox.shrink()));
          },
        ),
        home: Builder(
          builder: (context) => AnimatedSwitcher(
            duration: motionDuration(context, 400),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .04), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: !_splashFinished || introSeen == null
                ? SplashScreen(
                    warmUp: _store.api.warmUp,
                    onReady: () {
                      if (mounted) setState(() => _splashFinished = true);
                    })
                : introSeen!
                    ? HomeScreen(store: _store)
                    : IntroScreen(onStart: finishIntro),
          ),
        ),
      );
}

class ComfortTextScaler extends TextScaler {
  const ComfortTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(1);
}
