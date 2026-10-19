import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final mode = controller.mode;
          final system = mode == ThemeMode.system;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Preview(
                      label: 'Light',
                      dark: false,
                      selected: mode == ThemeMode.light,
                      dimmed: system,
                      accent: controller.accent,
                      onTap: () => controller.setMode(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Preview(
                      label: 'Dark',
                      dark: true,
                      selected: mode == ThemeMode.dark,
                      dimmed: system,
                      accent: controller.accent,
                      onTap: () => controller.setMode(ThemeMode.dark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                'Accent Color',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < AppTheme.accents.length; i++)
                    InkResponse(
                      onTap: () => controller.setAccentIndex(i),
                      child: Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == controller.accentIndex
                                ? AppTheme.accents[i]
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.accents[i],
                            shape: BoxShape.circle,
                          ),
                          child: i == controller.accentIndex
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Card(
                child: SwitchListTile(
                  title: const Text(
                    'System Default',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Follow your phone’s light or dark setting',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  value: system,
                  onChanged: (v) {
                    if (v) {
                      controller.setMode(ThemeMode.system);
                    } else {
                      final platformDark =
                          MediaQuery.platformBrightnessOf(context) ==
                              Brightness.dark;
                      controller.setMode(
                        platformDark ? ThemeMode.dark : ThemeMode.light,
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.label,
    required this.dark,
    required this.selected,
    required this.dimmed,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool dark;
  final bool selected;
  final bool dimmed;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = dark ? const Color(0xFF0F1A2E) : Colors.white;
    final bar = dark ? const Color(0xFF24344F) : const Color(0xFFE3EAF6);

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              height: 128,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: bar,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: bar,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
