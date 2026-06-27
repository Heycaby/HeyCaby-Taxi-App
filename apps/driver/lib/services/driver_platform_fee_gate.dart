import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../services/driver_billing_service.dart';
import '../l10n/driver_strings.dart';
import 'driver_apple_iap_billing.dart';
import '../widgets/driver_billing_plan_picker.dart';
import '../widgets/driver_mollie_checkout_screen.dart';

/// `true` when the signed-in user has [user_metadata.review_account] (App Store review).
/// Must match [authmw.extractReviewAccount] in the Go API (same JWT field).
bool driverAuthIsAppReviewAccount() {
  final meta = HeyCabySupabase.client.auth.currentSession?.user.userMetadata;
  if (meta == null) return false;
  final v = meta['review_account'];
  if (v is bool) return v;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

/// Ensures driver has paid platform fee when required. Returns `true` to proceed with going **available**.
Future<bool> ensureDriverPlatformFeeAllowsOnline(
  BuildContext context,
  WidgetRef ref,
) async {
  if (driverAuthIsAppReviewAccount()) return true;
  final api = ref.read(driverApiProvider);
  Map<String, dynamic> data;
  try {
    data = await api.fetchDriverStatus();
  } catch (e) {
    _logPlatformFeeTelemetry(
      scope: 'platform_fee',
      event: 'fetch_status_failed_initial',
      detail: e.toString(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.platformFeeStatusError)),
      );
    }
    return false;
  }

  final paymentRequired = data['payment_required'] == true;
  if (!paymentRequired) return true;

  final isLedger = DriverBillingService.isLedgerV1(data);
  if (isLedger && data['can_settle_outstanding'] != true) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.platformFeeStatusError)),
      );
    }
    return false;
  }

  if (driverStatusUsesAppleBilling(data) && !driverAppleIapSupportedOnDevice) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.iapOnlyAvailableOnIos)),
      );
    }
    return false;
  }
  if (!context.mounted) return false;

  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);
  final weeklyCents = data['weekly_fee_cents'];
  final feeEuro = weeklyCents is num
      ? (weeklyCents / 100).toStringAsFixed(2)
      : '?';
  String? selectedPlan;
  if (isLedger) {
    selectedPlan = 'settlement';
  } else {
    final plans = parseServerBillingPlans(data);
    selectedPlan = await pickDriverBillingPlanCode(
      context,
      colors: colors,
      typo: typo,
      plans: plans,
    );
  }
  if (selectedPlan == null || !context.mounted) return false;

  final pay = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(DriverStrings.platformFeeTitle, style: typo.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.platformFeeBody(feeEuro),
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              context.push('/driver/billing/history');
            },
            child: Text(DriverStrings.billingViewHistory),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(DriverStrings.cancel),
        ),
        FilledButton(
          onPressed: () {
            HapticService.mediumTap();
            Navigator.pop(ctx, true);
          },
          child: Text(DriverStrings.platformFeePay),
        ),
      ],
    ),
  );

  if (pay != true || !context.mounted) return false;

  final useAppleIap =
      driverStatusUsesAppleBilling(data) && driverAppleIapSupportedOnDevice;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              useAppleIap
                  ? DriverStrings.platformFeeStartingAppleIap
                  : DriverStrings.platformFeeStartingCheckout,
              style: typo.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );

  if (useAppleIap) {
    final iapOk = await purchaseDriverPlatformAccessWithAppleIap(
      context: context,
      api: api,
      planCode: selectedPlan,
    );
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!iapOk) return false;
  } else {
    Map<String, dynamic> created;
    try {
      created = isLedger
          ? await api.createDriverPlatformPayment()
          : await api.createDriverPlatformPayment(plan: selectedPlan);
    } catch (e) {
      _logPlatformFeeTelemetry(
        scope: 'platform_fee',
        event: 'create_payment_failed',
        detail: e.toString(),
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        final msg = e is DioException && e.response?.data is Map
            ? (e.response!.data['error']?.toString() ??
                DriverStrings.platformFeeStartError)
            : DriverStrings.platformFeeStartError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return false;
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    final url = created['checkoutUrl'] as String?;
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.platformFeeStartError)),
        );
      }
      return false;
    }

    if (!context.mounted) return false;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverMollieCheckoutScreen(
          checkoutUrl: url,
          colors: colors,
          typo: typo,
        ),
      ),
    );
  }

  try {
    data = await api.fetchDriverStatus();
  } catch (e) {
    _logPlatformFeeTelemetry(
      scope: 'platform_fee',
      event: 'fetch_status_failed_post_checkout',
      detail: e.toString(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.platformFeeStatusError)),
      );
    }
    return false;
  }

  final stillRequired = data['payment_required'] == true;
  if (stillRequired && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DriverStrings.platformFeeStillPending)),
    );
    return false;
  }

  return true;
}

void _logPlatformFeeTelemetry({
  required String scope,
  required String event,
  String? detail,
}) {
  HeyCabySupabase.client.rpc(
    'fn_driver_log_client_telemetry',
    params: {
      'p_scope': scope,
      'p_event': event,
      'p_detail': detail,
    },
  ).catchError((_) {});
}
