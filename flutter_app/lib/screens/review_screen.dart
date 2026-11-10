import 'dart:async';
import 'package:flutter/material.dart';
import '../models/learning.dart';
import '../models/puzzle.dart';
import '../services/game_store.dart';
import '../theme.dart';
import '../widgets/game_components.dart';
import '../widgets/knowledge_sheet.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.store, this.embedded = false});
  final GameStore store;
  final bool embedded;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<LearnedWord>? _session;
  String? _sessionId;
  int _index = 0, _correct = 0;
  bool _completeWord = false,
      _answered = false,
      _right = false,
      _saving = false;
  String? _error;
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _start() {
    final due = widget.store.learning.dueWords;
    if (due.isEmpty) return;
    setState(() {
      _session = due.take(widget.store.learning.sessionSize).toList();
      _sessionId = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      _index = 0;
      _correct = 0;
      _answered = false;
      _error = null;
      _text.clear();
    });
  }

  List<String> _choices(LearnedWord word) {
    // Explicit spelling cue makes the three source-backed choices unambiguous.
    final others = widget.store.learning.words
        .map((w) => w.answer)
        .toSet()
        .where((a) => a != word.answer && !a.startsWith(word.answer[0]))
        .take(2)
        .toList();
    if (others.length < 2) return [];
    final choices = [word.answer, ...others]..sort();
    return choices;
  }

  Future<void> _answer(bool correct) async {
    if (_answered || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.learning
          .review(_session![_index].key, correct, _sessionId!);
      if (!mounted) return;
      setState(() {
        _answered = true;
        _right = correct;
        if (correct) _correct++;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر حفظ المراجعة. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _next() async {
    if (_saving) return;
    if (_index + 1 == _session!.length) {
      setState(() => _saving = true);
      try {
        await widget.store.learning.finishSession(_sessionId!);
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'تعذر حفظ ملخص الجلسة. حاول مرة أخرى.');
        }
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
    if (mounted) {
      setState(() {
        _index++;
        _answered = false;
        _text.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar:
          widget.embedded ? null : AppBar(title: const Text('راجع ما تعلمته')),
      body: ListenableBuilder(
          listenable: widget.store.learning,
          builder: (context, _) {
            final learning = widget.store.learning;
            final done = _session != null && _index >= _session!.length;
            final word = _session != null && !done ? _session![_index] : null;
            final choices = word == null ? <String>[] : _choices(word);
            final fill = _completeWord || choices.isEmpty;
            return Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      Text('راجع ما تعلمته',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const Text(
                          'بضع كلمات، على مهل. لا وقت محدد ولا نقاط تخسرها.'),
                      const SizedBox(height: 22),
                      if (_session == null) ...[
                        SoftPanel(
                            color: GameColors.selected,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Icon(Icons.spa_rounded,
                                      size: 42, color: GameColors.primary),
                                  const SizedBox(height: 12),
                                  Text(
                                      '${arabicNumber(learning.dueWords.length)} كلمة جاهزة للمراجعة',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'مراجعات قصيرة بفواصل 1، 3، 7، 14، ثم 30 يوماً. عد متى أحببت.',
                                      textAlign: TextAlign.center),
                                ])),
                        const SizedBox(height: 18),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          ChoiceChip(
                              label: const Text('تذكّر المعنى'),
                              selected: !_completeWord,
                              onSelected: (_) =>
                                  setState(() => _completeWord = false)),
                          ChoiceChip(
                              label: const Text('أكمل الكلمة'),
                              selected: _completeWord,
                              onSelected: (_) =>
                                  setState(() => _completeWord = true)),
                        ]),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                            onPressed:
                                learning.dueWords.isEmpty ? null : _start,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                                'ابدأ جلسة · ${arabicNumber(learning.sessionSize)} كلمات')),
                        if (learning.dueWords.isEmpty)
                          const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                  'لا توجد كلمات مستحقة الآن. استكشف لغزاً جديداً أو استرح قليلاً.')),
                        const SizedBox(height: 26),
                        LearningStatsPanel(store: widget.store),
                      ] else if (done) ...[
                        const Entrance(
                            child: Icon(Icons.local_florist_rounded,
                                size: 76, color: GameColors.primary)),
                        const SizedBox(height: 20),
                        Text('خطوة جميلة في رحلتك',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Text(
                            'تذكّرت ${arabicNumber(_correct)} من ${arabicNumber(_session!.length)} كلمات. حفظنا موعد مراجعتك القادمة.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 22),
                        FilledButton(
                            onPressed: () => setState(() => _session = null),
                            child: const Text('تم، إلى لقاء هادئ آخر')),
                        const SizedBox(height: 24),
                        LearningStatsPanel(store: widget.store),
                      ] else ...[
                        GameProgress(value: _index / _session!.length),
                        const SizedBox(height: 12),
                        Text(
                            '${arabicNumber(_index + 1)} من ${arabicNumber(_session!.length)}',
                            style: const TextStyle(color: GameColors.muted)),
                        const SizedBox(height: 18),
                        SoftPanel(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Text(
                                  fill
                                      ? 'أكمل الكلمة'
                                      : 'أي كلمة توافق هذا المعنى؟',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              Text(
                                  word!.definition.isEmpty
                                      ? word.clue
                                      : word.definition,
                                  style: Theme.of(context).textTheme.bodyLarge),
                              const SizedBox(height: 10),
                              Text(
                                  'تبدأ بحرف ${word.answer[0]} · ${arabicNumber(word.answer.length)} حروف'),
                              const SizedBox(height: 18),
                              if (fill) ...[
                                Text(
                                    [
                                      for (var i = 0;
                                          i < word.answer.length;
                                          i++)
                                        i.isEven ? word.answer[i] : 'ـ'
                                    ].join('  '),
                                    style: const TextStyle(
                                        fontSize: 30, letterSpacing: 2),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                TextField(
                                    controller: _text,
                                    enabled: !_answered && !_saving,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                        labelText: 'اكتب الكلمة كاملة'),
                                    onSubmitted: (_) => unawaited(_answer(
                                        normalizeAnswer(_text.text) ==
                                            normalizeAnswer(word.answer)))),
                                const SizedBox(height: 12),
                                FilledButton(
                                    onPressed: _answered || _saving
                                        ? null
                                        : () => _answer(
                                            normalizeAnswer(_text.text) ==
                                                normalizeAnswer(word.answer)),
                                    child: const Text('تحقّق بهدوء')),
                              ] else
                                for (final choice in choices)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: OutlinedButton(
                                          onPressed: _answered || _saving
                                              ? null
                                              : () => _answer(
                                                  choice == word.answer),
                                          child: Text(choice))),
                              if (_answered) ...[
                                const SizedBox(height: 16),
                                Text(
                                    _right
                                        ? 'أحسنت، ما زالت في الذاكرة!'
                                        : 'لا بأس، نتعلم بالتكرار. الإجابة: ${word.answer}',
                                    style: const TextStyle(
                                        color: GameColors.primary,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                PronunciationButton(text: word.answer),
                                FilledButton(
                                    onPressed: _saving ? null : _next,
                                    child: Text(_index + 1 == _session!.length
                                        ? 'ملخص الجلسة'
                                        : 'الكلمة التالية')),
                              ],
                            ])),
                        TextButton(
                            onPressed: () => setState(() => _session = null),
                            child: const Text('نكمل لاحقاً')),
                      ],
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: GameColors.error)),
                    ])));
          }));
}

