import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_billing_service.dart';
import '../utils/driver_runtime_refresh.dart';
import '../services/driver_apple_iap_billing.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import '../widgets/driver_billing_plan_picker.dart';
import '../widgets/driver_mollie_checkout_screen.dart';
import '../widgets/driver_subscription_gate_body.dart';

int? _weeklyFeeCents(Map<String, dynamic>? s) {
  if (s == null) return null;
  final a = s['weekly_fee_cents'];
  if (a is num) return a.toInt();
  final b = s['weekly_fee_incl_vat_cents'];
  if (b is num) return b.toInt();
  return null;
}

String? _weeklyFeeEuro(Map<String, dynamic>? s) {
  final c = _weeklyFeeCents(s);
  if (c == null) return null;
  return (c / 100).toStringAsFixed(2);
}

String? _ledgerOutstandingLabel(Map<String, dynamic>? s) {
  if (s == null || !DriverBillingService.isLedgerV1(s)) return null;
  final outstanding = s['outstanding_cents'];
  final limit = s['limit_cents'];
  if (outstanding is! num || limit is! num) return null;
  final cur = (s['currency'] as String?)?.trim().toUpperCase();
  final sym = cur == 'EUR' || cur == null ? '€' : '$cur ';
  return '$sym${(outstanding / 100).toStringAsFixed(2)} / $sym${(limit / 100).toStringAsFixed(2)}';
}

String _ledgerFeePerRideLabel(Map<String, dynamic>? s) {
  final cents = s?['platform_fee_cents'];
  if (cents is num) {
    return '€${(cents / 100).toStringAsFixed(2)} ${DriverStrings.billingPerRideSuffix}';
  }
  return DriverStrings.billingDash;
}

void _refreshAfterBillingMutation(WidgetRef ref) {
  ref.invalidate(driverBillingStatusProvider);
  ref.invalidate(driverProfileProvider);
  ref.invalidate(driverPaymentLedgerProvider);
  unawaited(refreshDriverRuntime(ref));
}

String _paymentStatusLine(Map<String, dynamic>? s, bool paymentRequired) {
  if (s == null) return DriverStrings.billingDash;
  if (DriverBillingService.isLedgerV1(s)) {
    final st = (s['status'] as String?)?.toUpperCase();
    if (st == 'LOCKED' || paymentRequired) {
      return DriverStrings.billingStatusPaymentRequired;
    }
    if (st == 'WARNING') return DriverStrings.billingStatusOverdue;
    return DriverStrings.billingStatusNoPaymentDue;
  }
  final explicit =
      s['billing_status_label'] as String? ?? s['subscription_status'] as String?;
  if (explicit != null && explicit.trim().isNotEmpty) return explicit.trim();
  final st = (s['subscription_status'] as String?)?.toLowerCase();
  if (st == 'paused' || st == 'suspended') return DriverStrings.billingStatusPaused;
  if (st == 'canceled' || st == 'cancelled') return DriverStrings.billingStatusCanceled;
  if (paymentRequired) return DriverStrings.billingStatusPaymentRequired;
  return DriverStrings.billingStatusNoPaymentDue;
}

Color _paymentStatusColor(
  HeyCabyColorTokens colors,
  Map<String, dynamic>? s,
  bool paymentRequired,
) {
  if (s == null) return colors.textSoft;
  final st = (s['subscription_status'] as String?)?.toLowerCase();
  if (st == 'paused' || st == 'suspended') return colors.warning;
  if (st == 'canceled' || st == 'cancelled') return colors.textSoft;
  if (paymentRequired) return colors.error;
  return colors.success;
}

bool _hasSubscriptionControls(Map<String, dynamic>? s) {
  if (s == null) return false;
  if (s['show_subscription_controls'] == true) return true;
  final id = s['mollie_subscription_id'];
  if (id is String && id.trim().isNotEmpty) return true;
  if (s['has_mollie_subscription'] == true) return true;
  final st = (s['subscription_status'] as String?)?.toLowerCase();
  return st == 'active' ||
      st == 'pending' ||
      st == 'suspended' ||
      st == 'paused';
}

