import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// A small, decorative thank-you wave, animated without rebuilding the dialog.
class JawharCelebration extends StatefulWidget {
  const JawharCelebration({super.key});

  @override
  State<JawharCelebration> createState() => _JawharCelebrationState();
}

class _JawharCelebrationState extends State<JawharCelebration>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionDuration(context) == Duration.zero) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: RepaintBoundary(
          child: SizedBox(
              width: 190,
              height: 154,
              child: CustomPaint(painter: _CelebrationPainter(_animation)))));
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;
  static const _skin = Color(0xFFE9B58D);
  static const _skinShadow = Color(0xFFD89B73);
  static const _hair = Color(0xFF303A36);
  final _paint = Paint()..isAntiAlias = true;

  void _fill(Canvas canvas, Path path, Color color) {
    _paint
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, _paint);
  }

  void _oval(Canvas canvas, Rect rect, Color color) {
    _paint
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawOval(rect, _paint);
  }

  void _stroke(Canvas canvas, Path path, Color color, double width) {
    _paint
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, _paint);
  }

  void _sparkle(Canvas canvas, double x, double y, double radius) {
    _fill(
        canvas,
        Path()
          ..moveTo(x, y - radius)
          ..quadraticBezierTo(x + 1, y - 1, x + radius, y)
          ..quadraticBezierTo(x + 1, y + 1, x, y + radius)
          ..quadraticBezierTo(x - 1, y + 1, x - radius, y)
          ..quadraticBezierTo(x - 1, y - 1, x, y - radius),
        GameColors.gold);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 190, size.height / 154);
    final phase = animation.value * math.pi * 2;
    final float = math.sin(phase);
    _oval(canvas, const Rect.fromLTWH(35, 16, 122, 122), GameColors.selected);
    _oval(canvas, Rect.fromLTWH(51 - float, 140, 88 + float * 2, 9),
        GameColors.primary.withValues(alpha: .10));
    _sparkle(canvas, 39, 39 - float * 2, 6 + float);
    _sparkle(canvas, 158, 103 + float * 3, 5 - float);
    _sparkle(canvas, 136, 23 + float * 2, 4);
    _oval(canvas, Rect.fromLTWH(29, 91 + float * 3, 5, 5), GameColors.sage);
    _oval(canvas, Rect.fromLTWH(157, 53 - float * 3, 4, 4),
        GameColors.gold.withValues(alpha: .65));

    canvas.save();
    canvas.translate(0, -float * 2);
    // A bent upper arm stays anchored while the forearm waves at the elbow.
    _stroke(
        canvas,
        Path()
          ..moveTo(114, 108)
          ..quadraticBezierTo(131, 119, 138, 96),
        GameColors.primary,
        16);
    canvas.save();
    canvas.translate(138, 96);
    canvas.rotate(.12 + math.sin(phase * 2) * .22);
    _stroke(
        canvas,
        Path()
          ..moveTo(0, 0)
          ..lineTo(0, -24),
        _skin,
        11);
    _oval(canvas, const Rect.fromLTWH(-7, -36, 14, 20), _skin);
    for (var finger = 0; finger < 4; finger++) {
      final x = -4.5 + finger * 3.1;
      _stroke(
          canvas,
          Path()
            ..moveTo(x, -29)
            ..lineTo(x + (finger - 1.5) * .65,
                -39 - (finger == 1 || finger == 2 ? 5 : 1)),
          _skin,
          3.5);
    }
    _stroke(
        canvas,
        Path()
          ..moveTo(-4, -24)
          ..lineTo(-11, -31),
        _skin,
        5);
    canvas.restore();

    _fill(
        canvas,
        Path()
          ..moveTo(84, 98)
          ..quadraticBezierTo(62, 98, 59, 118)
          ..lineTo(56, 141)
          ..quadraticBezierTo(95, 149, 131, 141)
          ..lineTo(127, 117)
          ..quadraticBezierTo(126, 100, 105, 98)
          ..close(),
        GameColors.primary);
    _fill(
        canvas,
        Path()
          ..moveTo(86, 88)
          ..lineTo(85, 101)
          ..quadraticBezierTo(95, 112, 105, 101)
          ..lineTo(104, 88)
          ..close(),
        _skin);
    _oval(canvas, const Rect.fromLTWH(86, 86, 19, 12), _skinShadow);
    _stroke(
        canvas,
        Path()
          ..moveTo(82, 101)
          ..lineTo(94, 113)
          ..lineTo(108, 101),
        GameColors.sage,
        2);
    _stroke(
        canvas,
        Path()
          ..moveTo(94, 114)
          ..lineTo(94, 141),
        GameColors.sage.withValues(alpha: .35),
        1);

    // The other hand rests over his heart as a gesture of thanks.
    _stroke(
        canvas,
        Path()
          ..moveTo(64, 117)
          ..quadraticBezierTo(62, 139, 78, 128),
        GameColors.mint,
        13);
    _stroke(
        canvas,
        Path()
          ..moveTo(77, 128)
          ..lineTo(88, 121),
        _skin,
        9);
    _oval(canvas, const Rect.fromLTWH(83, 115, 13, 10), _skin);
    _fill(
        canvas,
        Path()
          ..moveTo(113, 124)
          ..cubicTo(102, 117, 106, 111, 113, 115)
          ..cubicTo(120, 111, 124, 117, 113, 124),
        GameColors.gold);

    _oval(canvas, const Rect.fromLTWH(67, 61, 12, 16), _skinShadow);
    _oval(canvas, const Rect.fromLTWH(113, 61, 12, 16), _skinShadow);
    _oval(canvas, const Rect.fromLTWH(72, 36, 47, 58), _skin);
    _fill(
        canvas,
        Path()
          ..moveTo(72, 65)
          ..cubicTo(64, 49, 70, 30, 87, 31)
          ..cubicTo(97, 20, 120, 29, 121, 43)
          ..quadraticBezierTo(126, 53, 118, 67)
          ..lineTo(114, 50)
          ..quadraticBezierTo(93, 53, 81, 44)
          ..quadraticBezierTo(80, 58, 75, 58)
          ..lineTo(75, 65)
          ..close(),
        _hair);
    _stroke(
        canvas,
        Path()
          ..moveTo(82, 35)
          ..quadraticBezierTo(98, 29, 111, 38),
        const Color(0xFF4E5A50),
        2.5);
    _stroke(
        canvas,
        Path()
          ..moveTo(82, 61)
          ..quadraticBezierTo(86, 58, 90, 61),
        _hair,
        1.8);
    _stroke(
        canvas,
        Path()
          ..moveTo(101, 61)
          ..quadraticBezierTo(105, 58, 109, 61),
        _hair,
        1.8);
    _oval(canvas, const Rect.fromLTWH(84, 65, 4, 5), _hair);
    _oval(canvas, const Rect.fromLTWH(103, 65, 4, 5), _hair);
    _stroke(
        canvas,
        Path()
          ..moveTo(95, 68)
          ..lineTo(93, 75)
          ..lineTo(97, 75),
        _skinShadow,
        1.6);
    _oval(canvas, const Rect.fromLTWH(78, 73, 9, 5),
        const Color(0xFFD99079).withValues(alpha: .45));
    _oval(canvas, const Rect.fromLTWH(105, 73, 9, 5),
        const Color(0xFFD99079).withValues(alpha: .45));
    _fill(
        canvas,
        Path()
          ..moveTo(86, 79)
          ..quadraticBezierTo(95, 83, 105, 79)
          ..quadraticBezierTo(96, 94, 86, 79),
        const Color(0xFF894C40));
    _stroke(
        canvas,
        Path()
          ..moveTo(89, 81)
          ..quadraticBezierTo(96, 83, 102, 81),
        GameColors.cell,
        2.4);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
