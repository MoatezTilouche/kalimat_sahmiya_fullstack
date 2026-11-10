import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/learning.dart';
import '../models/puzzle.dart';
import '../services/game_store.dart';
import '../services/speech_service.dart';
import '../theme.dart';

Future<void> showKnowledge(BuildContext context, GameStore store,
        {LearnedWord? word, KnowledgeCard? card}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        sheetAnimationStyle: AnimationStyle(
            duration: motionDuration(context, 280),
            reverseDuration: motionDuration(context, 200)),
        builder: (context) =>
            KnowledgeSheet(store: store, word: word, card: card));

class PronunciationButton extends StatelessWidget {
  const PronunciationButton({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: 'نطق الكلمة',
      icon: const Icon(Icons.volume_up_rounded),
      onPressed: () async {
        final ok = await SpeechService().speak(text);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'لا يتوفر صوت عربي على هذا الجهاز. يمكنك متابعة القراءة.')));
        }
      });
}

class KnowledgeSheet extends StatefulWidget {
  const KnowledgeSheet({super.key, required this.store, this.word, this.card});
  final GameStore store;
  final LearnedWord? word;
  final KnowledgeCard? card;
  @override
  State<KnowledgeSheet> createState() => _KnowledgeSheetState();
}

class _KnowledgeSheetState extends State<KnowledgeSheet> {
  KnowledgeCard? _card;
  LearningQuiz? _quiz;
  int? _choice;
  bool _loadingQuiz = false, _expanded = false;
  String? _quizMessage;
  final _speech = SpeechService();
  @override
  void initState() {
    super.initState();
    _card = widget.card;
    unawaited(widget.store.learning.openedCard());
    if (_card == null && widget.word != null) {
      // Display the offline definition immediately, then enrich on this explicit action only.
      _card = widget.store.learning.fallback(widget.word!);
      widget.store.learning.cardFor(widget.word!).then((card) {
        if (mounted) setState(() => _card = card);
      });
    }
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    if (_loadingQuiz) return;
    setState(() {
      _loadingQuiz = true;
      _quizMessage = null;
    });
    try {
      final quiz = await widget.store.learning.quizFor(_card!);
      if (quiz.choices[quiz.correctIndex] != _card!.word ||
          quiz.question != _card!.definition) {
        throw const FormatException();
      }
      if (mounted) setState(() => _quiz = quiz);
    } catch (_) {
      if (mounted) {
        setState(() => _quizMessage =
            'لا يتوفر اختبار موثوق محفوظ لهذه الكلمة حالياً. استمتع بقراءة معناها.');
      }
    } finally {
      if (mounted) setState(() => _loadingQuiz = false);
    }
  }

  Future<void> _answer(int index) async {
    if (_choice != null) return;
    setState(() => _choice = index);
    final card = _card!;
    final key = wordKey(card.word, card.definition);
    if (widget.store.learning.word(key) == null) {
      await widget.store.learning.rememberCard(card);
    }
    await widget.store.learning
        .quizResult(_quiz!.id, key, index == _quiz!.correctIndex);
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    if (card == null) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('اختر كلمة للتعرّف إلى معناها.'));
    }
    return SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(children: [
                    Icon(Icons.auto_stories_rounded, color: GameColors.primary),
                    SizedBox(width: 10),
                    Text('هل تعلم؟',
                        style: TextStyle(
                            color: GameColors.primary,
                            fontWeight: FontWeight.w700))
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: Text(card.word,
                            style: Theme.of(context).textTheme.headlineLarge)),
                    PronunciationButton(text: card.word)
                  ]),
                  Text(knowledgeCategories[card.category] ?? 'اللغة العربية',
                      style: const TextStyle(color: GameColors.muted)),
                  const SizedBox(height: 20),
                  SoftPanel(
                      color: GameColors.sky.withValues(alpha: .5),
                      child: Text(card.definition,
                          style: Theme.of(context).textTheme.bodyLarge)),
                  if (card.fact != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SoftPanel(
                            color: GameColors.lavender,
                            child: Text(card.fact!))),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ListenableBuilder(
                        listenable: widget.store.learning,
                        builder: (context, _) {
                          final favorite = widget.store.learning
                                  .word(wordKey(card.word, card.definition))
                                  ?.favorite ??
                              false;
                          return OutlinedButton.icon(
                              onPressed: () =>
                                  widget.store.learning.rememberCard(card),
                              icon: Icon(favorite
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded),
                              label: Text(
                                  favorite ? 'في المفضلة' : 'أضف إلى قاموسي'));
                        }),
                    TextButton.icon(
                        onPressed: () async {
                          if (!await _speech.speak(card.definition) &&
                              context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'الصوت العربي غير متاح على هذا الجهاز.')));
                          }
                        },
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('استمع للمعنى')),
                    TextButton.icon(
                        onPressed: _speech.stop,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('إيقاف الصوت')),
                  ]),
                  TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child:
                          Text(_expanded ? 'عرض أقل' : 'اقرأ المزيد والمصدر')),
                  if (_expanded)
                    SoftPanel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          if (card.explanation != null) Text(card.explanation!),
                          Text('المصدر: ${card.sourceName}'),
                          Text(card.reviewStatus == 'reviewed'
                              ? 'بطاقة مراجعة تحريرياً'
                              : 'تعريف معجمي؛ لم تُضف حقيقة موسوعية غير موثقة.'),
                          if (card.sourceLicense != null)
                            Text('الترخيص: ${card.sourceLicense}'),
                          if (card.dataLicense != null)
                            Text('ترخيص بيانات المعجم: ${card.dataLicense}'),
                          if (card.sourceRef != null)
                            SelectableText(card.sourceRef!),
                          if (card.sourceUrl != null) ...[
                            const SizedBox(height: 8),
                            SelectableText(card.sourceUrl!,
                                textDirection: TextDirection.ltr),
                            TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: card.sourceUrl!));
                                },
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('نسخ رابط المصدر')),
                          ],
                        ])),
                  const SizedBox(height: 14),
                  if (_quiz == null)
                    OutlinedButton.icon(
                        onPressed: _loadingQuiz ? null : _loadQuiz,
                        icon: const Icon(Icons.psychology_alt_rounded),
                        label: Text(_loadingQuiz
                            ? 'نبحث عن اختبار موثوق…'
                            : 'اختبار اختياري · بلا ضغط')),
                  if (_quizMessage != null)
                    Text(_quizMessage!,
                        style: const TextStyle(color: GameColors.muted)),
                  if (_quiz != null)
                    SoftPanel(
                        color: GameColors.lavender,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(_quiz!.question),
                              Text(
                                  'تبدأ بحرف ${_quiz!.firstLetter} · ${arabicNumber(_quiz!.length)} حروف'),
                              for (var i = 0; i < 3; i++)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: OutlinedButton(
                                        onPressed: _choice == null
                                            ? () => _answer(i)
                                            : null,
                                        child: Text(_quiz!.choices[i]))),
                              if (_choice != null)
                                Text(_choice == _quiz!.correctIndex
                                    ? 'أحسنت، معنى جديد يرافقك!'
                                    : 'محاولة جميلة. الإجابة: ${_quiz!.choices[_quiz!.correctIndex]}'),
                            ])),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('متابعة اللعب')),
                ])));
  }
}