bool _subscriptionPaused(Map<String, dynamic>? s) {
  if (s == null) return false;
  if (s['subscription_paused'] == true) return true;
  final st = (s['subscription_status'] as String?)?.toLowerCase();
  return st == 'paused' || st == 'suspended';
}

bool _subscriptionCanceled(Map<String, dynamic>? s) {
  if (s == null) return false;
  final st = (s['subscription_status'] as String?)?.toLowerCase();
  return st == 'canceled' || st == 'cancelled';
}

String? _starterBody(Map<String, dynamic>? s) {
  if (s == null) return null;
  if (s['starter_message'] is String) {
    final t = (s['starter_message'] as String).trim();
    if (t.isNotEmpty) return t;
  }
  if (s['starter_period_active'] == true) {
    final rides = s['starter_rides_remaining'];
    final cap = s['starter_earnings_cap_cents'];
    final used = s['starter_earnings_used_cents'];
    final parts = <String>[];
    if (rides is num) parts.add('Starter rides left: ${rides.toInt()}');
    if (cap is num && used is num) {
      parts.add(
        'Starter earnings: €${(used / 100).toStringAsFixed(2)} of €${(cap / 100).toStringAsFixed(2)}',
      );
    } else if (cap is num) {
      parts.add('Starter cap: €${(cap / 100).toStringAsFixed(2)}');
    }
    if (parts.isEmpty) return 'Starter benefits apply — see HeyCaby for details.';
    return parts.join('\n');
  }
  return null;
}

DateTime? _firstDateFromKeys(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) return null;
  for (final k in keys) {
    final v = map[k];
    if (v is String && v.trim().isNotEmpty) {
      final d = DateTime.tryParse(v.trim());
      if (d != null) return d.toLocal();
    }
  }
  return null;
}

DriverStatusTone _paymentStatusTone(
  HeyCabyColorTokens colors,
  Map<String, dynamic>? s,
  bool paymentRequired,
) {
  final c = _paymentStatusColor(colors, s, paymentRequired);
  if (c == colors.error) return DriverStatusTone.error;
  if (c == colors.success) return DriverStatusTone.success;
  if (c == colors.warning) return DriverStatusTone.warning;
  return DriverStatusTone.neutral;
}

class DriverBillingScreen extends ConsumerWidget {
  const DriverBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(colorsProvider);
    final colors = DriverColors.fromTheme(tokens);
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final profileAsync = ref.watch(driverProfileProvider);
    final billingStatusAsync = ref.watch(driverBillingStatusProvider);

    if (profileAsync.isLoading || billingStatusAsync.isLoading) {
      return DriverSubscriptionGateBody(
        colors: colors,
        typography: typography,
        summary: null,
        loading: true,
        errorMessage: null,
        onBack: () => context.pop(),
        onViewHistory: () {},
        onPayNow: () {},
        onPauseSubscription: () {},
        onResumeSubscription: () {},
        onCancelSubscription: () {},
      );
    }

    if (profileAsync.hasError || billingStatusAsync.hasError) {
      return DriverSubscriptionGateBody(
        colors: colors,
        typography: typography,
        summary: null,
        loading: false,
        errorMessage: DriverStrings.platformFeeStatusError,
        onBack: () => context.pop(),
        onViewHistory: () {},
        onPayNow: () {},
        onPauseSubscription: () {},
        onResumeSubscription: () {},
        onCancelSubscription: () {},
      );
    }

    final profile = profileAsync.valueOrNull;
    final billingStatus = billingStatusAsync.valueOrNull;
    final paymentRequired = billingStatus?['payment_required'] == true;
    final ledgerV1 = DriverBillingService.isLedgerV1(billingStatus);
    final weeklyEuro = ledgerV1
        ? null
        : _weeklyFeeEuro(billingStatus);
    final weeklyFeeDisplay = ledgerV1
        ? _ledgerFeePerRideLabel(billingStatus)
        : (weeklyEuro != null ? '€$weeklyEuro' : DriverStrings.billingDash);
    final paidUntil = ledgerV1
        ? null
        : _firstDateFromKeys(
            billingStatus,
            const ['next_payment_due_at', 'subscription_expires_at'],
          );
    final daysRemaining = paidUntil == null
        ? null
        : (paidUntil.difference(DateTime.now()).inHours / 24).ceil();
    final statusLine = _paymentStatusLine(billingStatus, paymentRequired);
    final starterBody = _starterBody(billingStatus);
    final showSub = !ledgerV1 &&
        _hasSubscriptionControls(billingStatus) &&
        !_subscriptionCanceled(billingStatus) &&
        !driverStatusUsesAppleBilling(
          Map<String, dynamic>.from(billingStatus ?? const {}),
        );
    final prepay = billingStatus?['allow_one_off_checkout'] == true;
    final appleIapUi = driverStatusUsesAppleBilling(
          Map<String, dynamic>.from(billingStatus ?? const {}),
        ) &&
        driverAppleIapSupportedOnDevice;

