import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';

class DriverCollectPaymentResult {
  const DriverCollectPaymentResult({
    required this.confirmed,
    required this.paymentMethod,
  });

  final bool confirmed;
  final RidePaymentMethod paymentMethod;
}

Future<DriverCollectPaymentResult?> showDriverCollectPaymentSheet(
  BuildContext context, {
  required DriverColors colors,
  required DriverTypography typography,
  required String rideId,
  required double fareEuro,
  RidePaymentMethod initialMethod = RidePaymentMethod.cash,
}) {
  return showModalBottomSheet<DriverCollectPaymentResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.42),
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _DriverCollectPaymentSheet(
      colors: colors,
      typography: typography,
      rideId: rideId,
      fareEuro: fareEuro,
      initialMethod: initialMethod,
    ),
  );
}

class _DriverCollectPaymentSheet extends StatefulWidget {
  const _DriverCollectPaymentSheet({
    required this.colors,
    required this.typography,
    required this.rideId,
    required this.fareEuro,
    required this.initialMethod,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String rideId;
  final double fareEuro;
  final RidePaymentMethod initialMethod;

  @override
  State<_DriverCollectPaymentSheet> createState() =>
      _DriverCollectPaymentSheetState();
}

class _DriverCollectPaymentSheetState
    extends State<_DriverCollectPaymentSheet> {
  static const _paymentService = RidePaymentService();

  late RidePaymentMethod _method;
  bool _confirming = false;
  bool _tikkieInstalled = true;
  double _tipEuro = 0;
  double? _serverTotalEuro;
  bool _riderAcknowledged = false;
  Timer? _pollTimer;
  RealtimeChannel? _paymentChannel;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;
    unawaited(_refreshTikkieInstalled());
    unawaited(_refreshPaymentSnapshot());
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshPaymentSnapshot());
    });
    _paymentChannel = HeyCabySupabase.client
        .channel('driver_payment:${widget.rideId}')
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
    unawaited(_paymentChannel?.unsubscribe());
    super.dispose();
  }

  Future<void> _refreshTikkieInstalled() async {
    final installed = await isTikkieAppInstalled();
    if (!mounted) return;
    setState(() => _tikkieInstalled = installed);
  }

  Future<void> _refreshPaymentSnapshot() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select(
            'tip_amount_eur, total_amount_eur, rider_payment_confirmed_at',
          )
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted || row == null) return;
      final tip = row['tip_amount_eur'];
      final total = row['total_amount_eur'];
      final riderAck = row['rider_payment_confirmed_at'] != null;
      setState(() {
        _tipEuro = tip is num ? tip.toDouble().clamp(0, 99999) : 0;
        _serverTotalEuro = total is num ? total.toDouble() : null;
        _riderAcknowledged = riderAck;
      });
    } catch (_) {}
  }

  double get _totalDue => _serverTotalEuro ?? (widget.fareEuro + _tipEuro);

  String get _totalLabel => formatRidePaymentEuro(_totalDue);

  Future<void> _openTikkie() async {
    HapticService.mediumTap();
    await openTikkieApp();
    if (!mounted) return;
    await _refreshTikkieInstalled();
  }

  Future<void> _confirmReceived() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    HapticService.mediumTap();
    try {
      final res = await _paymentService.confirm(
        rideId: widget.rideId,
        paymentMethod: _method.driverReceiptId,
      );
      if (!mounted) return;
      if (!res.ok) {
        HapticService.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.paymentConfirmFailed)),
        );
        return;
      }
      HapticService.success();
      Navigator.of(context).pop(
        DriverCollectPaymentResult(
          confirmed: true,
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
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: Material(
        color: colors.card,
        elevation: 12,
        shadowColor: colors.text.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
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
                _DriverPaymentMethodTabs(
                  colors: colors,
                  typography: typography,
                  selected: _method,
                  onChanged: (m) {
                    HapticService.lightTap();
                    setState(() => _method = m);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  DriverStrings.paymentCollectHeadline.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: typography.labelSmall.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _instructionTitle(),
                  textAlign: TextAlign.center,
                  style: (_method == RidePaymentMethod.tikkie
                          ? typography.titleLarge
                          : typography.titleMedium)
                      .copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (_riderAcknowledged) ...[
                  const SizedBox(height: 10),
                  Text(
                    DriverStrings.paymentRiderConfirmedPay,
                    textAlign: TextAlign.center,
                    style: typography.labelMedium.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  _totalLabel,
                  textAlign: TextAlign.center,
                  style: typography.displaySmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 44,
                    height: 1.02,
                    letterSpacing: 0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (_tipEuro > 0) ...[
                  const SizedBox(height: 10),
                  _DriverPaymentBreakdown(
                    colors: colors,
                    typography: typography,
                    fareLabel: formatRidePaymentEuro(widget.fareEuro),
                    tipLabel: formatRidePaymentEuro(_tipEuro),
                  ),
                ],
                const SizedBox(height: 14),
                _DriverMethodHintCard(
                  colors: colors,
                  typography: typography,
                  method: _method,
                  tikkieInstalled: _tikkieInstalled,
                ),
                const SizedBox(height: 22),
                if (_method == RidePaymentMethod.tikkie) ...[
                  OutlinedButton.icon(
                    onPressed: _confirming ? null : _openTikkie,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: Text(
                      _tikkieInstalled
                          ? DriverStrings.paymentCreateTikkieShowQr
                          : DriverStrings.paymentDownloadTikkie,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton(
                  onPressed: _confirming ? null : _confirmReceived,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _confirming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _primaryCtaLabel(),
                          style: typography.labelLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                if (_method == RidePaymentMethod.cash) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _confirming
                        ? null
                        : () {
                            HapticService.lightTap();
                            Navigator.of(context).pop(
                              DriverCollectPaymentResult(
                                confirmed: false,
                                paymentMethod: _method,
                              ),
                            );
                          },
                    child: Text(DriverStrings.paymentAmountDispute),
                  ),
                ],
                if (_method == RidePaymentMethod.pin) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _confirming
                        ? null
                        : () {
                            HapticService.lightTap();
                            setState(() {});
                          },
                    child: Text(DriverStrings.paymentPinRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _instructionTitle() {
    return switch (_method) {
      RidePaymentMethod.cash =>
        DriverStrings.paymentDriverCashInstruction(_totalLabel),
      RidePaymentMethod.pin => DriverStrings.paymentDriverPinInstruction,
      RidePaymentMethod.tikkie =>
        DriverStrings.paymentDriverTikkieInstruction(_totalLabel),
    };
  }

  String _primaryCtaLabel() {
    return switch (_method) {
      RidePaymentMethod.cash => DriverStrings.paymentCashCollected,
      RidePaymentMethod.pin => DriverStrings.paymentPinReceived,
      RidePaymentMethod.tikkie => DriverStrings.paymentTikkieReceived,
    };
  }
}

class _DriverPaymentBreakdown extends StatelessWidget {
  const _DriverPaymentBreakdown({
    required this.colors,
    required this.typography,
    required this.fareLabel,
    required this.tipLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String fareLabel;
  final String tipLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          _line(DriverStrings.rideFareLabel, fareLabel),
          const SizedBox(height: 4),
          _line(DriverStrings.paymentTipFromRider, tipLabel, accent: true),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool accent = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: typography.labelLarge.copyWith(
            color: accent ? colors.primary : colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DriverPaymentMethodTabs extends StatelessWidget {
  const _DriverPaymentMethodTabs({
    required this.colors,
    required this.typography,
    required this.selected,
    required this.onChanged,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final RidePaymentMethod selected;
  final ValueChanged<RidePaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: RidePaymentMethod.values.map((method) {
          final isSelected = method == selected;
          final label = switch (method) {
            RidePaymentMethod.cash => DriverStrings.cash,
            RidePaymentMethod.pin => DriverStrings.card,
            RidePaymentMethod.tikkie => 'Tikkie',
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
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: typography.labelLarge.copyWith(
                    color: isSelected ? colors.text : colors.textSecondary,
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

class _DriverMethodHintCard extends StatelessWidget {
  const _DriverMethodHintCard({
    required this.colors,
    required this.typography,
    required this.method,
    required this.tikkieInstalled,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final RidePaymentMethod method;
  final bool tikkieInstalled;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (method) {
      RidePaymentMethod.cash => (
          Icons.payments_outlined,
          DriverStrings.cash,
          DriverStrings.paymentCashCountBeforeExit,
        ),
      RidePaymentMethod.pin => (
          Icons.credit_card_rounded,
          DriverStrings.card,
          DriverStrings.paymentPinTakeTerminal,
        ),
      RidePaymentMethod.tikkie => (
          Icons.qr_code_2_rounded,
          'Tikkie',
          tikkieInstalled
              ? DriverStrings.paymentTikkieShowQrToRider
              : DriverStrings.paymentDownloadTikkieHint,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: typography.bodyMedium.copyWith(
                    color: colors.text,
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
