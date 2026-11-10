import 'package:flutter/material.dart';
import '../models/learning.dart';
import '../services/game_store.dart';
import '../theme.dart';
import '../widgets/knowledge_sheet.dart';
import '../widgets/game_components.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key, required this.store});
  final GameStore store;
  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  String _category = 'all';
  bool _loading = false;
  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.store.learning.refreshLibrary();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لا اتصال حالياً. بطاقاتك المحفوظة معك دائماً.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('رحلة المعرفة'), actions: [
        IconButton(
            onPressed: _loading ? null : _refresh,
            tooltip: 'جلب بطاقات جديدة',
            icon: const Icon(Icons.refresh_rounded))
      ]),
      body: ListenableBuilder(
          listenable: widget.store.learning,
          builder: (context, _) {
            final cards = widget.store.learning.library
                .where((c) => _category == 'all' || c.category == _category)
                .toList();
            return Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child:
                        ListView(padding: const EdgeInsets.all(22), children: [
                      const Entrance(
                          child: SoftPanel(
                              color: GameColors.lavender,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.auto_stories_rounded,
                                        size: 32, color: GameColors.primary),
                                    SizedBox(height: 14),
                                    Text('كل معنى، نافذة جديدة',
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 8),
                                    Text(
                                        'اقرأ على مهل. اكتشف تعريفات معجمية واحفظ ما تحب، دون أسئلة مفروضة أو وقت محدد.'),
                                  ]))),
                      const SizedBox(height: 20),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ChoiceChip(
                            label: const Text('الكل'),
                            selected: _category == 'all',
                            onSelected: (_) =>
                                setState(() => _category = 'all')),
                        for (final c in knowledgeCategories.entries)
                          ChoiceChip(
                              label: Text(c.value),
                              selected: _category == c.key,
                              onSelected: (_) =>
                                  setState(() => _category = c.key)),
                      ]),
                      const SizedBox(height: 20),
                      if (cards.isEmpty)
                        const SoftPanel(
                            child: Text(
                                'لم تُضف بطاقات موثقة لهذا التصنيف بعد. يمكنك استكشاف تعريفات اللغة العربية.')),
                      for (final card in cards)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => showKnowledge(
                                    context, widget.store, card: card),
                                child: SoftPanel(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(card.word,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium)),
                                        const Icon(Icons.auto_stories_rounded,
                                            color: GameColors.primary)
                                      ]),
                                      const SizedBox(height: 8),
                                      Text(card.definition),
                                      const SizedBox(height: 14),
                                      Text('المصدر: ${card.sourceName}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ])))),
                    ])));
          }));
}
