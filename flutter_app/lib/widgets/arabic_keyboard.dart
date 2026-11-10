import 'package:flutter/material.dart';
import '../theme.dart';
import 'game_components.dart';

class ArabicKeyboard extends StatelessWidget {
  const ArabicKeyboard({super.key, required this.onLetter});
  final ValueChanged<String> onLetter;
  static const rows = [
    ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ'],
    ['ح', 'ج', 'د', 'ش', 'س', 'ي', 'ب', 'ل', 'ا'],
    ['ت', 'ن', 'م', 'ك', 'ط', 'ئ', 'ء', 'ؤ', 'ر'],
    ['ذ', 'ى', 'ة', 'و', 'ز', 'ظ', 'أ', 'إ', 'آ'],
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final letters = rows.expand((r) => r).toList();
        final glyphSize = MediaQuery.textScalerOf(context).scale(22);
        final keyWidth = (glyphSize * 1.3 + 12).clamp(44.0, 160.0);
        final columns =
            ((box.maxWidth - 10) / (keyWidth + 6)).floor().clamp(3, 9);
        final keyHeight = (glyphSize * 1.6).clamp(44.0, 160.0).toDouble();
        return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: GameColors.selected,
                borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var offset = 0; offset < letters.length; offset += columns)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      for (final letter in letters.skip(offset).take(columns))
                        Expanded(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: PressScale(
                                    onTap: () => onLetter(letter),
                                    label: 'حرف $letter',
                                    child: Container(
                                        constraints: BoxConstraints(
                                            minHeight: keyHeight),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                            color: GameColors.cell,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color:
                                                    const Color(0xFFCBD7C6))),
                                        child: Text(letter,
                                            style: const TextStyle(
                                                fontSize: 22,
                                                height: 1.25,
                                                fontWeight: FontWeight.w700,
                                                color: GameColors.navy)))))),
                      for (var i = letters.length - offset; i < columns; i++)
                        const Expanded(child: SizedBox()),
                    ])),
            ]));
      });
}
