import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/rider_ride_snapshot_service.dart';

class RidePayDriverResult {
  const RidePayDriverResult({
    required this.confirmed,
    this.tipEuro,
    required this.paymentMethod,
  });

  final bool confirmed;
  final double? tipEuro;
  final RidePaymentMethod paymentMethod;
}

/// Rider payment sheet — cash / Tikkie / PIN with live method toggle.
Future<RidePayDriverResult?> showRidePayDriverSheet(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typography,
  required AppLocalizations l10n,
  required String rideId,
  String? riderToken,
  String? fareLabel,
  RidePaymentMethod initialMethod = RidePaymentMethod.cash,
}) async {
  return showModalBottomSheet<RidePayDriverResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.42),
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _RidePayDriverSheet(
      colors: colors,
      typography: typography,
      l10n: l10n,
      rideId: rideId,
      riderToken: riderToken,
      fareEuro: parseRidePaymentEuroLabel(fareLabel),
      initialMethod: initialMethod,
    ),
  );
}

@Deprecated('Use parseRidePaymentEuroLabel from heycaby_utils')
double? parseEuroAmountLabel(String? raw) => parseRidePaymentEuroLabel(raw);

@Deprecated('Use formatRidePaymentEuro from heycaby_utils')
String formatEuroAmount(double value) => formatRidePaymentEuro(value);

String riderPaymentMethodTitle(
  AppLocalizations l10n,
  List<String> paymentMethods,
) {
  return switch (RidePaymentMethod.fromBookingMethods(paymentMethods)) {
    RidePaymentMethod.cash => l10n.cash,
    RidePaymentMethod.pin => 'PIN',
    RidePaymentMethod.tikkie => l10n.tikkie,
  };
}

String? riderPaymentMethodSubtitle(
  AppLocalizations l10n,
  List<String> paymentMethods,
) {
  return switch (RidePaymentMethod.fromBookingMethods(paymentMethods)) {
    RidePaymentMethod.cash => l10n.paymentCashPayBeforeExit,
    RidePaymentMethod.pin => l10n.paymentPinTapReader,
    RidePaymentMethod.tikkie => l10n.paymentTikkieScanQrHint,
  };
}

