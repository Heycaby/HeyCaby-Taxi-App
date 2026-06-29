import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';

/// Fleet manager: pick a shared taxi to manage its driver allowlist.
class DriverFleetAllowlistScreen extends ConsumerStatefulWidget {
  const DriverFleetAllowlistScreen({super.key});

  @override
  ConsumerState<DriverFleetAllowlistScreen> createState() =>
      _DriverFleetAllowlistScreenState();
}

class _DriverFleetAllowlistScreenState
    extends ConsumerState<DriverFleetAllowlistScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _vehicles = const [];

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
        await ref.read(driverDataServiceProvider).fetchFleetHandoverVehicles();
    if (!mounted) return;
    if (res?['ok'] != true) {
      setState(() {
        _loading = false;
        _error = res?['error']?.toString();
      });
      return;
    }
    final items = <Map<String, dynamic>>[];
    final raw = res?['items'];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map) items.add(Map<String, dynamic>.from(row));
      }
    }
    setState(() {
      _loading = false;
      _vehicles = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: DriverStrings.fleetAllowlistTitle,
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
          : RefreshIndicator(
              onRefresh: _load,
              child: _vehicles.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(DriverSpacing.lg),
                          child: Text(
                            _error != null
                                ? DriverStrings.fleetAllowlistForbidden
                                : DriverStrings.fleetAllowlistEmpty,
                            style: typography.bodyMedium.copyWith(
                              color: _error != null
                                  ? colors.error
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(DriverSpacing.md),
                      itemCount: _vehicles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: DriverSpacing.sm),
                      itemBuilder: (_, index) {
                        final v = _vehicles[index];
                        final plate = v['plate_display']?.toString() ??
                            v['plate_normalized']?.toString() ??
                            '—';
                        final count = v['allowlist_count'] as int? ?? 0;
                        final vehicleId = v['vehicle_id']?.toString() ?? '';
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: colors.border),
                          ),
                          tileColor: colors.surface,
                          title: Text(
                            plate,
                            style: typography.titleSmall.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            count == 0
                                ? DriverStrings.fleetAllowlistOpenFleet
                                : DriverStrings.fleetAllowlistDriverCount(
                                    count),
                            style: typography.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: vehicleId.isEmpty
                              ? null
                              : () => context.push(
                                    '/driver/fleet/allowlist/$vehicleId',
                                    extra: plate,
                                  ),
                        );
                      },
                    ),
            ),
    );
  }
}
