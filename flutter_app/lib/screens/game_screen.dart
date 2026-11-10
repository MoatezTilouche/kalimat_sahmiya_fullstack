import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../models/puzzle.dart';
import '../services/game_store.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/arabic_keyboard.dart';
import '../widgets/game_components.dart';
import '../widgets/game_play_view.dart';
import '../models/learning.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level, this.store});
  final int level;
  final GameStore? store;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final _store = widget.store ?? GameStore.instance;
  Puzzle? _puzzle;
  Map<String, String> _answers = {};
  Set<String> _solved = {};
  String? _selectedId;
  int _cursor = 0;
  int _coins = 120;
  bool _isLoading = true;
  bool _wasCompleted = false;
  bool _showingVictory = false;
  String? _loadError;
  Future<void> _inputQueue = Future.value();
  bool _hinting = false;
  bool _canLeave = false;
  bool _leaving = false;
  String? _feedback;
  int _reward = 0;
  Set<String> _incorrect = {};
  String? _latestLearned;
  late final Widget _keyboard =
      ArabicKeyboard(onLetter: (letter) => _enqueue(() => _typeLetter(letter)));

  void _enqueue(Future<void> Function() input) {
    if (_leaving || _showingVictory) return;
    // Apply input before its first await; disk writes run through the store's queue.
    // Keeping a separate completion chain lets navigation wait for every save.
    final operation = input();
    _inputQueue = Future.wait<void>([_inputQueue, operation])
        .then<void>((_) {})
        .catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر حفظ آخر تغيير. يرجى إعادة المحاولة.')));
      }
    });
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _inputQueue;
    await _store.learning.flush();
    if (!mounted) return;
    setState(() => _canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && _puzzle != null) {
      _enqueue(() => _persist(completed: _wasCompleted));
    }
  }

  Future<void> _load() async {
    try {
      final puzzle = await _store.puzzleForLevel(widget.level);
      final saved = await _store.savedLevel(widget.level);
      final coins = await _store.coins;
      await _store.resumeAt(widget.level);
      await _store.learning.encounterPuzzle(puzzle);
      if (!mounted) return;
      setState(() {
        _puzzle = puzzle;
        _answers = saved.answers;
        _solved = saved.solved;
        _wasCompleted = saved.completed;
        _coins = coins;
        _selectedId = puzzle.words
            .firstWhere((w) => !_solved.contains(w.id),
                orElse: () => puzzle.words.first)
            .id;
        _cursor = 0;
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error is ApiException
              ? error.message
              : 'تعذر فتح هذا المستوى. يرجى إعادة المحاولة.';
          _isLoading = false;
        });
      }
    }
  }

  PuzzleWord? get _selectedWord {
    final puzzle = _puzzle;
    if (puzzle == null) return null;
    for (final word in puzzle.words) {
      if (word.id == _selectedId) return word;
    }
    return null;
  }

  int _firstEditableIndex(PuzzleWord word, {int from = 0}) {
    for (var i = from; i < word.cells.length; i++) {
      final point = word.cells[i];
      if (_answers[point.key] == null || _answers[point.key]!.isEmpty) return i;
    }
    return from < word.cells.length ? from : 0;
  }

  void _chooseWord(PuzzleWord word, {int? at}) {
    setState(() {
      _selectedId = word.id;
      _cursor = at ?? _firstEditableIndex(word);
    });
  }

  void _chooseCell(GridPosition point) {
    final puzzle = _puzzle!;
    final matches = puzzle.words
        .where((w) => w.cells.any((p) => p.key == point.key))
        .toList();
    if (matches.isEmpty) return;
    PuzzleWord chosen = matches.first;
    // A second tap on a crossing switches between its two answers.
    if (matches.length > 1 && selectedCellKey == point.key) {
      final alternatives =
          matches.where((w) => w.id != _selectedId && !_solved.contains(w.id));
      if (alternatives.isNotEmpty) chosen = alternatives.first;
    } else {
      for (final word in matches) {
        if (!_solved.contains(word.id) && word.id == _selectedId) {
          chosen = word;
          break;
        }
        if (!_solved.contains(word.id)) chosen = word;
      }
    }
    _chooseWord(chosen, at: chosen.cells.indexWhere((p) => p.key == point.key));
  }

  bool _lockedCell(GridPosition point) {
    for (final word in _puzzle!.words) {
      if (_solved.contains(word.id) &&
          word.cells.any((p) => p.key == point.key)) {
        return true;
      }
    }
    return false;
  }

  String? get selectedCellKey {
    final word = _selectedWord;
    return word == null
        ? null
        : word.cells[_cursor.clamp(0, word.cells.length - 1)].key;
  }

  Future<void> _persist({bool completed = false}) async {
    final awarded = await _store.saveLevel(widget.level, _answers, _solved,
        completed: completed);
    if (awarded && mounted) {
      setState(() {
        _coins += 60;
        _reward = 60;
      });
    }
  }

  void _selectNextWord() {
    final next = _puzzle!.words.where((w) => !_solved.contains(w.id));
    if (next.isNotEmpty) {
      final word = next.first;
      _selectedId = word.id;
      _cursor = _firstEditableIndex(word);
    }
  }

  bool _matches(PuzzleWord word) {
    final chars = word.answer.split('');
    return chars.length == word.cells.length &&
        List.generate(chars.length, (i) => i)
            .every((i) => _answers[word.cells[i].key] == chars[i]);
  }

  Future<void> _afterInput(PuzzleWord word) async {
    final full = word.cells.every((p) => (_answers[p.key] ?? '').isNotEmpty);
    final wrong = full && !_matches(word);
    setState(() {
      _incorrect = wrong ? {word.id} : {};
      if (wrong) _feedback = 'خذ وقتك، لعلّ حرفاً يحتاج إلى مراجعة.';
    });
    if (wrong) {
      await _store.learning.activity(word, widget.level, 'incorrect',
          uniqueId:
              'attempt:${widget.level}:${word.id}:${word.cells.map((p) => _answers[p.key] ?? '').join()}');
    }
    if (!mounted) return;
    final newlySolved = _puzzle!.words
        .where((w) => !_solved.contains(w.id) && _matches(w))
        .toList();
    if (newlySolved.isNotEmpty) {
      if (motionDuration(context) != Duration.zero) {
        unawaited(HapticFeedback.lightImpact());
      }
      setState(() {
        _solved.addAll(newlySolved.map((w) => w.id));
        _feedback = 'أحسنت! ${newlySolved.map((w) => w.answer).join('، ')}';
        if (_solved.contains(_selectedId)) _selectNextWord();
      });
      for (final learned in newlySolved) {
        await _store.learning.activity(learned, widget.level, 'solved');
      }
      if (mounted) {
        setState(() => _latestLearned =
            wordKey(newlySolved.last.answer, newlySolved.last.clue));
      }
    }
    final allSolved = _solved.length == _puzzle!.words.length;
    await _persist(completed: allSolved);
    if (allSolved && !_showingVictory && !_wasCompleted) {
      _showingVictory = true;
      _wasCompleted = true;
      if (mounted) _showVictory();
    }
  }

  Future<void> _typeLetter(String letter) async {
    if (!RegExp(r'^[\u0621-\u063A\u0641-\u064A]$').hasMatch(letter)) return;
    final word = _selectedWord;
    if (word == null || _solved.contains(word.id)) return;
    var index = _cursor.clamp(0, word.cells.length - 1).toInt();
    if (_lockedCell(word.cells[index])) {
      final candidates = <int>[
        for (var i = 0; i < word.cells.length; i++)
          if (!_lockedCell(word.cells[i])) i,
      ];
      if (candidates.isEmpty) return;
      index = candidates.first;
    }
    setState(() {
      _feedback = null;
      _answers[word.cells[index].key] = letter;
      _cursor = index;
      for (var i = index + 1; i < word.cells.length; i++) {
        if (!_lockedCell(word.cells[i])) {
          _cursor = i;
          break;
        }
      }
    });
    await _afterInput(word);
  }

  Future<void> _erase() async {
    final word = _selectedWord;
    if (word == null || _solved.contains(word.id)) return;
    var index = _cursor;
    if (_answers[word.cells[index].key]?.isEmpty ?? true) {
      index = index > 0 ? index - 1 : 0;
    }
    if (_lockedCell(word.cells[index])) return;
    setState(() {
      _answers.remove(word.cells[index].key);
      _cursor = index;
    });
    await _persist();
  }

  Future<void> _hint() async {
    final word = _selectedWord;
    if (word == null || _solved.contains(word.id) || _hinting) return;
    if (_coins < 25) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تحتاج إلى 25 قطعة ذهبية لاستخدام التلميح')));
      return;
    }
    final chars = word.answer.split('');
    var wrongIndex = -1;
    for (var i = 0; i < word.cells.length; i++) {
      if (_answers[word.cells[i].key] != chars[i]) {
        wrongIndex = i;
        break;
      }
    }
    if (wrongIndex == -1) {
      await _afterInput(word);
      return;
    }
    setState(() => _hinting = true);
    int? balance;
    try {
      balance = await _store.useHint(widget.level, _answers, _solved,
          word.cells[wrongIndex].key, chars[wrongIndex]);
    } finally {
      if (mounted) setState(() => _hinting = false);
    }
    if (balance == null || !mounted) return;
    await _store.learning.activity(word, widget.level, 'hint',
        uniqueId:
            'hint:${widget.level}:${word.id}:${word.cells[wrongIndex].key}:${DateTime.now().microsecondsSinceEpoch}');
    setState(() {
      _coins = balance!;
      _answers[word.cells[wrongIndex].key] = chars[wrongIndex];
      _cursor = (wrongIndex + 1).clamp(0, word.cells.length - 1).toInt();
    });
    await _afterInput(word);
  }

  void _showVictory() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
          canPop: false,
          child: VictoryDialog(
              level: widget.level,
              reward: _reward,
              onNext: () {
                Navigator.pop(dialogContext);
                Navigator.pushReplacement(
                    context,
                    gameRoute<void>(
                        GameScreen(level: widget.level + 1, store: _store)));
              },
              onHome: () {
                Navigator.pop(dialogContext);
                unawaited(_leave());
              })),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: LoadingView());
    if (_loadError != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('المستوى')),
          body: Center(
              child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 55, color: GameColors.primary),
              const SizedBox(height: 14),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                    });
                    _load();
                  },
                  child: const Text('إعادة المحاولة')),
            ]),
          )));
    }
    final puzzle = _puzzle!;
    final selected = _selectedWord;
    return PopScope(
        canPop: _canLeave,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_leave());
        },
        child: GamePlayView(
            store: _store,
            puzzle: puzzle,
            answers: _answers,
            solved: _solved,
            incorrect: _incorrect,
            selected: selected,
            cursor: selected == null
                ? null
                : selected.cells[_cursor.clamp(0, selected.cells.length - 1)],
            coins: _coins,
            onBack: () => unawaited(_leave()),
            onHint: () => _enqueue(_hint),
            onErase: () => _enqueue(_erase),
            onWord: _chooseWord,
            onCell: _chooseCell,
            keyboard: _keyboard,
            completed: _wasCompleted,
            feedback: _feedback,
            latestLearned: _latestLearned,
            hinting: _hinting));
  }
}
