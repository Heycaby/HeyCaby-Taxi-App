import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: colors.textSoft),
            const SizedBox(height: 16),
            Text(
              title,
              style: typo.titleMedium.copyWith(color: colors.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: typo.bodyMedium.copyWith(color: colors.textSoft),
            ),
          ],
        ),
      ),
    );
  }
}
