import 'dart:async';
import 'package:flutter/material.dart';
import '../models/puzzle.dart';
import '../services/game_store.dart';
import '../theme.dart';
import '../widgets/game_components.dart';
import '../widgets/settings_sheet.dart';
import 'game_screen.dart';
import 'dictionary_screen.dart';
import 'knowledge_screen.dart';
import 'review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.store});
  final GameStore? store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _store = widget.store ?? GameStore.instance;
  int _unlocked = 1, _current = 1, _coins = 120, _downloaded = 0, _tab = 0;
  Set<int> _completed = {};
  GameDifficulty _chapter = GameDifficulty.easy;
  bool _syncing = false, _opening = false, _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final unlocked = await _store.unlockedLevel;
      final completed = await _store.completedLevels;
      final current = await _store.currentLevel;
      final coins = await _store.coins;
      final downloaded = await _store.cachedWordCount;
      if (!mounted) return;
      setState(() {
        _unlocked = unlocked;
        _completed = completed;
        _current = current;
        _coins = coins;
        _downloaded = downloaded;
        _loading = false;
        _error = null;
        _chapter = GameDifficulty.forLevel(unlocked);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر قراءة تقدمك. حاول مرة أخرى.';
        });
      }
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final count = await _store.syncWords(difficulty: _chapter);
      final downloaded = await _store.cachedWordCount;
      if (!mounted) return;
      setState(() => _downloaded = downloaded);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('أضفنا ${arabicNumber(count)} كلمة إلى المعجم المحفوظ')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                const Text('تعذر الاتصال. مستوياتك المحفوظة متاحة دون إنترنت.'),
            action: SnackBarAction(label: 'إعادة المحاولة', onPressed: _sync)));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openLevel(int level) async {
    if (level > _unlocked || _opening) return;
    setState(() => _opening = true);
    await Navigator.of(context)
        .push(gameRoute<void>(GameScreen(level: level, store: _store)));
    if (!mounted) return;
    await _refresh();
    if (mounted) setState(() => _opening = false);
  }

  void _about() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('كلمات سهمية'),
              content: const SingleChildScrollView(
                  child: Text('إلى أبي الغالي جوهر، بكل الحب والتقدير\n\n'
                      'ووردنت العربية 4.0 لصلاح عبده، المشتقة من ووردنت الإنجليزية المفتوحة وووردنت برنستون. ترخيص نسب المصنف 4.0.\n\n'
                      'بيانات التواتر: مختبر كامل، بترخيص نسب المصنف والترخيص بالمثل 4.0. الخط: نوتو العربية.\n\n'
                      'البطاقات تعرض التعريفات كما وردت في مصادرها. بعض التعريفات المستوردة لم تخضع لمراجعة تحريرية. لم تُولّد حقائق موسوعية أو إضافات آلية.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسناً'))
              ]));
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingView(message: 'نستعيد رحلتك…'));
    }
    if (_error != null) {
      return Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!),
        TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة'))
      ])));
    }
    return ListenableBuilder(
        listenable: _store.learning,
        builder: (context, _) => Scaffold(
            body: _tab == 2
                ? DictionaryScreen(store: _store, embedded: true)
                : _tab == 3
                    ? ReviewScreen(store: _store, embedded: true)
                    : _home(context),
            bottomNavigationBar: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'الرئيسية'),
                  NavigationDestination(
                      icon: Icon(Icons.explore_outlined),
                      selectedIcon: Icon(Icons.explore_rounded),
                      label: 'المستويات'),
                  NavigationDestination(
                      icon: Icon(Icons.menu_book_rounded), label: 'قاموسي'),
                  NavigationDestination(
                      icon: Icon(Icons.refresh_rounded), label: 'المراجعة'),
                ])));
  }

  Widget _home(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = width > 800 ? (width - 740) / 2 : 22.0;
    final total = _chapter.lastLevel ?? (_unlocked + 12).clamp(75, 999999);
    final count = total - _chapter.firstLevel + 1;
    final learned = _store.learning;
    return SafeArea(
        child: CustomScrollView(key: ValueKey('home_$_tab'), slivers: [
      SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, 16, inset, 0),
          sliver: SliverList.list(children: [
            Row(children: [
              const Icon(Icons.spa_rounded,
                  color: GameColors.primary, size: 30),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('كلمات سهمية',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  onPressed: () => showComfortSettings(context, _store),
                  tooltip: 'إعدادات الراحة',
                  icon: const Icon(Icons.tune_rounded))
            ]),
            if (_tab == 0) ...[
              const SizedBox(height: 24),
              const Entrance(
                  child: Text('مرحباً يا جوهر',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800))),
              const SizedBox(height: 6),
              const Text('خذ وقتك… لكل كلمة حكاية.',
                  style: TextStyle(color: GameColors.muted)),
              const SizedBox(height: 22),
              Entrance(
                  child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: GameColors.primary,
                          borderRadius: BorderRadius.circular(28)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(children: [
                              Icon(Icons.eco_rounded, color: GameColors.sage),
                              SizedBox(width: 10),
                              Expanded(
                                  child: Text('لحظة هادئة مع العربية',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 17)))
                            ]),
                            const SizedBox(height: 20),
                            Text('نواصل من المستوى ${arabicNumber(_current)}',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const SizedBox(height: 16),
                            GameProgress(
                                value: (_completed.length /
                                        _unlocked.clamp(75, 999999))
                                    .clamp(0, 1),
                                color: GameColors.sage,
                                dark: true),
                            const SizedBox(height: 10),
                            Text(
                                '${arabicNumber(_completed.length)} مستوى اكتمل في رحلتك',
                                style:
                                    const TextStyle(color: Color(0xFFE0EBDD))),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                                onPressed: _opening
                                    ? null
                                    : () => _openLevel(_current),
                                style: FilledButton.styleFrom(
                                    backgroundColor: GameColors.cell,
                                    foregroundColor: GameColors.primary),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(
                                    _opening ? 'نجهّز لغزك…' : 'العب الآن')),
                          ]))),
              const SizedBox(height: 18),
              Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CoinPill(coins: _coins),
                    _smallStat('كلمة اكتشفتها', learned.discovered),
                    _smallStat('جاهزة للمراجعة', learned.dueWords.length),
                  ]),
              const SizedBox(height: 26),
              _feature(
                  'رحلة المعرفة',
                  'معنى جديد، ونافذة أوسع',
                  Icons.auto_stories_rounded,
                  GameColors.lavender,
                  () => Navigator.push(context,
                      gameRoute<void>(KnowledgeScreen(store: _store)))),
              _feature(
                  'قاموس إنجازاتي',
                  'كل كلماتك في مكتبة تحبها',
                  Icons.menu_book_rounded,
                  GameColors.sand,
                  () => setState(() => _tab = 2)),
              _feature(
                  'راجع ما تعلمته',
                  'بضع كلمات، على مهل',
                  Icons.refresh_rounded,
                  GameColors.sky,
                  () => setState(() => _tab = 3)),
            ],
            const SizedBox(height: 28),
            Text('اختر محطتك', style: Theme.of(context).textTheme.titleLarge),
            const Text('تفتح المستويات بالتتابع، وتبقى رحلتك محفوظة.',
                style: TextStyle(color: GameColors.muted)),
            const SizedBox(height: 16),
            for (final difficulty in GameDifficulty.values)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ChapterCard(
                      difficulty: difficulty,
                      selected: _chapter == difficulty,
                      completed: _completed
                          .where(
                              (l) => GameDifficulty.forLevel(l) == difficulty)
                          .length,
                      onTap: () => setState(() => _chapter = difficulty))),
            const SizedBox(height: 14),
          ])),
      SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          sliver: SliverLayoutBuilder(builder: (context, constraints) {
            final columns =
                (constraints.crossAxisExtent / 95).floor().clamp(3, 7);
            return SliverGrid.builder(
                itemCount: count,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 98 *
                        MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10),
                itemBuilder: (context, i) {
                  final level = _chapter.firstLevel + i;
                  return LevelTile(
                      key: ValueKey('level_$level'),
                      level: level,
                      difficulty: _chapter,
                      completed: _completed.contains(level),
                      current: level == _unlocked,
                      locked: level > _unlocked,
                      onTap: () => _openLevel(level));
                });
          })),
      SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, 22, inset, 30),
          sliver: SliverList.list(children: [
            SoftPanel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  const Icon(Icons.offline_pin_rounded,
                      color: GameColors.primary),
                  const SizedBox(height: 8),
                  const Text('معك، حتى دون اتصال',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const Text('75 مستوى وبطاقات معرفة محفوظة داخل التطبيق.'),
                  Text('${arabicNumber(_downloaded)} كلمة إضافية محفوظة'),
                  TextButton.icon(
                      onPressed: _syncing ? null : _sync,
                      icon: const Icon(Icons.cloud_download_rounded),
                      label: Text(_syncing ? 'نضيف كلمات…' : 'توسيع المعجم')),
                ])),
            if (_tab == 0) ...[
              const SizedBox(height: 20),
              LearningStatsPanel(store: _store)
            ],
            const SizedBox(height: 18),
            TextButton(
                onPressed: _about,
                child: const Text('صُنعت بحب لجوهر · المصادر والتراخيص')),
          ])),
    ]));
  }

  Widget _smallStat(String label, int value) => SoftPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text('${arabicNumber(value)} $label',
          style: const TextStyle(fontSize: 13)));
  Widget _feature(String title, String subtitle, IconData icon, Color color,
          VoidCallback action) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(24),
              child: SoftPanel(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(16)),
                        child: Icon(icon, color: GameColors.primary)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 18)),
                          Text(subtitle,
                              style: const TextStyle(
                                  color: GameColors.muted, fontSize: 13))
                        ])),
                    const Icon(Icons.chevron_left_rounded,
                        color: GameColors.muted),
                  ]))));
}

