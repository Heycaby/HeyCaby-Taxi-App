import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';

/// Shown on Home when profile is awaiting manual admin review.
class DriverVerificationStatusBanner extends ConsumerWidget {
  const DriverVerificationStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileProvider);
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return profileAsync.when(
      data: (p) {
        if (p == null) return const SizedBox.shrink();
        final ps = (p.profileStatus ?? '').toLowerCase();
        final pending = ps == 'pending_review' || ps == 'pending';
        if (!pending) return const SizedBox.shrink();

        return Material(
          color: colors.accentL,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => context.push('/driver/documents'),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_top_rounded, color: colors.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DriverStrings.verificationPendingTitle,
                          style: typo.labelLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DriverStrings.verificationPendingBody,
                          style: typo.bodySmall.copyWith(
                            color: colors.textSoft,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textSoft),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
