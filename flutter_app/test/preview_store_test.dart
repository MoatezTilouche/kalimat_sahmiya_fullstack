import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat_sahmiya/services/preview_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Edge preview plays bundled levels with temporary progress', () async {
    final store = PreviewStore();
    await store.init();
    final puzzle = await store.puzzleForLevel(1);
    expect(puzzle.level, 1);
    await store.markIntroSeen();
    final cell = puzzle.words.first.cells.first.key;
    final letter = puzzle.words.first.answer[0];
    expect(await store.useHint(1, {}, {}, cell, letter), 95);
    expect((await store.savedLevel(1)).answers[cell], letter);
    expect(await store.hintsUsed, 1);
    expect(await store.saveLevel(1, {cell: letter}, {}, completed: true), true);
    expect(
        await store.saveLevel(1, {cell: letter}, {}, completed: true), false);
    expect(await store.coins, 155);
    expect(await store.currentLevel, 2);
    final fresh = PreviewStore();
    expect(await fresh.coins, 120);
    expect(await fresh.hasSeenIntro, false);
    await store.close();
    await fresh.close();
  });
}