class ChapterCard extends StatelessWidget {
  const ChapterCard(
      {super.key,
      required this.difficulty,
      required this.selected,
      required this.completed,
      required this.onTap});
  final GameDifficulty difficulty;
  final bool selected;
  final int completed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(
      onTap: onTap,
      label: difficulty.label,
      child: AnimatedContainer(
          duration: motionDuration(context, 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: selected ? GameColors.selected : GameColors.cell,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: selected ? difficulty.color : GameColors.border)),
          child: Row(children: [
            Icon(difficulty.icon, color: difficulty.color, size: 30),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(difficulty.subtitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 17)),
                  Text(
                      '${difficulty.label} · ${difficulty.lastLevel == null ? 'من المستوى 51' : '${arabicNumber(difficulty.firstLevel)}–${arabicNumber(difficulty.lastLevel!)}'}',
                      style: const TextStyle(
                          color: GameColors.muted, fontSize: 13))
                ])),
            if (completed > 0)
              Icon(Icons.check_circle_rounded, color: difficulty.color),
            Icon(
                selected
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_left_rounded,
                color: difficulty.color),
          ])));
}

class LevelTile extends StatelessWidget {
  const LevelTile(
      {super.key,
      required this.level,
      required this.difficulty,
      required this.completed,
      required this.current,
      required this.locked,
      required this.onTap,
      this.order = 0});
  final int level, order;
  final GameDifficulty difficulty;
  final bool completed, current, locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(
      onTap: locked ? null : onTap,
      label:
          'المستوى ${arabicNumber(level)}، ${locked ? 'مقفل' : completed ? 'مكتمل' : current ? 'التحدي الحالي' : 'متاح'}',
      child: AnimatedContainer(
          duration: motionDuration(context, 300),
          decoration: BoxDecoration(
              color: current
                  ? difficulty.color
                  : completed
                      ? GameColors.selected
                      : GameColors.cell,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: current ? difficulty.color : GameColors.border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
                completed
                    ? Icons.check_circle_rounded
                    : locked
                        ? Icons.lock_outline_rounded
                        : Icons.star_rounded,
                size: 20,
                color: current
                    ? Colors.white
                    : completed
                        ? difficulty.color
                        : GameColors.muted),
            const SizedBox(height: 5),
            Text(arabicNumber(level),
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: current
                        ? Colors.white
                        : locked
                            ? GameColors.muted
                            : difficulty.color)),
          ])));
}
