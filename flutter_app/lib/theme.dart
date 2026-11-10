import 'package:flutter/material.dart';
import 'models/puzzle.dart';

abstract final class GameColors {
  static const background = Color(0xFFF8F6F1);
  static const navy = Color(0xFF27332F);
  static const primary = Color(0xFF315C52);
  static const secondary = Color(0xFFB9AFD1);
  static const sage = Color(0xFFA8BFA3);
  static const mint = Color(0xFF3B6B54);
  static const gold = Color(0xFFC6A66C);
  static const muted = Color(0xFF63716A);
  static const border = Color(0xFFDDE2D9);
  static const cell = Color(0xFFFFFEFB);
  static const sand = Color(0xFFEDE4D4);
  static const sky = Color(0xFFD7E7ED);
  static const lavender = Color(0xFFEEEAF3);
  static const selected = Color(0xFFE5EDDF);
  static const success = Color(0xFFDCE9DA);
  static const error = Color(0xFF80545B);
  static const gradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0xFF294F46), Color(0xFF3C685B)]);
}

extension DifficultyStyle on GameDifficulty {
  Color get color => switch (this) {
        GameDifficulty.easy => GameColors.mint,
        GameDifficulty.medium => const Color(0xFF916B2E),
        GameDifficulty.hard => const Color(0xFF78566C),
      };
  IconData get icon => switch (this) {
        GameDifficulty.easy => Icons.spa_rounded,
        GameDifficulty.medium => Icons.explore_rounded,
        GameDifficulty.hard => Icons.auto_stories_rounded,
      };
}

Duration motionDuration(BuildContext context, [int milliseconds = 300]) =>
    MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.accessibleNavigationOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);

ThemeData gameTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoArabic',
      scaffoldBackgroundColor: GameColors.background,
      colorScheme: ColorScheme.fromSeed(
          seedColor: GameColors.primary,
          primary: GameColors.primary,
          onPrimary: Colors.white,
          secondary: GameColors.mint,
          tertiary: const Color(0xFF716184),
          surface: GameColors.cell,
          onSurface: GameColors.navy,
          error: GameColors.error,
          outline: GameColors.muted,
          outlineVariant: GameColors.border,
          surfaceContainerHighest: GameColors.selected),
      textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 32,
              height: 1.5,
              fontWeight: FontWeight.w800,
              color: GameColors.navy),
          headlineMedium: TextStyle(
              fontSize: 26,
              height: 1.5,
              fontWeight: FontWeight.w800,
              color: GameColors.navy),
          titleLarge: TextStyle(
              fontSize: 21,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: GameColors.navy),
          titleMedium: TextStyle(
              fontSize: 17,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: GameColors.navy),
          bodyLarge:
              TextStyle(fontSize: 17, height: 1.8, color: GameColors.navy),
          bodyMedium:
              TextStyle(fontSize: 15, height: 1.7, color: GameColors.navy),
          bodySmall:
              TextStyle(fontSize: 13, height: 1.7, color: GameColors.muted)),
      appBarTheme: const AppBarTheme(
          backgroundColor: GameColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: GameColors.navy,
          centerTitle: true),
      navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: GameColors.cell,
          indicatorColor: GameColors.selected,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 54),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(
                  fontFamily: 'NotoArabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w700))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: GameColors.border))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: GameColors.cell,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: GameColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: GameColors.border))),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: GameColors.background,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)))),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: GameColors.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      dividerColor: GameColors.border,
    );

class SoftPanel extends StatelessWidget {
  const SoftPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.color = GameColors.cell});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: padding,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GameColors.border)),
      child: child);
}
