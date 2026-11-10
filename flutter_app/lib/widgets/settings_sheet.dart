import 'package:flutter/material.dart';
import '../services/game_store.dart';
import '../screens/intro_screen.dart';
import '../theme.dart';

Future<void> showComfortSettings(BuildContext context, GameStore store) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => ListenableBuilder(
            listenable: store.learning,
            builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('على راحتك',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const Text('مساحتك الهادئة للتفكير والتعلّم',
                          style: TextStyle(color: GameColors.muted)),
                      const SizedBox(height: 22),
                      const Text('حجم الخط',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final choice in [
                          ('1', 'عادي'),
                          ('1.2', 'كبير'),
                          ('1.4', 'كبير جداً')
                        ])
                          ChoiceChip(
                              label: Text(choice.$2),
                              selected: store.learning.fontScale ==
                                  double.parse(choice.$1),
                              onSelected: (_) => store.learning
                                  .setPreference('font_scale', choice.$1))
                      ]),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('وضع التركيز'),
                          subtitle:
                              const Text('واجهة أبسط وحركة أقل أثناء اللعب'),
                          value: store.learning.focusMode,
                          onChanged: (v) =>
                              store.learning.setPreference('focus_mode', '$v')),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تقليل الحركة'),
                          subtitle:
                              const Text('انتقالات هادئة دون مؤثرات متحركة'),
                          value: store.learning.reducedMotion,
                          onChanged: (v) => store.learning
                              .setPreference('reduced_motion', '$v')),
                      const SizedBox(height: 12),
                      const Text('عدد كلمات المراجعة'),
                      Wrap(spacing: 8, children: [
                        for (final n in [5, 10, 15])
                          ChoiceChip(
                              label: Text(n == 5
                                  ? '5 كلمات'
                                  : n == 10
                                      ? '10 كلمات'
                                      : '15 كلمة'),
                              selected: store.learning.sessionSize == n,
                              onSelected: (_) => store.learning
                                  .setPreference('session_size', '$n'))
                      ]),
                      const Divider(height: 30),
                      TextButton.icon(
                          icon: const Icon(Icons.auto_stories_rounded),
                          label: const Text('عرض دليل البداية'),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (context) => IntroScreen(
                                    onStart: () async =>
                                        Navigator.pop(context))));
                          }),
                      FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('تم')),
                    ]))));
