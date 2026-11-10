import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/game_components.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.warmUp, required this.onReady});

  final Future<void> Function() warmUp;
  final VoidCallback onReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _minimumTimer, _slowTimer;
  bool _minimumElapsed = false, _backendReady = false;
  bool _slow = false, _failed = false, _finished = false;

  @override
  void initState() {
    super.initState();
    _minimumTimer = Timer(const Duration(seconds: 3), () {
      _minimumElapsed = true;
      if (_backendReady) _finish();
    });
    unawaited(_connect());
  }

  Future<void> _connect() async {
    setState(() {
      _failed = false;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_finished) setState(() => _slow = true);
    });
    try {
      await widget.warmUp();
      if (!mounted || _finished) return;
      _backendReady = true;
      _slowTimer?.cancel();
      if (_minimumElapsed) _finish();
    } catch (_) {
      if (!mounted || _finished) return;
      _slowTimer?.cancel();
      setState(() => _failed = true);
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    _minimumTimer?.cancel();
    _slowTimer?.cancel();
    widget.onReady();
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: GameColors.primary,
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: GameColors.gradient),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Entrance(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(36),
                                child: Image.asset('assets/branding/logo.png',
                                    width: 164,
                                    height: 164,
                                    semanticLabel: 'شعار كلمات سهمية'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text('كلمات سهمية',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 8),
                            const Text('حرف، ومعنى، ولحظة هدوء',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFFD5E4D3))),
                            const SizedBox(height: 40),
                            if (!_failed)
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  value:
                                      motionDuration(context) == Duration.zero
                                          ? .65
                                          : null,
                                  strokeWidth: 2.5,
                                  color: GameColors.gold,
                                  backgroundColor: Colors.white24,
                                  semanticsLabel: 'جاري الاتصال',
                                ),
                              )
                            else
                              const Icon(Icons.cloud_off_rounded,
                                  color: GameColors.gold, size: 28),
                            const SizedBox(height: 20),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _failed
                                    ? 'تعذر الاتصال الآن'
                                    : _slow
                                        ? 'ننتظر الاتصال…'
                                        : 'نجهّز رحلتك…',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _failed
                                  ? 'يمكنك إعادة المحاولة أو متابعة المستويات المحفوظة دون إنترنت.'
                                  : _slow
                                      ? 'الاتصال الأول قد يستغرق نحو دقيقة. يمكنك اللعب دون إنترنت أثناء الانتظار.'
                                      : 'المستويات المحفوظة معك حتى دون إنترنت.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Color(0xFFD5E4D3), fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            if (_failed) ...[
                              FilledButton.icon(
                                onPressed: _connect,
                                style: FilledButton.styleFrom(
                                    backgroundColor: GameColors.gold,
                                    foregroundColor: GameColors.primary),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('إعادة المحاولة'),
                              ),
                              const SizedBox(height: 8),
                            ],
                            TextButton(
                              onPressed: _finish,
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white),
                              child: const Text('المتابعة دون إنترنت'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
