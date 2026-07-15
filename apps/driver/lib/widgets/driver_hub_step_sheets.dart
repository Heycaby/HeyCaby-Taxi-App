import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_earnings_targets_notifier.dart';
import '../providers/driver_state_provider.dart';
import '../theme/app_icons.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../ui/driver_bottom_sheet.dart';
import '../utils/driver_hub_goal_progress.dart';
import 'driver_hub_goal_period_selector.dart';
import 'driver_hub_assets.dart';
import 'driver_hub_sign_tile.dart';

final driverHubEarningsPeriodProvider = StateProvider<String>((_) => 'weekly');

void showDriverHubTariffTooltip(BuildContext context) {
  final colors = ProviderScope.containerOf(context).read(colorsProvider);
  final typo = ProviderScope.containerOf(context).read(typographyProvider);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Image.asset(
        DriverHubAssets.setTariff,
        width: 48,
        height: 48,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.speed_rounded, size: 48),
      ),
      title: Text(
        DriverStrings.hubTariffTooltipTitle,
        style: typo.titleMedium.copyWith(fontWeight: FontWeight.w900),
      ),
      content: Text(
        DriverStrings.hubTariffTooltipBody,
        style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.4),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(DriverStrings.hubDone),
        ),
      ],
    ),
  );
}

Future<void> showDriverHubMoneySheet(BuildContext context, WidgetRef ref) {
  final colors = DriverColors.fromTheme(ref.read(colorsProvider));
  return showDriverBottomSheet<void>(
    context: context,
    colors: colors,
    builder: (ctx) => const _DriverHubMoneySheetBody(),
  );
}

Future<void> showDriverHubPricesSheet(BuildContext context, WidgetRef ref) {
  final colors = DriverColors.fromTheme(ref.read(colorsProvider));
  return showDriverBottomSheet<void>(
    context: context,
    colors: colors,
    builder: (ctx) => const _DriverHubPricesSheetBody(),
  );
}

Future<void> showDriverHubSafetySheet(BuildContext context, WidgetRef ref) {
  final colors = DriverColors.fromTheme(ref.read(colorsProvider));
  return showDriverBottomSheet<void>(
    context: context,
    colors: colors,
    builder: (ctx) => const _DriverHubSafetySheetBody(),
  );
}

Future<void> showDriverHubHelpSheet(BuildContext context, WidgetRef ref) {
  final colors = DriverColors.fromTheme(ref.read(colorsProvider));
  return showDriverBottomSheet<void>(
    context: context,
    colors: colors,
    builder: (ctx) => const _DriverHubHelpSheetBody(),
  );
}

class _DriverHubSheetChrome extends StatelessWidget {
  const _DriverHubSheetChrome({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = refWatchColors(context);
    final typo = refWatchTypo(context);
    return Padding(
      padding: EdgeInsets.only(
        left: DriverSpacing.screenEdge,
        right: DriverSpacing.screenEdge,
        bottom: MediaQuery.paddingOf(context).bottom + DriverSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: typo.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: colors.textMid),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          child,
        ],
      ),
    );
  }

  static HeyCabyColorTokens refWatchColors(BuildContext context) {
    return ProviderScope.containerOf(context).read(colorsProvider);
  }

  static HeyCabyTypography refWatchTypo(BuildContext context) {
    return ProviderScope.containerOf(context).read(typographyProvider);
  }
}

class _DriverHubMoneySheetBody extends ConsumerWidget {
  const _DriverHubMoneySheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final earnings = ref.watch(driverEarningsProvider).valueOrNull;
    final targets = ref.watch(driverEarningsTargetsProvider).valueOrNull ?? {};
    final shift = ref.watch(driverShiftStatsProvider).valueOrNull;
    final billing = ref.watch(driverBillingStatusProvider).valueOrNull;
    final period = ref.watch(driverHubEarningsPeriodProvider);
    final todayEuros = earnings?.todayEuros ?? 0;
    final weekEuros = earnings?.weekEuros ?? 0;
    final biweeklyEuros = earnings?.biweeklyEuros ?? 0;
    final monthEuros = earnings?.monthEuros ?? 0;
    final rides = shift?.shiftRidesToday ?? earnings?.todayRides ?? 0;
    final periodEarned = DriverHubGoalProgress.earnedForPeriod(
      period: period,
      todayEuros: todayEuros,
      weekEuros: weekEuros,
      biweeklyEuros: biweeklyEuros,
      monthEuros: monthEuros,
    );
    final periodTarget = targets[period] ?? 0;
    final goal = DriverHubGoalProgress.snapshot(
      earned: periodEarned,
      target: periodTarget,
      period: period,
    );
    final ridesPaused = billing?['ride_requests_paused'] == true;

