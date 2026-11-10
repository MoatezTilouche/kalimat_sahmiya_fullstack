import 'package:flutter/material.dart';
import '../models/learning.dart';
import '../models/puzzle.dart';
import '../services/game_store.dart';
import '../theme.dart';
import '../widgets/game_components.dart';
import '../widgets/knowledge_sheet.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen(
      {super.key, required this.store, this.embedded = false});
  final GameStore store;
  final bool embedded;
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  String _query = '', _order = 'recent', _category = 'all', _difficulty = 'all';
  bool _favorites = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store.learning,
      builder: (context, _) {
        final learning = widget.store.learning;
        final due = learning.dueWords.map((w) => w.key).toSet();
        final words = learning.words
            .where((w) =>
                (normalizeArabic(w.answer).contains(normalizeArabic(_query)) ||
                    normalizeArabic(w.definition)
                        .contains(normalizeArabic(_query))) &&
                (!_favorites || w.favorite) &&
                (_category == 'all' || w.category == _category) &&
                (_difficulty == 'all' || w.difficulty.code == _difficulty) &&
                (_order != 'mastered' || w.mastered) &&
                (_order != 'review' || due.contains(w.key)))
            .toList();
        words.sort((a, b) => _order == 'alphabetical'
            ? a.answer.compareTo(b.answer)
            : b.firstLearned.compareTo(a.firstLearned));
        return Scaffold(
            appBar: widget.embedded
                ? null
                : AppBar(title: const Text('قاموس إنجازاتي')),
            body: SafeArea(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: CustomScrollView(slivers: [
                          SliverPadding(
                              padding: const EdgeInsets.all(22),
                              sliver: SliverList.list(children: [
                                Text('قاموس إنجازاتي',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                const Text('مكتبتك الصغيرة، تكبر مع كل كلمة'),
                                const SizedBox(height: 20),
                                TextField(
                                    onChanged: (v) =>
                                        setState(() => _query = v),
                                    decoration: const InputDecoration(
                                        hintText: 'ابحث عن كلمة أو معنى',
                                        prefixIcon:
                                            Icon(Icons.search_rounded))),
                                const SizedBox(height: 14),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  FilterChip(
                                      selected: _favorites,
                                      label: const Text('المفضلة'),
                                      avatar: const Icon(Icons.bookmark_rounded,
                                          size: 18),
                                      onSelected: (v) =>
                                          setState(() => _favorites = v)),
                                  for (final option in [
                                    ('recent', 'الأحدث'),
                                    ('alphabetical', 'أبجدياً'),
                                    ('mastered', 'أتقنتها'),
                                    ('review', 'تحتاج مراجعة')
                                  ])
                                    ChoiceChip(
                                        selected: _order == option.$1,
                                        label: Text(option.$2),
                                        onSelected: (_) =>
                                            setState(() => _order = option.$1)),
                                ]),
                                const SizedBox(height: 12),
                                Wrap(spacing: 12, runSpacing: 8, children: [
                                  DropdownButton<String>(
                                      value: _difficulty,
                                      underline: const SizedBox(),
                                      items: [
                                        const DropdownMenuItem(
                                            value: 'all',
                                            child: Text('كل الصعوبات')),
                                        for (final d in GameDifficulty.values)
                                          DropdownMenuItem(
                                              value: d.code,
                                              child: Text(d.label))
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _difficulty = v!)),
                                  DropdownButton<String>(
                                      value: _category,
                                      underline: const SizedBox(),
                                      items: [
                                        const DropdownMenuItem(
                                            value: 'all',
                                            child: Text('كل التصنيفات')),
                                        for (final c
                                            in knowledgeCategories.entries)
                                          DropdownMenuItem(
                                              value: c.key,
                                              child: Text(c.value))
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _category = v!)),
                                ]),
                                const SizedBox(height: 10),
                                Text(
                                    '${arabicNumber(words.length)} كلمة · ${arabicNumber(learning.mastered)} كلمة أتقنتها',
                                    style: const TextStyle(
                                        color: GameColors.muted)),
                              ])),
                          if (words.isEmpty)
                            const SliverToBoxAdapter(
                                child: Padding(
                                    padding: EdgeInsets.all(30),
                                    child: SoftPanel(
                                        child: Column(children: [
                                      Icon(Icons.menu_book_rounded,
                                          size: 48, color: GameColors.primary),
                                      SizedBox(height: 16),
                                      Text('كل كلمة بداية جديدة',
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700)),
                                      SizedBox(height: 8),
                                      Text(
                                          'ستجد هنا الكلمات التي تصادفها في الألغاز، ويمكنك إضافة بطاقات من رحلة المعرفة.',
                                          textAlign: TextAlign.center)
                                    ])))),
                          SliverPadding(
                              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                              sliver: SliverList.builder(
                                  itemCount: words.length,
                                  itemBuilder: (context, i) {
                                    final word = words[i];
                                    return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: WordLibraryCard(
                                            word: word,
                                            onOpen: () => showKnowledge(
                                                context, widget.store,
                                                word: word),
                                            onFavorite: () =>
                                                learning.favorite(word.key),
                                            due: due.contains(word.key)));
                                  })),
                          const SliverPadding(
                              padding: EdgeInsets.only(bottom: 20)),
                        ])))));
      });
}

class WordLibraryCard extends StatelessWidget {
  const WordLibraryCard(
      {super.key,
      required this.word,
      required this.onOpen,
      required this.onFavorite,
      this.due = false});
  final LearnedWord word;
  final VoidCallback onOpen, onFavorite;
  final bool due;
  @override
  Widget build(BuildContext context) => SoftPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: InkWell(
                  onTap: onOpen,
                  child: Text(word.answer,
                      style: Theme.of(context).textTheme.headlineMedium))),
          PronunciationButton(text: word.answer),
          IconButton(
              tooltip: word.favorite ? 'إزالة من المفضلة' : 'أضف إلى المفضلة',
              onPressed: onFavorite,
              icon: Icon(
                  word.favorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: GameColors.primary))
        ]),
        const SizedBox(height: 6),
        Text(word.definition.isEmpty ? word.clue : word.definition),
        const SizedBox(height: 12),
        Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DifficultyBadge(difficulty: word.difficulty),
              Text(knowledgeCategories[word.category] ?? 'اللغة العربية',
                  style: const TextStyle(color: GameColors.muted)),
              if (word.mastered)
                const Icon(Icons.verified_rounded,
                    size: 19, color: GameColors.mint),
              if (due)
                const Text('جاهزة للمراجعة',
                    style: TextStyle(color: GameColors.primary)),
              TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: const Text('اكتشف المعنى')),
            ]),
      ]));
}