    String? nextPaymentLabel;
    if (ledgerV1) {
      nextPaymentLabel = _ledgerOutstandingLabel(billingStatus);
    } else if (paidUntil != null) {
      final value = (daysRemaining != null && daysRemaining > 0)
          ? DriverStrings.billingDaysRemaining(daysRemaining)
          : DriverStrings.billingNextPaymentDueSoon;
      nextPaymentLabel = '${DriverStrings.billingNextPayment}: $value';
    }

    final summary = DriverSubscriptionSummary(
      isFounding: profile?.isFoundingDriver == true,
      foundingNumber: profile?.foundingNumber,
      weeklyFeeDisplay: weeklyFeeDisplay,
      weeklyFeeUnknown: ledgerV1 ? false : weeklyEuro == null,
      statusLine: statusLine,
      statusTone: _paymentStatusTone(tokens, billingStatus, paymentRequired),
      nextPaymentLabel: nextPaymentLabel,
      starterBody: starterBody,
      showSubscriptionControls: showSub,
      subscriptionPaused: _subscriptionPaused(billingStatus),
      paymentRequired: paymentRequired,
      showOptionalCheckout: prepay && !paymentRequired,
      showAppleRestore: appleIapUi,
      showPaymentMethods: !appleIapUi && !ledgerV1,
    );

    void invalidateBilling() => _refreshAfterBillingMutation(ref);

