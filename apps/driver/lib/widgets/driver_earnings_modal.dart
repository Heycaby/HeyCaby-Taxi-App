import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import 'driver_earnings_modal_parts.dart';

/// Rate Command Center - V6: Ultra Clean Edition
/// Design philosophy: Minimal, focused, purposeful
/// - Only shows today's earnings
/// - Shows active tariff name
/// - Tap tariff for details
/// - Edit takes you to dedicated tariff screen
class DriverEarningsModal extends ConsumerStatefulWidget {
  const DriverEarningsModal({
    super.key,
    required this.todayEarnings,
    required this.zoneName,
    required this.statusKind,
    required this.colors,
    required this.typo,
    required this.onDismiss,
    required this.onTakeBreak,
    required this.onEndShift,
    required this.onResume,
  });

  final String todayEarnings;
  final String zoneName;
  final DriverStatusKind statusKind;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onDismiss;
  final VoidCallback onTakeBreak;
  final VoidCallback onEndShift;
  final VoidCallback onResume;

  @override
  ConsumerState<DriverEarningsModal> createState() =>
      _DriverEarningsModalState();
}

class _DriverEarningsModalState extends ConsumerState<DriverEarningsModal> {
  bool _amountVisible = true;
  double? _swipeStartY;
  bool _swipeDismissed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final displayAmount = _amountVisible ? widget.todayEarnings : '••••••';
    final statusCol = statusColor(widget.statusKind, colors);
    final statusLabel = widget.statusKind == DriverStatusKind.online
        ? DriverStrings.online
        : widget.statusKind == DriverStatusKind.onBreak
            ? DriverStrings.onBreak
            : DriverStrings.offline;
    final activeAsync = ref.watch(activeRateProfileProvider);
    final activeProfile = activeAsync.valueOrNull;
    final profilesAsync = ref.watch(driverRateProfilesProvider);
    final profiles = profilesAsync.valueOrNull ?? [];
    final driverIdAsync = ref.watch(driverIdProvider);
    final driverId = driverIdAsync.valueOrNull;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Backdrop
          Positioned.fill(
            child: Container(
              color: colors.bg.withValues(alpha: 0.6),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            DriverStrings.today,
                            style: typo.titleSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              _amountVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: colors.textSoft,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _amountVisible = !_amountVisible,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: colors.textSoft, size: 22),
                            onPressed: widget.onDismiss,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    
                    // Earnings - Large and clean
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _amountVisible = !_amountVisible;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          displayAmount,
                          style: typo.headingLarge.copyWith(
                            color: colors.text,
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),
                    ),
                    
