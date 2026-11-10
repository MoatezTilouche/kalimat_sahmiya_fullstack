import 'package:flutter/material.dart';
import '../models/puzzle.dart';
import '../theme.dart';
import '../widgets/game_components.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onStart});
  final Future<void> Function() onStart;
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _starting = false;
  bool _exampleSelected = false;
  static const steps = [
    (
      'اقرأ… واتبع السهم',
      'كل مربع بلون الرمل يحمل سؤالا. اضغط عليه لقراءته كاملا، ثم اتبع السهم إلى اليسار أو إلى الأسفل لتعرف موضع الإجابة.',
      Icons.touch_app_rounded
    ),
    (
      'حرف يلتقي بحرف',
      'اكتب الإجابة بلوحة الحروف العربية. الحروف المشتركة تساعدك على اكتشاف الكلمات المتقاطعة.',
      Icons.keyboard_rounded
    ),
    (
      'تألق في كل مستوى',
      'حل جميع الكلمات لفتح التحدي التالي وكسب القطع الذهبية. تقدمك يبقى محفوظا على هاتفك.',
      Icons.emoji_events_rounded
    ),
    (
      'دفعة صغيرة عند الحاجة',
      'استخدم التلميح لكشف حرف مقابل 25 قطعة ذهبية. أول 75 مستوى معك حتى دون إنترنت.',
      Icons.lightbulb_rounded
    ),
  ];
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_starting) return;
    if (_page < steps.length - 1) {
      if (motionDuration(context) == Duration.zero) {
        _pages.jumpToPage(_page + 1);
        return;
      }
      await _pages.nextPage(
          duration: motionDuration(context, 400), curve: Curves.easeOutCubic);
    } else {
      setState(() => _starting = true);
      try {
        await widget.onStart();
      } catch (_) {
        if (mounted) {
          setState(() => _starting = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('تعذر حفظ البداية. حاول مرة أخرى.')));
        }
      }
    }
  }

  Widget _lesson(int index) => SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(steps[index].$3, size: 30, color: GameColors.gold),
            if (index == 0) ...[
              const SizedBox(height: 12),
              Semantics(
                  button: true,
                  label: 'مثال تفاعلي: اضغط على السهم لتحديد الإجابة',
                  child: InkWell(
                      onTap: () =>
                          setState(() => _exampleSelected = !_exampleSelected),
                      child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final letter in ['ر', 'و', 'ن'])
                                  AnimatedContainer(
                                      duration: motionDuration(context, 160),
                                      margin: const EdgeInsets.all(3),
                                      width: 42,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: _exampleSelected
                                              ? GameColors.sage
                                              : GameColors.cell,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text(
                                          _exampleSelected ? letter : '·',
                                          style: const TextStyle(
                                              fontSize: 23,
                                              color: GameColors.primary))),
                                Container(
                                    width: 48,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: GameColors.sand,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.arrow_back_rounded,
                                        textDirection: TextDirection.ltr,
                                        color: GameColors.primary)),
                              ])))),
            ],
            const SizedBox(height: 12),
            Text(steps[index].$1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(steps[index].$2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFE0EBDD), height: 1.9, fontSize: 14)),
          ])));

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Container(
          decoration: const BoxDecoration(gradient: GameColors.gradient),
          child: SafeArea(
              child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 520),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 28, vertical: 28),
                                      child: Column(children: [
                                        const Entrance(
                                            child: Text('أهلا بك في عالم',
                                                style: TextStyle(
                                                    color: Color(0xFFD5E4D3),
                                                    fontSize: 13))),
                                        const SizedBox(height: 6),
                                        const Entrance(
                                            order: 1,
                                            child: Text('كلمات سهمية',
                                                style: TextStyle(
                                                    fontSize: 35,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white))),
                                        const SizedBox(height: 30),
                                        const PuzzleEmblem(size: 174),
                                        const SizedBox(height: 32),
                                        SoftPanel(
                                            color: Colors.white
                                                .withValues(alpha: .10),
                                            padding: const EdgeInsets.all(20),
                                            child: Column(children: [
                                              const Icon(Icons.favorite_rounded,
                                                  color: GameColors.gold,
                                                  size: 20),
                                              const SizedBox(height: 8),
                                              const Text(
                                                  'إلى أبي الغالي جوهر، بكل الحب والتقدير',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      height: 1.8,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'من ابنك معتز، الذي يحبك كثيرًا.',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: .6))),
                                            ])),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                            height: 250 *
                                                MediaQuery.textScalerOf(context)
                                                    .scale(1)
                                                    .clamp(1, 1.8),
                                            child: PageView.builder(
                                                controller: _pages,
                                                itemCount: steps.length,
                                                onPageChanged: (p) =>
                                                    setState(() => _page = p),
                                                itemBuilder: (context, i) =>
                                                    _lesson(i))),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              for (var i = 0;
                                                  i < steps.length;
                                                  i++)
                                                AnimatedContainer(
                                                    duration:
                                                        motionDuration(context),
                                                    width: _page == i ? 26 : 7,
                                                    height: 7,
                                                    margin: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4),
                                                    decoration: BoxDecoration(
                                                        color: _page == i
                                                            ? GameColors.gold
                                                            : Colors.white
                                                                .withValues(
                                                                    alpha: .25),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8)))
                                            ]),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                            width: double.infinity,
                                            child: FilledButton(
                                                onPressed:
                                                    _starting ? null : _next,
                                                style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.white,
                                                    foregroundColor:
                                                        GameColors.primary),
                                                child: Text(_starting
                                                    ? 'نحفظ بدايتك…'
                                                    : _page == steps.length - 1
                                                        ? 'ابدأ رحلتك'
                                                        : 'التالي'))),
                                        const SizedBox(height: 12),
                                        Text(
                                            '${arabicNumber(_page + 1)} من ${arabicNumber(steps.length)}',
                                            style: const TextStyle(
                                                color: Color(0xFFD5E4D3),
                                                fontSize: 11)),
                                      ]))))))))));
}