class _RidePayDriverSheet extends StatefulWidget {
  const _RidePayDriverSheet({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.rideId,
    required this.riderToken,
    required this.fareEuro,
    required this.initialMethod,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final AppLocalizations l10n;
  final String rideId;
  final String? riderToken;
  final double? fareEuro;
  final RidePaymentMethod initialMethod;

  @override
  State<_RidePayDriverSheet> createState() => _RidePayDriverSheetState();
}

class _RidePayDriverSheetState extends State<_RidePayDriverSheet> {
  static const _tipPresets = <double>[0, 2, 5, 10];
  static const _paymentService = RidePaymentService();
  late RidePaymentMethod _method;
  double _selectedTip = 0;
  bool _confirming = false;
  bool _driverConfirmed = false;
  bool _riderCanSelfConfirm = false;
  bool _checkoutAdvanced = false;
  DateTime? _selfConfirmAvailableAt;
  Timer? _pollTimer;
  Timer? _selfConfirmTimer;
  RealtimeChannel? _paymentChannel;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;
    unawaited(_refreshPaymentSnapshot());
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshPaymentSnapshot());
    });
    _paymentChannel = HeyCabySupabase.client
        .channel('rider_payment:${widget.rideId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.rideId,
          ),
          callback: (_) => unawaited(_refreshPaymentSnapshot()),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _selfConfirmTimer?.cancel();
    unawaited(_paymentChannel?.unsubscribe());
    super.dispose();
  }

  void _scheduleRiderSelfConfirmTimer() {
    if (_riderCanSelfConfirm || _selfConfirmAvailableAt == null) return;
    final remaining =
        _selfConfirmAvailableAt!.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      unawaited(_refreshPaymentSnapshot());
      return;
    }
    _selfConfirmTimer?.cancel();
    _selfConfirmTimer = Timer(remaining, () {
      unawaited(_refreshPaymentSnapshot());
    });
  }

  Future<void> _refreshPaymentSnapshot() async {
    try {
      final row = await RiderRideSnapshotService.fetch(
        rideRequestId: widget.rideId,
        riderToken: widget.riderToken,
      );
      if (!mounted || row == null) return;

      final availableRaw = row['rider_self_confirm_available_at']?.toString();
      final selfConfirmAvailableAt = availableRaw != null
          ? DateTime.tryParse(availableRaw)?.toUtc()
          : null;
      final driverConfirmed = row['driver_payment_confirmed_at'] != null;
      final riderCanSelfConfirm = row['rider_can_self_confirm'] == true;
      final tip = row['tip_amount_eur'];

      setState(() {
        _selfConfirmAvailableAt =
            selfConfirmAvailableAt ?? _selfConfirmAvailableAt;
        _driverConfirmed = driverConfirmed;
        _riderCanSelfConfirm = riderCanSelfConfirm;
        if (tip is num && tip.toDouble() > 0) {
          _selectedTip = tip.toDouble().clamp(0, 99999);
        }
      });
      _scheduleRiderSelfConfirmTimer();
      if (driverConfirmed) {
        unawaited(_advanceOnDriverConfirmed());
      }
    } catch (_) {}
  }

  Future<void> _advanceOnDriverConfirmed() async {
    if (_checkoutAdvanced || _confirming || !mounted) return;
    _checkoutAdvanced = true;
    setState(() => _confirming = true);
    HapticService.success();
    try {
      if (_selectedTip > 0 || widget.riderToken != null) {
        await _paymentService.confirm(
          rideId: widget.rideId,
          tipEuro: _selectedTip,
          riderToken: widget.riderToken,
          paymentMethod: _method.id,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        RidePayDriverResult(
          confirmed: true,
          tipEuro: _selectedTip > 0 ? _selectedTip : null,
          paymentMethod: _method,
        ),
      );
    } catch (_) {
      _checkoutAdvanced = false;
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  double? get _fare => widget.fareEuro;

  double get _total => (_fare ?? 0) + _selectedTip;

  String get _totalLabel => formatRidePaymentEuro(_total);

  bool get _showsTips => true;

  bool get _canTapSelfConfirm => _riderCanSelfConfirm && !_driverConfirmed;

  Future<void> _confirmPaid() async {
    if (_confirming || !_canTapSelfConfirm) return;
    setState(() => _confirming = true);
    HapticService.mediumTap();
    try {
      final res = await _paymentService.confirm(
        rideId: widget.rideId,
        tipEuro: _selectedTip,
        riderToken: widget.riderToken,
        paymentMethod: _method.id,
      );
      if (!mounted) return;
      if (!res.ok) {
        HapticService.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.paymentConfirmFailed)),
        );
        return;
      }
      HapticService.success();
      Navigator.of(context).pop(
        RidePayDriverResult(
          confirmed: true,
          tipEuro: _selectedTip > 0 ? _selectedTip : null,
          paymentMethod: _method,
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = widget.typography;
    final l10n = widget.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final fareLabel = _fare != null ? formatRidePaymentEuro(_fare!) : '—';
    final amountLabel = _selectedTip > 0 ? _totalLabel : fareLabel;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: GlassPanel(
        colors: colors,
        typography: typography,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        borderRadius: BorderRadius.circular(28),
        tintColor: colors.card,
        borderColor: colors.border.withValues(alpha: 0.55),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _PaymentMethodTabs(
                colors: colors,
                typo: typography,
                l10n: l10n,
                selected: _method,
                onChanged: (m) {
                  HapticService.lightTap();
                  setState(() => _method = m);
                },
              ),
              const SizedBox(height: 20),
              Text(
                l10n.paymentRiderHeadline.toUpperCase(),
                textAlign: TextAlign.center,
                style: typography.labelSmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _instructionTitle(l10n),
                textAlign: TextAlign.center,
                style: typography.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                amountLabel,
                textAlign: TextAlign.center,
                style: typography.displaySmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 44,
                  height: 1.02,
                  letterSpacing: -1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 14),
              _MethodHintCard(
                colors: colors,
                typo: typography,
                method: _method,
                l10n: l10n,
              ),
              if (_showsTips) ...[
                const SizedBox(height: 18),
                Text(
                  l10n.paymentAddTipQuestion,
                  textAlign: TextAlign.center,
                  style: typography.labelMedium.copyWith(
                    color: colors.textSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: _tipPresets.map((amount) {
                    final selected = _selectedTip == amount;
                    final label = amount == 0
                        ? l10n.paymentNoTip
                        : formatRidePaymentEuro(amount);
                    return _TipChip(
                      label: label,
                      selected: selected,
                      colors: colors,
                      typo: typography,
                      onTap: () {
                        HapticService.lightTap();
                        setState(() => _selectedTip = amount);
                      },
                    );
                  }).toList(),
                ),
              ],
              if (_driverConfirmed) ...[
                const SizedBox(height: 22),
                Text(
                  l10n.paymentDriverConfirmedProceed,
                  textAlign: TextAlign.center,
                  style: typography.labelMedium.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: (_confirming || !_canTapSelfConfirm)
                      ? null
                      : _confirmPaid,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _confirming
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onAccent,
                          ),
                        )
                      : Text(
                          _canTapSelfConfirm
                              ? _primaryCtaLabel(l10n)
                              : l10n.paymentWaitingForDriver,
                          style: typography.labelLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                if (!_canTapSelfConfirm) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.paymentWaitingForDriverHint,
                    textAlign: TextAlign.center,
                    style: typography.bodySmall.copyWith(
                      color: colors.textSoft,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: _confirming
                    ? null
                    : () {
                        HapticService.lightTap();
                        Navigator.of(context).pop(
                          RidePayDriverResult(
                            confirmed: false,
                            paymentMethod: _method,
                          ),
                        );
                      },
                child: Text(
                  l10n.ridePayDriverDismiss,
                  style: typography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textMid,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _instructionTitle(AppLocalizations l10n) {
    return switch (_method) {
      RidePaymentMethod.cash => l10n.paymentRiderCashInstruction(_totalLabel),
      RidePaymentMethod.pin => l10n.paymentRiderPinInstruction,
      RidePaymentMethod.tikkie => l10n.paymentRiderTikkieInstruction,
    };
  }

  String _primaryCtaLabel(AppLocalizations l10n) {
    return switch (_method) {
      RidePaymentMethod.cash => l10n.ridePayDriverConfirmWithTotal(_totalLabel),
      RidePaymentMethod.pin => l10n.paymentRiderPaidConfirm,
      RidePaymentMethod.tikkie =>
        l10n.ridePayDriverConfirmWithTotal(_totalLabel),
    };
  }
}

class _PaymentMethodTabs extends StatelessWidget {
  const _PaymentMethodTabs({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.selected,
    required this.onChanged,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final RidePaymentMethod selected;
  final ValueChanged<RidePaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: RidePaymentMethod.values.map((method) {
          final isSelected = method == selected;
          final label = switch (method) {
            RidePaymentMethod.cash => l10n.cash,
            RidePaymentMethod.pin => 'PIN',
            RidePaymentMethod.tikkie => l10n.tikkie,
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(method),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? colors.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colors.text.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: typo.labelLarge.copyWith(
                    color: isSelected ? colors.text : colors.textSoft,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MethodHintCard extends StatelessWidget {
  const _MethodHintCard({
    required this.colors,
    required this.typo,
    required this.method,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final RidePaymentMethod method;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (method) {
      RidePaymentMethod.cash => (
          Icons.payments_outlined,
          l10n.cash,
          l10n.paymentCashPayBeforeExit,
        ),
      RidePaymentMethod.pin => (
          Icons.credit_card_rounded,
          'PIN',
          l10n.paymentPinTapReader,
        ),
      RidePaymentMethod.tikkie => (
          Icons.qr_code_2_rounded,
          l10n.tikkie,
          l10n.paymentTikkieScanQrHint,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typo.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: typo.bodyMedium.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.accent.withValues(alpha: 0.12) : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? colors.accent.withValues(alpha: 0.45)
                : colors.border.withValues(alpha: 0.65),
          ),
        ),
        child: Text(
          label,
          style: typo.labelLarge.copyWith(
            color: selected ? colors.accent : colors.textMid,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