    return _DriverHubSheetChrome(
      title: DriverStrings.hubTileMoney,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      DriverHubAssets.moneyWallet,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.account_balance_wallet_rounded,
                        color: colors.accent,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DriverSpacing.md),
                Text(
                  earnings?.formatEuros(todayEuros) ?? '€0.00',
                  style: typo.displaySmall.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_taxi_rounded,
                        size: 18, color: colors.textMid),
                    const SizedBox(width: 6),
                    Text(
                      DriverStrings.hubRidesToday(rides),
                      style: typo.bodyMedium.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DriverSpacing.xl),
          DriverHubGoalPeriodSelector(
            period: period,
            colors: colors,
            typo: typo,
            onPeriodChanged: (value) {
              ref.read(driverHubEarningsPeriodProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: DriverSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: periodTarget > 0 ? goal.progress.clamp(0.0, 1.0) : null,
                  strokeWidth: 6,
                  color: goal.achieved ? colors.success : colors.accent,
                  backgroundColor: colors.border.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverHubGoalProgress.periodLabel(period),
                      style: typo.labelLarge.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      earnings?.formatEuros(periodEarned) ?? '€0.00',
                      style: typo.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (periodTarget > 0)
                      Text(
                        '/ ${earnings?.formatEuros(periodTarget) ?? '€0.00'}',
                        style: typo.bodySmall.copyWith(
                          color: colors.textSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (goal.message != null) ...[
            const SizedBox(height: DriverSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DriverSpacing.md),
              decoration: BoxDecoration(
                color: goal.achieved
                    ? colors.success.withValues(alpha: 0.10)
                    : colors.accent.withValues(alpha: 0.08),
                borderRadius: DriverRadius.mdAll,
                border: Border.all(
                  color: goal.achieved
                      ? colors.success.withValues(alpha: 0.28)
                      : colors.accent.withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                goal.message!,
                style: typo.bodyMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: DriverSpacing.lg),
          FilledButton(
            onPressed: () =>
                _showSetGoalSheet(context, ref, period, colors, typo),
            child: Text(
              periodTarget > 0
                  ? '${DriverStrings.hubEditGoalForPeriod} · ${DriverHubGoalProgress.periodLabel(period)}'
                  : '${DriverStrings.hubSetGoalForPeriod} · ${DriverHubGoalProgress.periodLabel(period)}',
            ),
          ),
          if (ridesPaused) ...[
            const SizedBox(height: DriverSpacing.md),
            Material(
              color: colors.warning.withValues(alpha: 0.10),
              borderRadius: DriverRadius.mdAll,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/driver/billing');
                },
                borderRadius: DriverRadius.mdAll,
                child: Padding(
                  padding: const EdgeInsets.all(DriverSpacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.warning),
                      const SizedBox(width: DriverSpacing.sm),
                      Expanded(
                        child: Text(
                          DriverStrings.platformBalanceRequestsPaused,
                          style: typo.bodySmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: colors.warning),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSetGoalSheet(
    BuildContext context,
    WidgetRef ref,
    String period,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
  ) {
    final targets = ref.read(driverEarningsTargetsProvider).valueOrNull ?? {};
    final current = targets[period] ?? 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DriverHubSetGoalSheet(
        period: period,
        initialAmount: current,
        colors: colors,
        typo: typo,
      ),
    );
  }
}

class _DriverHubSetGoalSheet extends ConsumerStatefulWidget {
  const _DriverHubSetGoalSheet({
    required this.period,
    required this.initialAmount,
    required this.colors,
    required this.typo,
  });

  final String period;
  final double initialAmount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  ConsumerState<_DriverHubSetGoalSheet> createState() =>
      _DriverHubSetGoalSheetState();
}

class _DriverHubSetGoalSheetState extends ConsumerState<_DriverHubSetGoalSheet> {
  late final TextEditingController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmount > 0
          ? widget.initialAmount.toInt().toString()
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final amount = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    setState(() => _busy = true);
    HapticService.mediumTap();
    final ok = await ref
        .read(driverEarningsTargetsProvider.notifier)
        .saveTarget(widget.period, amount);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    if (_busy || widget.initialAmount <= 0) return;
    setState(() => _busy = true);
    HapticService.selectionClick();
    final ok = await ref
        .read(driverEarningsTargetsProvider.notifier)
        .removeTarget(widget.period);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    final periodLabel = DriverHubGoalProgress.periodLabel(widget.period);
    final hasGoal = widget.initialAmount > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: DriverSpacing.screenEdge,
        right: DriverSpacing.screenEdge,
        bottom: MediaQuery.paddingOf(context).bottom + DriverSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasGoal
                ? '${DriverStrings.hubEditGoalForPeriod} · $periodLabel'
                : '${DriverStrings.hubSetGoalForPeriod} · $periodLabel',
            style: typo.titleMedium.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: DriverSpacing.md),
          TextField(
            controller: _controller,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              prefixText: '€ ',
              hintText: DriverStrings.hubGoalAmountHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? '…' : DriverStrings.save),
          ),
          if (hasGoal) ...[
            const SizedBox(height: DriverSpacing.sm),
            TextButton(
              onPressed: _busy ? null : _remove,
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text(DriverStrings.hubRemoveGoal),
            ),
          ],
        ],
      ),
    );
  }
}

class _HubTariffTipBanner extends StatelessWidget {
  const _HubTariffTipBanner({required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.accent.withValues(alpha: 0.08),
      borderRadius: DriverRadius.mdAll,
      child: InkWell(
        onTap: () => showDriverHubTariffTooltip(context),
        borderRadius: DriverRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(DriverSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Image.asset(
                  DriverHubAssets.setTariff,
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.speed_rounded, size: 28, color: colors.accent),
                ),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.hubTariffTooltipTitle,
                      style: typo.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DriverStrings.hubTariffTooltipBody,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(
                        color: colors.textMid,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.info_outline_rounded, color: colors.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverHubPricesSheetBody extends ConsumerStatefulWidget {
  const _DriverHubPricesSheetBody();

  @override
  ConsumerState<_DriverHubPricesSheetBody> createState() =>
      _DriverHubPricesSheetBodyState();
}

class _DriverHubPricesSheetBodyState
    extends ConsumerState<_DriverHubPricesSheetBody> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final profiles = ref.watch(driverRateProfilesProvider).valueOrNull ?? [];
    final activeProfile = ref.watch(activeRateProfileProvider).valueOrNull;
    final driverId = ref.watch(driverIdProvider).valueOrNull;
    final isLoading = ref.watch(driverRateProfilesProvider).isLoading;

    Future<void> onChipTap(String profileId) async {
      if (driverId == null) return;
      final ok = await ref
          .read(driverDataServiceProvider)
          .switchRateProfile(driverId, profileId);
      if (ok) {
        ref.invalidate(driverRateProfilesProvider);
        ref.invalidate(activeRateProfileProvider);
        if (mounted) setState(() => _step = 1);
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: DriverSpacing.screenEdge,
        right: DriverSpacing.screenEdge,
        bottom: MediaQuery.paddingOf(context).bottom + DriverSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_step > 0)
                IconButton(
                  onPressed: () {
                    HapticService.selectionClick();
                    setState(() => _step = 0);
                  },
                  icon: Icon(Icons.arrow_back_rounded, color: colors.textMid),
                ),
              Expanded(
                child: Text(
                  _step == 0
                      ? DriverStrings.hubTileSetTariff
                      : DriverStrings.hubPricesStepShow,
                  style: typo.titleLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: colors.textMid),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          _HubTariffTipBanner(colors: colors, typo: typo),
          const SizedBox(height: DriverSpacing.md),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(DriverSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (profiles.isEmpty)
            FilledButton(
              onPressed: () async {
                if (driverId == null) return;
                await ref
                    .read(driverDataServiceProvider)
                    .createFirstRateProfile(driverId);
                ref.invalidate(driverRateProfilesProvider);
                ref.invalidate(activeRateProfileProvider);
              },
              child: Text(DriverStrings.setUpRates),
            )
          else if (_step == 0) ...[
            Wrap(
              spacing: DriverSpacing.sm,
              runSpacing: DriverSpacing.sm,
              children: [
                for (final p in profiles)
                  _HubProfileChip(
                    label: p.profileName,
                    selected: p.id == activeProfile?.id,
                    colors: colors,
                    typo: typo,
                    onTap: () {
                      HapticService.mediumTap();
                      onChipTap(p.id);
                    },
                  ),
              ],
            ),
            if (activeProfile != null) ...[
              const SizedBox(height: DriverSpacing.lg),
              FilledButton(
                onPressed: () {
                  HapticService.selectionClick();
                  setState(() => _step = 1);
                },
                child: Text(DriverStrings.hubNext),
              ),
            ],
          ] else if (activeProfile != null) ...[
            Center(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      DriverHubAssets.setTariff,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.speed_rounded, size: 48, color: colors.accent),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  Text(
                    '€${activeProfile.perKmRate.toStringAsFixed(2)}',
                    style: typo.displaySmall.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    DriverStrings.hubPerKmHero,
                    style: typo.titleSmall.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DriverSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _HubRateSign(
                    icon: Icons.flag_rounded,
                    value: '€${activeProfile.baseFare.toStringAsFixed(2)}',
                    label: DriverStrings.rateStart,
                    colors: colors,
                    typo: typo,
                  ),
                ),
                const SizedBox(width: DriverSpacing.sm),
                Expanded(
                  child: _HubRateSign(
                    icon: Icons.route_rounded,
                    value: '€${activeProfile.perKmRate.toStringAsFixed(2)}',
                    label: DriverStrings.ratePerKm,
                    colors: colors,
                    typo: typo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DriverSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _HubRateSign(
                    icon: Icons.schedule_rounded,
                    value: '€${activeProfile.perMinRate.toStringAsFixed(2)}',
                    label: DriverStrings.ratePerMin,
                    colors: colors,
                    typo: typo,
                  ),
                ),
                const SizedBox(width: DriverSpacing.sm),
                Expanded(
                  child: _HubRateSign(
                    icon: Icons.hourglass_top_rounded,
                    value:
                        '€${activeProfile.waitingRate.toStringAsFixed(2)}',
                    label: DriverStrings.rateWaiting,
                    colors: colors,
                    typo: typo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DriverSpacing.lg),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/driver/tariffs');
              },
              child: Text(DriverStrings.hubManageAllPrices),
            ),
          ],
        ],
      ),
    );
  }
}

class _HubProfileChip extends StatelessWidget {
  const _HubProfileChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_taxi_rounded,
              size: 20,
              color: selected ? colors.onAccent : colors.textMid,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: typo.titleSmall.copyWith(
                color: selected ? colors.onAccent : colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubRateSign extends StatelessWidget {
  const _HubRateSign({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
    required this.typo,
  });

  final IconData icon;
  final String value;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.sm,
        vertical: DriverSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.8),
        borderRadius: DriverRadius.mdAll,
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.accent, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: typo.titleSmall.copyWith(
              fontWeight: FontWeight.w900,
              color: colors.text,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: typo.labelSmall.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverHubSafetySheetBody extends ConsumerWidget {
  const _DriverHubSafetySheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);
    final driverId = ref.watch(driverIdProvider).valueOrNull;
    final canShare = driver.activeRideId != null &&
        (driver.appState == DriverAppState.assigned ||
            driver.appState == DriverAppState.arrived ||
            driver.appState == DriverAppState.inProgress ||
            driver.appState == DriverAppState.completingRide);

    return _DriverHubSheetChrome(
      title: DriverStrings.hubTileSafety,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 64,
            child: FilledButton.icon(
              onPressed: () async {
                HapticService.heavyTap();
                if (driverId != null && driverId.isNotEmpty) {
                  try {
                    await ref.read(driverDataServiceProvider).insertSafetyEvent(
                          driverId,
                          'emergency_call',
                          rideRequestId: driver.activeRideId,
                        );
                  } catch (e) {
                    if (kDebugMode) debugPrint('Safety event error: $e');
                  }
                }
                if (context.mounted) {
                  await launchUrl(Uri.parse('tel:112'));
                }
              },
              icon: const Icon(AppIcons.emergency, size: 28),
              label: Text(
                DriverStrings.call112,
                style: typo.titleMedium.copyWith(fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (canShare) ...[
            const SizedBox(height: DriverSpacing.md),
            DriverHubSignTile(
              colors: colors,
              typography: typo,
              icon: Icons.share_rounded,
              label: DriverStrings.shareTripDetails,
              subtitle: DriverStrings.hubShareFamily,
              tint: colors.text,
              onTap: () async {
                final url = await ref
                    .read(driverDataServiceProvider)
                    .getOrCreateRideShareUrl(driver.activeRideId!);
                if (url != null && context.mounted) {
                  await Share.share(url);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverHubHelpSheetBody extends ConsumerWidget {
  const _DriverHubHelpSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return _DriverHubSheetChrome(
      title: DriverStrings.hubTileHelp,
      child: Column(
        children: [
          DriverHubSignTile(
            colors: colors,
            typography: typo,
            icon: Icons.chat_bubble_rounded,
            label: DriverStrings.hubHelpChat,
            subtitle: DriverStrings.helpSectionTitle,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/driver/support');
            },
          ),
          const SizedBox(height: DriverSpacing.sm),
          DriverHubSignTile(
            colors: colors,
            typography: typo,
            icon: Icons.lightbulb_outline_rounded,
            label: DriverStrings.hubHelpIdea,
            subtitle: DriverStrings.appSuggestion,
            tint: colors.warning,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/driver/app-suggestion');
            },
          ),
        ],
      ),
    );
  }
}