                    // Status line
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusCol,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusLabel,
                            style: typo.bodySmall.copyWith(
                              color: statusCol,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ' · ${widget.zoneName}',
                            style: typo.bodySmall.copyWith(
                              color: colors.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    
                    // Active Tariff - Clean and simple
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showTariffDetails(context, activeProfile, colors, typo),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: colors.accent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DriverStrings.editTariffs,
                                      style: typo.labelSmall.copyWith(
                                        color: colors.textSoft,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      activeProfile?.profileName ??
                                          DriverStrings.standardTariff,
                                      style: typo.bodyMedium.copyWith(
                                        color: colors.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: colors.textSoft,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Quick Tariff Switcher - Horizontal chips
                    if (profiles.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: profiles.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final p = profiles[index];
                              final isActive = p.id == activeProfile?.id;
                              return GestureDetector(
                                onTap: isActive
                                    ? null
                                    : () async {
                                        debugPrint('Tapped tariff: ${p.profileName}, id: ${p.id}');
                                        debugPrint('driverId: $driverId');
                                        if (driverId == null) {
                                          debugPrint('ERROR: driverId is null!');
                                          return;
                                        }
                                        debugPrint('Switching to profile ${p.id}...');
                                        final ok = await ref
                                            .read(driverDataServiceProvider)
                                            .switchRateProfile(driverId, p.id);
                                        debugPrint('Switch result: $ok');
                                        if (ok) {
                                          ref.invalidate(driverRateProfilesProvider);
                                          ref.invalidate(activeRateProfileProvider);
                                          debugPrint('Providers invalidated');
                                        }
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isActive ? colors.accent : colors.card,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isActive ? Colors.transparent : colors.border.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isActive) ...[
                                        Icon(
                                          Icons.check,
                                          size: 14,
                                          color: colors.onAccent,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        p.profileName,
                                        style: typo.labelSmall.copyWith(
                                          color: isActive ? colors.onAccent : colors.text,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    SizedBox(height: 8 + MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show tariff details in a small bottom sheet
  void _showTariffDetails(BuildContext context, DriverRateProfile? profile,
      HeyCabyColorTokens colors, HeyCabyTypography typo) {
    final profilesAsync = ref.read(driverRateProfilesProvider);
    final profiles = profilesAsync.valueOrNull ?? [];
    final driverIdAsync = ref.read(driverIdProvider);
    final driverId = driverIdAsync.valueOrNull;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TariffDetailsSheet(
        profile: profile,
        profiles: profiles,
        driverId: driverId,
        colors: colors,
        typo: typo,
        onEdit: () {
          Navigator.pop(context);
          widget.onDismiss();
          context.push('/driver/tariffs');
        },
        onSwitchProfile: (profileId) async {
          if (driverId == null) return;
          final ok = await ref
              .read(driverDataServiceProvider)
              .switchRateProfile(driverId, profileId);
          if (ok) {
            ref.invalidate(driverRateProfilesProvider);
            ref.invalidate(activeRateProfileProvider);
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        },
      ),
    );
  }
}

/// Tariff Details Sheet - Shows rate breakdown and allows tariff switching
class _TariffDetailsSheet extends StatefulWidget {
  final DriverRateProfile? profile;
  final List<DriverRateProfile> profiles;
  final String? driverId;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onEdit;
  final Function(String profileId) onSwitchProfile;

  const _TariffDetailsSheet({
    required this.profile,
    required this.profiles,
    required this.driverId,
    required this.colors,
    required this.typo,
    required this.onEdit,
    required this.onSwitchProfile,
  });

  @override
  State<_TariffDetailsSheet> createState() => _TariffDetailsSheetState();
}

class _TariffDetailsSheetState extends State<_TariffDetailsSheet> {
  bool _switching = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.profile?.baseFare ?? 0;
    final perKm = widget.profile?.perKmRate ?? 0;
    final perMin = widget.profile?.perMinRate ?? 0;
    final perMinWait = widget.profile?.waitingRate ?? 0;
    final returnDiscount = widget.profile?.returnDiscountPct ?? 0;
    final hasMultipleProfiles = widget.profiles.length > 1;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.colors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.colors.text.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.colors.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.colors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_taxi_outlined,
                    color: widget.colors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile?.profileName ??
                            DriverStrings.standardTariff,
                        style: widget.typo.titleSmall.copyWith(
                          color: widget.colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DriverStrings.activeTariff,
                        style: widget.typo.labelSmall.copyWith(
                          color: widget.colors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: widget.colors.textSoft),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, indent: 20, endIndent: 20),

          // Rate breakdown
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _RateRow(
                  label: 'Start price',
                  value: '€${base.toStringAsFixed(2)}',
                  colors: widget.colors,
                  typo: widget.typo,
                ),
                const SizedBox(height: 12),
                _RateRow(
                  label: 'Per kilometer',
                  value: '€${perKm.toStringAsFixed(2)}',
                  colors: widget.colors,
                  typo: widget.typo,
                ),
                const SizedBox(height: 12),
                _RateRow(
                  label: 'Per minute',
                  value: '€${perMin.toStringAsFixed(2)}',
                  colors: widget.colors,
                  typo: widget.typo,
                ),
                const SizedBox(height: 12),
                _RateRow(
                  label: 'Wait time / min',
                  value: '€${perMinWait.toStringAsFixed(2)}',
                  colors: widget.colors,
                  typo: widget.typo,
                ),
                if (returnDiscount > 0) ...[
                  const SizedBox(height: 12),
                  _RateRow(
                    label: 'Return trip discount',
                    value: '$returnDiscount%',
                    colors: widget.colors,
                    typo: widget.typo,
                    isHighlighted: true,
                  ),
                ],
              ],
            ),
          ),

          // Tariff Switcher - Show all available tariffs
          if (hasMultipleProfiles) ...[
            const Divider(height: 1, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 16,
                    color: widget.colors.textSoft,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Switch Tariff',
                    style: widget.typo.labelSmall.copyWith(
                      color: widget.colors.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: widget.profiles.map((p) {
                  final isActive = p.id == widget.profile?.id;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _switching || isActive
                          ? null
                          : () async {
                              debugPrint('Modal tapped tariff: ${p.profileName}');
                              setState(() => _switching = true);
                              await widget.onSwitchProfile(p.id);
                              debugPrint('Modal switch completed');
                              if (mounted) {
                                setState(() => _switching = false);
                              }
                            },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? widget.colors.accent.withValues(alpha: 0.1)
                              : widget.colors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive
                                ? widget.colors.accent.withValues(alpha: 0.3)
                                : widget.colors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: isActive
                                  ? widget.colors.accent
                                  : widget.colors.textSoft,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.profileName,
                                style: widget.typo.bodyMedium.copyWith(
                                  color: widget.colors.text,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.colors.accent
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Active',
                                  style: widget.typo.labelSmall.copyWith(
                                    color: widget.colors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 16),

          // Edit button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
              onPressed: _switching ? null : widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Edit This Tariff',
                style: widget.typo.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Rate row widget for tariff details
class _RateRow extends StatelessWidget {
  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool isHighlighted;

  const _RateRow({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: typo.bodyMedium.copyWith(
            color: colors.textSoft,
          ),
        ),
        Text(
          value,
          style: typo.bodyMedium.copyWith(
            color: isHighlighted ? colors.success : colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

