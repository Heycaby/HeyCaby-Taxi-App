import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/booking_draft_provider.dart';
import '../providers/booking_provider.dart';
import '../services/booking_draft_storage.dart';

/// Home sheet: continue a booking saved from the trip summary.
class BookingDraftResumeCard extends ConsumerWidget {
  const BookingDraftResumeCard({super.key});

  static bool _canGoToSummary(BookingState b) {
    return b.pickup != null &&
        b.destination != null &&
        (b.vehicleCategory != null && b.vehicleCategory!.isNotEmpty) &&
        b.paymentMethods.isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(bookingDraftProvider);
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    return draftAsync.when(
      data: (draft) {
        if (draft == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                ref.read(bookingProvider.notifier).restoreFromDraft(draft);
                await BookingDraftStorage.clear();
                ref.invalidate(bookingDraftProvider);
                if (!context.mounted) return;
                if (_canGoToSummary(draft)) {
                  context.push('/summary');
                } else if (draft.pickup != null && draft.destination != null) {
                  context.push('/vehicle-category');
                } else {
                  context.push('/search');
                }
              },
              child: Ink(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.45)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_rounded, color: colors.accent, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.continueSavedBooking,
                              style: typo.titleSmall.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.continueSavedBookingHint,
                              style: typo.bodySmall.copyWith(
                                color: colors.textMid,
                                height: 1.4,
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
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
