import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../utils/driver_runtime_refresh.dart';
import '../screens/driver_runtime_gate_screen.dart';
import '../utils/driver_readiness_routes.dart';

/// Bottom sheet: progress toward going online, each missing step with a deep link.
Future<void> showDriverGoOnlineGuidanceSheet(
  BuildContext context,
  WidgetRef ref, {
  required DriverRuntimeGateArgs args,
}) async {
  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      final list = args.checklist;
      final missing = list.where((e) => !e.complete).toList();
      final total = list.length;
      final done = list.where((e) => e.complete).length;
      final pct = total == 0 ? 0 : ((done / total) * 100).round();
      final progress = total == 0 ? 0.0 : done / total;

      void bumpCaches() {
        ref.invalidate(driverComplianceProvider);
        ref.invalidate(driverProfileProvider);
        unawaited(refreshDriverRuntime(ref));
      }

      void openRoute(String route) {
        Navigator.of(ctx).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.push(route);
            bumpCaches();
          }
        });
      }

      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.text.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        args.title,
                        style: typo.titleLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: colors.border.withValues(alpha: 0.55),
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DriverStrings.goOnlineGuidanceProgress(pct),
                          style: typo.labelLarge.copyWith(
                            color: colors.textSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        args.body,
                        style: typo.bodyMedium.copyWith(
                          color: colors.textMid,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DriverStrings.goOnlineGuidanceSubtitle,
                        style: typo.bodySmall.copyWith(
                          color: colors.textSoft,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (missing.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.42,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: missing.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = missing[i];
                        final route = flutterRouteForReadinessItem(item);
                        return Material(
                          color: colors.bg.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: route == null
                                ? null
                                : () => openRoute(route),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.radio_button_unchecked,
                                        size: 20,
                                        color: colors.warning,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: typo.titleSmall.copyWith(
                                            color: colors.text,
                                            fontWeight: FontWeight.w700,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.note != null && item.note!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 30),
                                      child: Text(
                                        item.note!.trim(),
                                        style: typo.bodySmall.copyWith(
                                          color: colors.textMid,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (route != null) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.tonal(
                                        onPressed: () => openRoute(route),
                                        child: Text(DriverStrings.goOnlineGuidanceOpenAction),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else if (args.ctaLabel != null && args.ctaRoute != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: FilledButton(
                      onPressed: () => openRoute(args.ctaRoute!),
                      child: Text(args.ctaLabel!),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                context.push('/driver/documents');
                                bumpCaches();
                              }
                            });
                          },
                          child: Text(DriverStrings.goOnlineGuidanceViewAll),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(DriverStrings.goOnlineGuidanceClose),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
