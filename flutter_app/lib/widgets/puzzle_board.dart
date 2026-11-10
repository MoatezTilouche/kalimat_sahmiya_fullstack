import 'package:flutter/material.dart';
import '../models/puzzle.dart';
import '../theme.dart';

class PuzzleBoard extends StatefulWidget {
  const PuzzleBoard(
      {super.key,
      required this.puzzle,
      required this.answers,
      required this.solved,
      required this.selected,
      required this.onSelectWord,
      required this.onSelectCell,
      this.cursor,
      this.incorrect = const {}});
  final Puzzle puzzle;
  final Map<String, String> answers;
  final Set<String> solved, incorrect;
  final PuzzleWord? selected;
  final GridPosition? cursor;
  final ValueChanged<PuzzleWord> onSelectWord;
  final ValueChanged<GridPosition> onSelectCell;
  @override
  State<PuzzleBoard> createState() => _PuzzleBoardState();
}

class _PuzzleBoardState extends State<PuzzleBoard> {
  late Map<String, PuzzleWord> _byId;
  late Set<String> _crossings;
  final _cache = <int, (String, Widget)>{};
  @override
  void initState() {
    super.initState();
    _index();
  }

  @override
  void didUpdateWidget(PuzzleBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.puzzle, widget.puzzle)) _index();
  }

  void _index() {
    _byId = {for (final w in widget.puzzle.words) w.id: w};
    final counts = <String, int>{};
    for (final word in widget.puzzle.words) {
      for (final p in word.cells) {
        counts.update(p.key, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    _crossings = counts.keys.where((k) => counts[k]! > 1).toSet();
    _cache.clear();
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        widget.selected?.cells.map((p) => p.key).toSet() ?? <String>{};
    final solved = {
      for (final word
          in widget.puzzle.words.where((w) => widget.solved.contains(w.id)))
        ...word.cells.map((p) => p.key)
    };
    final wrong = {
      for (final word
          in widget.puzzle.words.where((w) => widget.incorrect.contains(w.id)))
        ...word.cells.map((p) => p.key)
    };
    return Directionality(
        textDirection: TextDirection.ltr,
        child: AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.puzzle.size,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3),
                itemCount: widget.puzzle.size * widget.puzzle.size,
                itemBuilder: (context, index) {
                  final r = index ~/ widget.puzzle.size,
                      c = index % widget.puzzle.size;
                  final point = GridPosition(r, c),
                      cell = widget.puzzle.cells[r][c];
                  final active = selected.contains(point.key),
                      cursor = widget.cursor?.key == point.key;
                  final done = solved.contains(point.key),
                      incorrect = wrong.contains(point.key) && !done;
                  final letter = widget.answers[point.key] ?? '';
                  // Reuse the actual widget instance for unaffected cells during rapid input.
                  final signature =
                      '${cell['type']}:$active:$cursor:$done:$incorrect:$letter:${widget.selected?.id}:${MediaQuery.textScalerOf(context).scale(1)}:${motionDuration(context).inMilliseconds}';
                  final old = _cache[index];
                  if (old?.$1 == signature) return old!.$2;
                  Widget child;
                  if (cell['type'] == 'block') {
                    child = DecoratedBox(
                        decoration: BoxDecoration(
                            color: GameColors.border.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(7)));
                  } else if (cell['type'] == 'clue') {
                    final word = _byId[cell['wordId']]!;
                    child = _ClueCell(
                        word: word,
                        selected: widget.selected?.id == word.id,
                        onTap: () => widget.onSelectWord(word));
                  } else {
                    child = _LetterCell(
                        key: ValueKey('cell_${point.key}'),
                        letter: letter,
                        active: active,
                        cursor: cursor,
                        solved: done,
                        incorrect: incorrect,
                        crossing: _crossings.contains(point.key),
                        onTap: () => widget.onSelectCell(point));
                  }
                  _cache[index] = (signature, child);
                  return child;
                })));
  }
}

class _ClueCell extends StatelessWidget {
  const _ClueCell(
      {required this.word, required this.selected, required this.onTap});
  final PuzzleWord word;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      label:
          '${word.clue}، ${word.direction == 'left' ? 'إلى اليسار' : 'إلى الأسفل'}',
      child: Tooltip(
          message: word.clue,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(7),
              child: AnimatedContainer(
                  duration: motionDuration(context, 160),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: selected ? GameColors.primary : GameColors.sand,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: selected
                              ? GameColors.primary
                              : const Color(0xFFD2C5AE))),
                  child: LayoutBuilder(builder: (context, box) {
                    final lines = ((box.maxHeight - 20) /
                            (MediaQuery.textScalerOf(context).scale(12) * 1.3))
                        .floor()
                        .clamp(1, 2);
                    return Column(children: [
                      Expanded(
                          child: Center(
                              child: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Text(
                                      word.clue.split(' ').take(3).join(' '),
                                      maxLines: lines,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1.3,
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? Colors.white
                                              : GameColors.navy))))),
                      SizedBox(
                          height: 18,
                          child: Icon(
                              word.direction == 'left'
                                  ? Icons.arrow_back_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 17,
                              color:
                                  selected ? Colors.white : GameColors.primary,
                              textDirection: TextDirection.ltr)),
                    ]);
                  })))));
}

class _LetterCell extends StatelessWidget {
  const _LetterCell(
      {super.key,
      required this.letter,
      required this.active,
      required this.cursor,
      required this.solved,
      required this.incorrect,
      required this.crossing,
      required this.onTap});
  final String letter;
  final bool active, cursor, solved, incorrect, crossing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: cursor,
      label:
          '${letter.isEmpty ? 'خانة حرف فارغة' : 'حرف $letter'}${solved ? '، مكتمل' : ''}${incorrect ? '، راجع الإجابة' : ''}',
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
              duration: motionDuration(context, 160),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: cursor
                      ? GameColors.primary
                      : solved
                          ? GameColors.success
                          : active
                              ? GameColors.selected
                              : GameColors.cell,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      width: cursor || active || incorrect ? 1.5 : 1,
                      color: incorrect
                          ? GameColors.error
                          : cursor || active
                              ? GameColors.primary
                              : solved
                                  ? GameColors.sage
                                  : GameColors.border)),
              child: Stack(alignment: Alignment.center, children: [
                if (crossing)
                  Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cursor
                                  ? GameColors.sage
                                  : GameColors.muted))),
                Text(letter,
                    style: TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: cursor ? Colors.white : GameColors.navy)),
              ]))));
}
