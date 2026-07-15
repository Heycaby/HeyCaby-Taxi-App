import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/booking_provider.dart';
import '../services/rider_runtime_config_service.dart';

bool riderPrepayEnabledForMode(
  RiderRuntimeTuning config,
  BookingMode mode,
) =>
    switch (mode) {
      BookingMode.scheduled => config.scheduledPrepayEnabled,
      BookingMode.terug => config.taxiTerugPrepayEnabled,
      BookingMode.instant => config.instantPrepayEnabled,
      BookingMode.marketplace => false,
    };

bool riderPrepayVisibleForRideStatus(String? status) => const {
      'accepted',
      'driver_en_route',
      'driver_arrived',
      'arrived',
    }.contains(status);

BookingMode riderPrepayModeFromBackend(
  String? backendMode,
  BookingMode fallback,
) =>
    switch (backendMode?.trim().toLowerCase()) {
      'scheduled' => BookingMode.scheduled,
      'terug' => BookingMode.terug,
      'instant' => BookingMode.instant,
      'marketplace' => BookingMode.marketplace,
      _ => fallback,
    };

/// Feature-flagged rider projection of the backend payment state.
///
/// The widget never supplies an amount and never marks a payment paid. It only
/// starts the canonical Edge Function and renders webhook-confirmed snapshots.
class RiderPrepayCard extends StatefulWidget {
  const RiderPrepayCard({
    super.key,
    required this.rideId,
    required this.mode,
    required this.colors,
    required this.typography,
    required this.l10n,
    this.riderToken,
    this.service = const PrepaidRidePaymentService(),
  });

  final String rideId;
  final String? riderToken;
  final BookingMode mode;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final AppLocalizations l10n;
  final PrepaidRidePaymentService service;

  @override
  State<RiderPrepayCard> createState() => _RiderPrepayCardState();
}

class _RiderPrepayCardState extends State<RiderPrepayCard>
    with WidgetsBindingObserver {
  PrepaidRidePayment? _payment;
  Timer? _pollTimer;
  bool _loading = true;
  bool _openingCheckout = false;
  bool _checkoutWasOpened = false;
  bool _optionalPayDriverSelected = false;
  String? _error;

  bool get _isOptional => widget.mode == BookingMode.instant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSnapshot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _checkoutWasOpened) {
      _checkoutWasOpened = false;
      _refreshSnapshot();
    }
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshSnapshot(showLoading: false),
    );
  }

  Future<void> _refreshSnapshot({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    final result = await widget.service.snapshot(
      rideId: widget.rideId,
      riderToken: widget.riderToken,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _payment = result.payment;
        _error = null;
      } else {
        _error = result.error;
      }
    });
    if (_payment?.isPaid == true) {
      _pollTimer?.cancel();
      _pollTimer = null;
    } else if (_payment != null) {
      _startPolling();
    }
  }

  Future<void> _payNow() async {
    if (_loading || _openingCheckout) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.service.createCheckout(
      rideId: widget.rideId,
      riderToken: widget.riderToken,
      instantPrepayOptIn: _isOptional,
    );
    if (!mounted) return;
    final payment = result.payment;
    if (!result.ok || payment == null) {
      setState(() {
        _loading = false;
        _error = result.error ?? 'payment_create_failed';
      });
      return;
    }
    setState(() {
      _payment = payment;
      _loading = false;
    });
    _startPolling();
    await _openCheckout(payment.checkoutUrl);
  }

  Future<void> _openCheckout(String? rawUrl) async {
    final uri = Uri.tryParse(rawUrl ?? '');
    if (uri == null || _openingCheckout) {
      setState(() => _error = 'checkout_url_missing');
      return;
    }
    setState(() => _openingCheckout = true);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() {
      _openingCheckout = false;
      _checkoutWasOpened = launched;
      if (!launched) _error = 'checkout_launch_failed';
    });
  }

  String get _errorCopy {
    if (_error == 'driver_not_prepay_ready') {
      return widget.l10n.prepayDriverNotReady;
    }
    return widget.l10n.prepayUnavailable;
  }

  @override
  Widget build(BuildContext context) {
    if (_optionalPayDriverSelected) return const SizedBox.shrink();

    final colors = widget.colors;
    final typo = widget.typography;
    final paid = _payment?.isPaid == true;
    final hasCheckout = (_payment?.checkoutUrl ?? '').isNotEmpty;
    final statusColor = paid ? colors.success : colors.accent;
    final amountLabel = HeyCabyRideFare.formatCentsLabel(
      _payment?.amountCents,
      symbol: _payment?.currency == 'EUR' ? '€' : '${_payment?.currency} ',
    );

    return Semantics(
      liveRegion: paid,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: statusColor.withValues(alpha: paid ? 0.35 : 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    paid ? Icons.verified_rounded : Icons.lock_outline_rounded,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paid
                            ? widget.l10n.prepayPaid
                            : widget.l10n.prepayRideTitle,
                        style: typo.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paid
                            ? widget.l10n.prepayPaid
                            : _isOptional
                                ? widget.l10n.prepayRideOptionalBody
                                : widget.l10n.prepayRideRequiredBody,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (amountLabel != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.l10n.prepayAmount(amountLabel),
                style: typo.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (_error != null && !paid) ...[
              const SizedBox(height: 12),
              Text(
                _errorCopy,
                style: typo.bodySmall.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
            if (!paid) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loading || _openingCheckout
                    ? null
                    : hasCheckout
                        ? () => _openCheckout(_payment?.checkoutUrl)
                        : _payNow,
                icon: _loading || _openingCheckout
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onAccent,
                        ),
                      )
                    : const Icon(Icons.open_in_new_rounded),
                label: Text(
                  hasCheckout
                      ? widget.l10n.prepayOpenCheckout
                      : _error != null
                          ? widget.l10n.prepayRetry
                          : widget.l10n.prepayPayNow,
                ),
              ),
              if (_payment != null && _error == null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.l10n.prepayAwaitingConfirmation,
                  textAlign: TextAlign.center,
                  style: typo.labelSmall.copyWith(color: colors.textSoft),
                ),
              ],
              if (_isOptional) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(
                            () => _optionalPayDriverSelected = true,
                          ),
                  child: Text(widget.l10n.prepayPayDriver),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
