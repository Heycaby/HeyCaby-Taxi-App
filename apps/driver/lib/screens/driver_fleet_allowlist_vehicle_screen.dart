import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_button.dart';

/// Manage allowlisted drivers for one shared-fleet taxi.
class DriverFleetAllowlistVehicleScreen extends ConsumerStatefulWidget {
  const DriverFleetAllowlistVehicleScreen({
    super.key,
    required this.vehicleId,
    required this.plateDisplay,
  });

  final String vehicleId;
  final String plateDisplay;

  @override
  ConsumerState<DriverFleetAllowlistVehicleScreen> createState() =>
      _DriverFleetAllowlistVehicleScreenState();
}

class _DriverFleetAllowlistVehicleScreenState
    extends ConsumerState<DriverFleetAllowlistVehicleScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _drivers = const [];

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
    final res = await ref
        .read(driverDataServiceProvider)
        .fetchFleetHandoverAllowlist(widget.vehicleId);
    if (!mounted) return;
    if (res?['ok'] != true) {
      setState(() {
        _loading = false;
        _error = res?['error']?.toString() ?? 'forbidden';
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
      _drivers = items;
    });
  }

  Future<void> _remove(String driverId) async {
    final res =
        await ref.read(driverDataServiceProvider).setFleetHandoverAllowlist(
              vehicleId: widget.vehicleId,
              driverId: driverId,
              add: false,
            );
    if (!mounted) return;
    if (res?['ok'] == true) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(DriverStrings.fleetAllowlistUpdateFailed),
        ),
      );
    }
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDriverSheet(
        vehicleId: widget.vehicleId,
        onAdded: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: widget.plateDisplay,
        colors: colors,
        typography: typography,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/driver/fleet/allowlist');
            }
          },
        ),
      ),
      floatingActionButton: _error == null
          ? FloatingActionButton.extended(
              onPressed: _showAddSheet,
              icon: const Icon(LucideIcons.userPlus),
              label: const Text(DriverStrings.fleetAllowlistAddDriver),
            )
          : null,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.lg),
                    child: Text(
                      DriverStrings.fleetAllowlistForbidden,
                      style: typography.bodyLarge.copyWith(color: colors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      DriverSpacing.md,
                      DriverSpacing.md,
                      DriverSpacing.md,
                      96,
                    ),
                    children: [
                      Text(
                        DriverStrings.fleetAllowlistVehicleBody,
                        style: typography.bodyMedium.copyWith(
                          color: colors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: DriverSpacing.lg),
                      if (_drivers.isEmpty)
                        Text(
                          DriverStrings.fleetAllowlistOpenFleet,
                          style: typography.bodyMedium.copyWith(
                            color: colors.textMuted,
                          ),
                        )
                      else
                        ..._drivers.map((d) {
                          final id = d['driver_id']?.toString() ?? '';
                          final name =
                              d['display_name']?.toString() ?? 'Chauffeur';
                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: DriverSpacing.sm,
                            ),
                            child: ListTile(
                              title: Text(name),
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle_outline,
                                    color: colors.error),
                                onPressed:
                                    id.isEmpty ? null : () => _remove(id),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _AddDriverSheet extends ConsumerStatefulWidget {
  const _AddDriverSheet({
    required this.vehicleId,
    required this.onAdded,
  });

  final String vehicleId;
  final Future<void> Function() onAdded;

  @override
  ConsumerState<_AddDriverSheet> createState() => _AddDriverSheetState();
}

class _AddDriverSheetState extends ConsumerState<_AddDriverSheet> {
  final _queryController = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _results = const [];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryController.text.trim();
    if (q.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(DriverStrings.fleetAllowlistSearchHint),
        ),
      );
      return;
    }
    setState(() => _searching = true);
    final res = await ref
        .read(driverDataServiceProvider)
        .searchFleetHandoverDrivers(widget.vehicleId, q);
    if (!mounted) return;
    final items = <Map<String, dynamic>>[];
    if (res?['ok'] == true && res?['items'] is List) {
      for (final row in res!['items'] as List) {
        if (row is Map) items.add(Map<String, dynamic>.from(row));
      }
    }
    setState(() {
      _searching = false;
      _results = items;
    });
  }

  Future<void> _add(String driverId) async {
    final res =
        await ref.read(driverDataServiceProvider).setFleetHandoverAllowlist(
              vehicleId: widget.vehicleId,
              driverId: driverId,
              add: true,
            );
    if (!mounted) return;
    if (res?['ok'] == true) {
      Navigator.of(context).pop();
      await widget.onAdded();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(DriverStrings.fleetAllowlistUpdateFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: DriverSpacing.screenEdge,
          right: DriverSpacing.screenEdge,
          bottom: MediaQuery.viewInsetsOf(context).bottom + DriverSpacing.lg,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DriverSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DriverStrings.fleetAllowlistAddDriver,
                  style: typography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DriverSpacing.md),
                TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    labelText: DriverStrings.fleetAllowlistSearchLabel,
                    hintText: DriverStrings.fleetAllowlistSearchHint,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: DriverSpacing.md),
                DriverButton(
                  label: DriverStrings.fleetAllowlistSearchAction,
                  onPressed: _searching ? null : _search,
                  loading: _searching,
                  colors: colors,
                  typography: typography,
                  size: DriverButtonSize.lg,
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: DriverSpacing.lg),
                  ..._results.map((d) {
                    final id = d['driver_id']?.toString() ?? '';
                    final name = d['display_name']?.toString() ?? 'Chauffeur';
                    final email = d['email']?.toString() ?? '';
                    final photo = d['profile_photo_url']?.toString();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photo != null && photo.isNotEmpty
                            ? CachedNetworkImageProvider(photo)
                            : null,
                        child: photo == null || photo.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(name),
                      subtitle: email.isNotEmpty ? Text(email) : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: id.isEmpty ? null : () => _add(id),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