    return DriverSubscriptionGateBody(
      colors: colors,
      typography: typography,
      summary: summary,
      loading: false,
      errorMessage: null,
      onBack: () => context.pop(),
      onViewHistory: () => context.push('/driver/billing/history'),
      onPayNow: () => _handlePayment(context, ref, billingStatus),
      onOptionalPay:
          prepay ? () => _handlePayment(context, ref, billingStatus) : null,
      onPaymentMethods:
          appleIapUi ? null : () => _openPaymentMethodsPortal(context, ref),
      onRestoreApple:
          appleIapUi ? () => _restoreAppleIapPurchases(context, ref) : null,
      onPauseSubscription: () => _runSubscriptionAction(
        context,
        ref,
        () => ref.read(driverApiProvider).pauseDriverPlatformSubscription(),
        invalidateBilling,
      ),
      onResumeSubscription: () => _runSubscriptionAction(
        context,
        ref,
        () => ref.read(driverApiProvider).resumeDriverPlatformSubscription(),
        invalidateBilling,
      ),
      onCancelSubscription: () => _confirmCancelSubscription(
        context,
        ref,
        invalidateBilling,
      ),
    );
  }

  Future<void> _runSubscriptionAction(
    BuildContext context,
    WidgetRef ref,
    Future<Map<String, dynamic>> Function() apiCall,
    VoidCallback onAfterAction,
  ) async {
    final typo = ref.read(typographyProvider);
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
                DriverStrings.billingSubscriptionWorking,
                style: typo.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
    try {
      await apiCall();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.billingSubscriptionDone)),
        );
        onAfterAction();
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        final msg = e is DioException && e.response?.data is Map
            ? (e.response!.data['error']?.toString() ??
                DriverStrings.billingSubscriptionError)
            : DriverStrings.billingSubscriptionError;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _confirmCancelSubscription(
    BuildContext context,
    WidgetRef ref,
    VoidCallback onAfterAction,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DriverStrings.billingSubscriptionCancelConfirmTitle),
        content: Text(DriverStrings.billingSubscriptionCancelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(DriverStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(DriverStrings.billingSubscriptionConfirm),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _runSubscriptionAction(
        context,
        ref,
        () => ref.read(driverApiProvider).cancelDriverPlatformSubscription(),
        onAfterAction,
      );
    }
  }

  Future<void> _handlePayment(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? billingStatus,
  ) async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final api = ref.read(driverApiProvider);
    final ledgerV1 = DriverBillingService.isLedgerV1(billingStatus);

    String? selectedPlan;
    if (!ledgerV1) {
      selectedPlan = await _pickBillingPlan(context, ref, billingStatus);
      if (selectedPlan == null || !context.mounted) return;
    }

    final bs = billingStatus ?? const <String, dynamic>{};
    if (driverStatusUsesAppleBilling(bs) && !driverAppleIapSupportedOnDevice) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.iapOnlyAvailableOnIos)),
        );
      }
      return;
    }
    final useApple =
        driverStatusUsesAppleBilling(bs) && driverAppleIapSupportedOnDevice;

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
                useApple
                    ? DriverStrings.platformFeeStartingAppleIap
                    : DriverStrings.billingPayPreparing,
                style: typo.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );

    if (useApple) {
      final plan = selectedPlan;
      if (plan == null) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        return;
      }
      final ok = await purchaseDriverPlatformAccessWithAppleIap(
        context: context,
        api: api,
        planCode: plan,
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (ok && context.mounted) {
        _refreshAfterBillingMutation(ref);
      }
      return;
    }

    Map<String, dynamic> created;
    try {
      created = await api.createDriverPlatformPayment(
        plan: ledgerV1 ? null : selectedPlan,
      );
    } catch (e) {
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
      return;
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    final url = created['checkoutUrl'] as String?;
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.platformFeeStartError)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverMollieCheckoutScreen(
          checkoutUrl: url,
          colors: colors,
          typo: typo,
        ),
      ),
    );

    if (success == true && context.mounted) {
      final paymentId = created['mollie_payment_id']?.toString();
      if (paymentId != null && paymentId.isNotEmpty) {
        await api.syncDriverBillingPayment(paymentId);
      }
      _refreshAfterBillingMutation(ref);
    }
  }

  Future<String?> _pickBillingPlan(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? billingStatus,
  ) async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final plans = parseServerBillingPlans(billingStatus);
    return pickDriverBillingPlanCode(
      context,
      colors: colors,
      typo: typo,
      plans: plans,
    );
  }

  Future<void> _openPaymentMethodsPortal(BuildContext context, WidgetRef ref) async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final api = ref.read(driverApiProvider);

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
                DriverStrings.billingPayPreparing,
                style: typo.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );

    String? url;
    try {
      url = await api.fetchDriverPaymentMethodsPortalUrl();
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        final msg = e is DioException && e.response?.data is Map
            ? (e.response!.data['error']?.toString() ??
                DriverStrings.billingPaymentMethodsUnavailable)
            : DriverStrings.billingPaymentMethodsUnavailable;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    final portal = url;
    if (portal == null || portal.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.billingPaymentMethodsUnavailable)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DriverMollieCheckoutScreen(
          checkoutUrl: portal,
          colors: colors,
          typo: typo,
          appBarTitle: DriverStrings.billingPaymentMethodsPortalTitle,
          successUrlContains: null,
          autoPopOnSuccessUrlMatch: false,
        ),
      ),
    );
    if (context.mounted) {
      ref.invalidate(driverBillingStatusProvider);
      ref.invalidate(driverPaymentLedgerProvider);
      unawaited(refreshDriverRuntime(ref));
    }
  }

  Future<void> _restoreAppleIapPurchases(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final typo = ref.read(typographyProvider);
    final api = ref.read(driverApiProvider);
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
                DriverStrings.billingPayPreparing,
                style: typo.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
    final ok = await restoreDriverPlatformAccessAppleIap(
      context: context,
      api: api,
    );
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (ok && context.mounted) {
      ref.invalidate(driverBillingStatusProvider);
      ref.invalidate(driverProfileProvider);
      ref.invalidate(driverPaymentLedgerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.billingRestoreDone)),
      );
    }
  }
}
