import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../widgets/driver_mollie_checkout_screen.dart';

/// Ensures driver has paid platform fee when required. Returns `true` to proceed with going **available**.
Future<bool> ensureDriverPlatformFeeAllowsOnline(
  BuildContext context,
  WidgetRef ref,
) async {
  final api = ref.read(driverApiProvider);
  Map<String, dynamic> data;
  try {
    data = await api.fetchDriverStatus();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.platformFeeStatusError)),
      );
    }
    return false;
  }

  final paymentRequired = data['payment_required'] == true;
  if (!paymentRequired) return true;
  if (!context.mounted) return false;

  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);
  final weeklyCents = data['weekly_fee_cents'];
  final feeEuro = weeklyCents is num
      ? (weeklyCents / 100).toStringAsFixed(2)
      : '?';

  final pay = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(DriverStrings.platformFeeTitle, style: typo.titleLarge),
      content: Text(
        DriverStrings.platformFeeBody(feeEuro),
        style: typo.bodyMedium.copyWith(color: colors.textMid),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(DriverStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(DriverStrings.platformFeePay),
        ),
      ],
    ),
  );

  if (pay != true || !context.mounted) return false;

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
              DriverStrings.platformFeeStartingCheckout,
              style: typo.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );

  Map<String, dynamic> created;
  try {
    created = await api.createDriverPlatformPayment();
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

  try {
    data = await api.fetchDriverStatus();
  } catch (_) {
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
