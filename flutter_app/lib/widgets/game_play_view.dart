import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/puzzle.dart';
import '../services/game_store.dart';
import '../theme.dart';
import 'game_components.dart';
import 'knowledge_sheet.dart';
import 'puzzle_board.dart';
import 'puzzle_viewport.dart';
import 'settings_sheet.dart';

class GamePlayView extends StatelessWidget {
  const GamePlayView(
      {super.key,
      required this.store,
      required this.puzzle,
      required this.answers,
      required this.solved,
      required this.incorrect,
      required this.selected,
      required this.cursor,
      required this.coins,
      required this.onBack,
      required this.onHint,
      required this.onErase,
      required this.onWord,
      required this.onCell,
      required this.keyboard,
      required this.completed,
      this.feedback,
      this.latestLearned,
      this.hinting = false});
  final GameStore store;
  final Puzzle puzzle;
  final Map<String, String> answers;
  final Set<String> solved, incorrect;
  final PuzzleWord? selected;
  final GridPosition? cursor;
  final int coins;
  final VoidCallback onBack, onHint, onErase;
  final ValueChanged<PuzzleWord> onWord;
  final ValueChanged<GridPosition> onCell;
  final Widget keyboard;
  final bool completed, hinting;
  final String? feedback, latestLearned;

  Widget _header(BuildContext context, bool focus) => Row(children: [
        IconButton(
            onPressed: onBack,
            tooltip: 'العودة إلى رحلتي',
            icon: const Icon(Icons.arrow_forward_rounded,
                textDirection: TextDirection.ltr)),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المستوى ${arabicNumber(puzzle.level)}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (!focus) DifficultyBadge(difficulty: puzzle.difficulty),
        ])),
        if (!focus && MediaQuery.sizeOf(context).width > 360)
          CoinPill(coins: coins),
        if (focus && latestLearned != null)
          IconButton(
              tooltip: 'رحلة المعرفة',
              icon: const Icon(Icons.auto_stories_rounded),
              onPressed: () {
                final word = store.learning.word(latestLearned!);
                if (word != null) showKnowledge(context, store, word: word);
              }),
        IconButton(
            onPressed: () => showComfortSettings(context, store),
            tooltip: 'إعدادات الراحة',
            icon: const Icon(Icons.tune_rounded)),
      ]);
  Widget _progress() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
            child: GameProgress(value: solved.length / puzzle.words.length)),
        const SizedBox(width: 14),
        Text(
            '${arabicNumber(solved.length)} / ${arabicNumber(puzzle.words.length)}',
            style: const TextStyle(color: GameColors.muted)),
      ]));
  Widget _clue(BuildContext context) => AnimatedSwitcher(
      duration: motionDuration(context, 220),
      child: SoftPanel(
          key: ValueKey(selected?.id),
          color: GameColors.sand.withValues(alpha: .65),
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Icon(
                    selected?.direction == 'left'
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_downward_rounded,
                    textDirection: TextDirection.ltr,
                    color: GameColors.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('السؤال الحالي',
                      style: TextStyle(fontSize: 13, color: GameColors.muted)),
                  const SizedBox(height: 5),
                  Text(selected?.clue ?? 'اختر سؤالاً من الشبكة',
                      style: const TextStyle(
                          fontSize: 18,
                          height: 1.65,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      '${arabicNumber(selected?.answer.length ?? 0)} حروف · ${selected?.direction == 'left' ? 'إلى اليسار' : 'إلى الأسفل'}',
                      style: const TextStyle(
                          fontSize: 12, color: GameColors.muted)),
                ])),
          ])));
  Widget _grid(double height) => PuzzleViewport(
      height: height,
      board: PuzzleBoard(
          puzzle: puzzle,
          answers: answers,
          solved: solved,
          incorrect: incorrect,
          selected: selected,
          cursor: cursor,
          onSelectWord: onWord,
          onSelectCell: onCell));
  Widget _controls() => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: onErase,
                icon: const Icon(Icons.backspace_outlined, size: 18),
                label: const Text('حذف'))),
        const SizedBox(width: 10),
        Expanded(
            child: FilledButton.icon(
                onPressed: hinting ? null : onHint,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: const Text('تلميح · 25'))),
      ]));
  List<Widget> _body(BuildContext context, bool focus) {
    final learned =
        latestLearned == null ? null : store.learning.word(latestLearned!);
    return [
      _header(context, focus),
      _progress(),
      _clue(context),
      const SizedBox(height: 8),
      _grid(300),
      if (feedback != null && !focus)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(feedback!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: GameColors.primary, fontWeight: FontWeight.w700))),
      if (learned != null && !focus)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Entrance(
                key: ValueKey(latestLearned),
                child: OutlinedButton.icon(
                    onPressed: () =>
                        showKnowledge(context, store, word: learned),
                    icon: const Icon(Icons.auto_stories_rounded),
                    label: Text(
                        'اكتشفت «${learned.answer}» · تعرّف إلى معناها')))),
      if (!focus)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
                completed ? 'مستوى مكتمل، أحسنت!' : 'كل حرف تكتبه يبقى محفوظاً',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: GameColors.muted))),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: store.learning,
      builder: (context, _) {
        final focus = store.learning.focusMode;
        final compact = MediaQuery.sizeOf(context).height < 740 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Scaffold(
            body: SafeArea(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: LayoutBuilder(builder: (context, box) {
                              if (focus && !compact && box.maxHeight >= 850) {
                                // Keep the clue and keyboard in place; only the readable grid pans.
                                return Column(children: [
                                  _header(context, true),
                                  _progress(),
                                  ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight: math.min(
                                              box.maxHeight * .19, 170.0)),
                                      child: SingleChildScrollView(
                                          child: _clue(context))),
                                  Expanded(
                                      child: LayoutBuilder(
                                          builder: (context, gridBox) =>
                                              gridBox.maxHeight < 160
                                                  ? SingleChildScrollView(
                                                      child: _grid(180))
                                                  : _grid(math.max(
                                                      80.0,
                                                      gridBox.maxHeight -
                                                          78)))),
                                  _controls(),
                                  keyboard,
                                  const SizedBox(height: 8),
                                ]);
                              }
                              final body = _body(context, focus);
                              return compact
                                  ? SingleChildScrollView(
                                      key: const PageStorageKey('game_scroll'),
                                      child: Column(children: [
                                        const SizedBox(height: 10),
                                        ...body,
                                        _controls(),
                                        keyboard,
                                        const SizedBox(height: 14)
                                      ]))
                                  : Column(children: [
                                      Expanded(
                                          child: SingleChildScrollView(
                                              child: Column(children: [
                                        const SizedBox(height: 10),
                                        ...body
                                      ]))),
                                      _controls(),
                                      keyboard,
                                      const SizedBox(height: 10)
                                    ]);
                            }))))));
      });
}
