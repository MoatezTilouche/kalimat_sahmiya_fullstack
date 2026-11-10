import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/puzzle.dart';
import '../theme.dart';
import 'puzzle_board.dart';

class PuzzleViewport extends StatefulWidget {
  const PuzzleViewport({super.key, required this.board, this.height = 320});
  final PuzzleBoard board;
  final double height;
  @override
  State<PuzzleViewport> createState() => _PuzzleViewportState();
}

class _PuzzleViewportState extends State<PuzzleViewport>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  Animation<Matrix4>? _matrix;
  bool _positioned = false;
  @override
  void initState() {
    super.initState();
    _animation.addListener(() {
      if (_matrix != null) _transform.value = _matrix!.value;
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _move(Matrix4 target) {
    if (motionDuration(context) == Duration.zero) {
      _transform.value = target;
      return;
    }
    _matrix = Matrix4Tween(begin: _transform.value.clone(), end: target)
        .animate(
            CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    _animation.forward(from: 0);
  }

  void _zoom(double factor, Size viewport, double extent) {
    final old = _transform.value;
    final scale = old.getMaxScaleOnAxis();
    final minimum = math.min(viewport.width, viewport.height) / extent;
    final next = (scale * factor).clamp(minimum, 2.5);
    final point = _transform.toScene(viewport.center(Offset.zero));
    _move(Matrix4.identity()
      ..translateByDouble(viewport.width / 2 - point.dx * next,
          viewport.height / 2 - point.dy * next, 0, 1)
      ..scaleByDouble(next, next, 1, 1));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final height = widget.height;
        final extent = math
            .max(
                box.maxWidth,
                widget.board.puzzle.size *
                    52 *
                    MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.8))
            .toDouble();
        final viewport = Size(box.maxWidth, height);
        final fit = math.min(viewport.width, viewport.height) / extent;
        if (!_positioned) {
          _positioned = true;
          final cursor = widget.board.cursor ?? const GridPosition(0, 0);
          final x = (cursor.column + .5) * extent / widget.board.puzzle.size;
          final y = (cursor.row + .5) * extent / widget.board.puzzle.size;
          _transform.value = Matrix4.identity()
            ..translateByDouble(
                (viewport.width / 2 - x).clamp(viewport.width - extent, 0),
                (viewport.height / 2 - y).clamp(viewport.height - extent, 0),
                0,
                1);
        }
        return Column(children: [
          Row(children: [
            const Expanded(
                child: Text('شبكة الكلمات',
                    style: TextStyle(color: GameColors.muted, fontSize: 13))),
            IconButton(
                tooltip: 'تصغير الشبكة',
                onPressed: () => _zoom(1 / 1.25, viewport, extent),
                icon: const Icon(Icons.zoom_out_rounded)),
            IconButton(
                tooltip: 'تكبير الشبكة',
                onPressed: () => _zoom(1.25, viewport, extent),
                icon: const Icon(Icons.zoom_in_rounded)),
            IconButton(
                tooltip: 'عرض الشبكة كاملة',
                onPressed: () => _move(Matrix4.identity()
                  ..translateByDouble((viewport.width - extent * fit) / 2,
                      (viewport.height - extent * fit) / 2, 0, 1)
                  ..scaleByDouble(fit, fit, 1, 1)),
                icon: const Icon(Icons.fit_screen_rounded)),
          ]),
          ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                  color: GameColors.border,
                  height: height,
                  width: box.maxWidth,
                  child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: InteractiveViewer(
                          key: const ValueKey('puzzle_zoom'),
                          transformationController: _transform,
                          onInteractionStart: (_) => _animation.stop(),
                          constrained: false,
                          minScale: fit,
                          maxScale: 2.5,
                          boundaryMargin: const EdgeInsets.all(160),
                          child: RepaintBoundary(
                              child: SizedBox(
                                  width: extent,
                                  height: extent,
                                  child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: widget.board))))))),
          const SizedBox(height: 5),
          const Text('اسحب الشبكة أو كبّرها لقراءة أريح',
              style: TextStyle(fontSize: 12, color: GameColors.muted)),
        ]);
      });
}
