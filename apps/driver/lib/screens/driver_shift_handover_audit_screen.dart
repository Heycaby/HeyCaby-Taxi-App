import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';

/// Staff-only audit list for Secure Shift Handover requests (Supabase RPC gated).
class DriverShiftHandoverAuditScreen extends ConsumerStatefulWidget {
  const DriverShiftHandoverAuditScreen({super.key});

  @override
  ConsumerState<DriverShiftHandoverAuditScreen> createState() =>
      _DriverShiftHandoverAuditScreenState();
}

class _DriverShiftHandoverAuditScreenState
    extends ConsumerState<DriverShiftHandoverAuditScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res =
        await ref.read(driverDataServiceProvider).fetchAdminShiftHandoverList();
    if (!mounted) return;
    if (res?['ok'] != true) {
      setState(() {
        _loading = false;
        _error = res?['error']?.toString() ?? 'not_authorized';
      });
      return;
    }
    final raw = res?['items'];
    final items = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) {
          items.add(Map<String, dynamic>.from(row));
        }
      }
    }
    setState(() {
      _loading = false;
      _items = items;
    });
  }

  String _formatTime(dynamic value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat('dd MMM yyyy HH:mm').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: DriverStrings.shiftHandoverAuditTitle,
        colors: colors,
        typography: typography,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/driver');
            }
          },
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.lg),
                    child: Text(
                      DriverStrings.shiftHandoverAuditForbidden,
                      textAlign: TextAlign.center,
                      style: typography.bodyLarge.copyWith(color: colors.error),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(DriverSpacing.lg),
                              child: Text(
                                DriverStrings.shiftHandoverAuditEmpty,
                                style: typography.bodyMedium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(DriverSpacing.md),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: DriverSpacing.sm),
                          itemBuilder: (_, index) {
                            final row = _items[index];
                            final plate = row['plate_display']?.toString() ??
                                row['plate_normalized']?.toString() ??
                                '—';
                            final status = row['status']?.toString() ?? '—';
                            final requester =
                                row['requesting_name']?.toString() ?? '—';
                            final current =
                                row['current_name']?.toString() ?? '—';
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(DriverSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plate,
                                      style: typography.titleSmall.copyWith(
                                        color: colors.text,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$status · ${_formatTime(row['requested_at'])}',
                                      style: typography.labelMedium.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: DriverSpacing.sm),
                                    Text(
                                      'Aanvrager: $requester',
                                      style: typography.bodySmall.copyWith(
                                        color: colors.text,
                                      ),
                                    ),
                                    Text(
                                      'Huidige chauffeur: $current',
                                      style: typography.bodySmall.copyWith(
                                        color: colors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