class LearningStatsPanel extends StatelessWidget {
  const LearningStatsPanel({super.key, required this.store});
  final GameStore store;
  @override
  Widget build(BuildContext context) {
    final learning = store.learning;
    return SoftPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('رحلتك في التعلّم', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      Wrap(spacing: 16, runSpacing: 14, children: [
        _stat('كلمة اكتشفتها', learning.discovered),
        _stat('كلمة أتقنتها', learning.mastered),
        _stat('مراجعة', learning.reviewCount),
        _stat('تصنيف استكشفته', learning.exploredCategories),
        _stat('جلسة مكتملة', learning.sessions),
      ]),
      const SizedBox(height: 14),
      Text(learning.reviewCount == 0
          ? 'أول مراجعة هي بداية الحكاية'
          : 'دقة المراجعة ${arabicNumber((learning.accuracy * 100).round())}٪'),
      if (learning.words.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
            'من كلماتك الأخيرة: ${(learning.words.toList()..sort((a, b) => b.firstLearned.compareTo(a.firstLearned))).take(3).map((w) => w.answer).join('، ')}'),
      ],
      const Divider(height: 30),
      const Text('إنجازاتك الصغيرة',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      for (final badge in learning.achievements)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              AnimatedSwitcher(
                  duration: motionDuration(context, 300),
                  child: Icon(
                      badge.unlocked
                          ? Icons.workspace_premium_rounded
                          : Icons.eco_rounded,
                      key: ValueKey('${badge.label}${badge.unlocked}'),
                      color: badge.unlocked
                          ? const Color(0xFF95743E)
                          : GameColors.muted)),
              const SizedBox(width: 12),
              Expanded(child: Text(badge.label)),
              Text(
                  badge.unlocked
                      ? 'اكتمل'
                      : '${arabicNumber(badge.value)} / ${arabicNumber(badge.target)}',
                  style: const TextStyle(color: GameColors.muted)),
            ])),
    ]));
  }

  Widget _stat(String label, int value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(arabicNumber(value),
            style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: GameColors.primary)),
        Text(label),
      ]);
}
