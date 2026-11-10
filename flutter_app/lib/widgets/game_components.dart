import 'package:flutter/material.dart';
import '../models/puzzle.dart';
import '../theme.dart';

class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motionDuration(context, 300 + order.clamp(0, 3) * 15),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)), child: child)));
}

class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.label});
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: widget.label,
      enabled: widget.onTap != null,
      child: AnimatedScale(
          scale: _pressed ? .96 : 1,
          duration: motionDuration(context, 100),
          child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.onTap == null
                  ? null
                  : (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              child: widget.child)));
}

class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins, this.dark = false});
  final int coins;
  final bool dark;
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'الرصيد ${arabicNumber(coins)} قطعة ذهبية',
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: .13)
                  : const Color(0xFFF0E6D2),
              borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.toll_rounded, size: 23, color: GameColors.gold),
            const SizedBox(width: 7),
            TweenAnimationBuilder<double>(
                tween: Tween(end: coins.toDouble()),
                duration: motionDuration(context, 350),
                builder: (_, value, __) => Text(arabicNumber(value.round()),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : const Color(0xFF785B29))))
          ])));
}

class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge(
      {super.key, required this.difficulty, this.dark = false});
  final GameDifficulty difficulty;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: .15)
              : difficulty.color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(difficulty.icon,
            size: 15, color: dark ? Colors.white : difficulty.color),
        const SizedBox(width: 5),
        Text(difficulty.label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : difficulty.color))
      ]));
}

class GameProgress extends StatelessWidget {
  const GameProgress(
      {super.key,
      required this.value,
      this.color = GameColors.mint,
      this.dark = false});
  final double value;
  final Color color;
  final bool dark;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: motionDuration(context, 300),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: dark
                  ? Colors.white.withValues(alpha: .17)
                  : color.withValues(alpha: .10),
              color: color)));
}

class PuzzleEmblem extends StatelessWidget {
  const PuzzleEmblem({super.key, this.size = 108});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: Transform.rotate(
          angle: -.10,
          child: Directionality(
              textDirection: TextDirection.ltr,
              child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  children: [
                    for (var i = 0; i < 9; i++)
                      Entrance(
                          order: i,
                          child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: i == 2 || i == 6
                                      ? GameColors.gold
                                      : Colors.white
                                          .withValues(alpha: i == 4 ? .3 : .94),
                                  borderRadius:
                                      BorderRadius.circular(size / 13)),
                              child: i == 2 || i == 6
                                  ? Icon(
                                      i == 2
                                          ? Icons.arrow_back_rounded
                                          : Icons.arrow_downward_rounded,
                                      color: GameColors.primary,
                                      size: size / 5.5)
                                  : Text(
                                      [
                                        'ر',
                                        'م',
                                        '←',
                                        'ش',
                                        'س',
                                        'م',
                                        '↓',
                                        'ن',
                                        'و'
                                      ][i],
                                      style: TextStyle(
                                          fontSize: size / 5.5,
                                          height: 1.2,
                                          fontWeight: FontWeight.w800,
                                          color: i == 4
                                              ? Colors.white
                                              : GameColors.primary))))
                  ]))));
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'نجهز لك تحديا جميلا…'});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
          child: Entrance(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.extension_rounded,
            size: 54, color: GameColors.primary),
        const SizedBox(height: 20),
        Text(message),
        const SizedBox(height: 18),
        if (motionDuration(context) != Duration.zero)
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
      ])));
}

Route<T> gameRoute<T>(Widget child) => PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondary, page) {
      if (motionDuration(context) == Duration.zero) return page;
      return FadeTransition(
          opacity: animation,
          child: SlideTransition(
              position: Tween(begin: const Offset(-.05, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
              child: page));
    });

class VictoryDialog extends StatelessWidget {
  const VictoryDialog(
      {super.key,
      required this.level,
      required this.reward,
      required this.onNext,
      required this.onHome});
  final int level;
  final int reward;
  final VoidCallback onNext;
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(children: [
            SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 10),
                      Entrance(
                          child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF0E6D2)),
                              child: const Icon(Icons.emoji_events_rounded,
                                  size: 66, color: GameColors.gold))),
                      const SizedBox(height: 20),
                      const Text('خطوة جميلة في رحلتك!',
                          style: TextStyle(
                              fontSize: 27, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text('أكملت المستوى ${arabicNumber(level)} بكل تألق',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      DifficultyBadge(
                          difficulty: GameDifficulty.forLevel(level)),
                      const SizedBox(height: 20),
                      SoftPanel(
                          color: const Color(0xFFF3EDE1),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.toll_rounded,
                                    color: GameColors.gold),
                                const SizedBox(width: 10),
                                Flexible(
                                    child: Text(
                                        reward > 0
                                            ? '+${arabicNumber(reward)} قطعة ذهبية'
                                            : 'المكافأة محفوظة في رصيدك',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF785B29))))
                              ])),
                      const SizedBox(height: 22),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: onNext,
                              icon: const Icon(Icons.arrow_back_rounded,
                                  textDirection: TextDirection.ltr),
                              label: const Text('التحدي التالي'))),
                      const SizedBox(height: 6),
                      TextButton(
                          onPressed: onHome,
                          child: const Text('العودة إلى رحلتي')),
                    ])))
          ])));
}
