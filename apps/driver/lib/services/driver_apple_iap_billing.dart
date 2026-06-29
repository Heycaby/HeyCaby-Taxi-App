import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../l10n/driver_strings.dart';

/// Matches [driverservice] `billing_provider` when App Store IAP is active.
bool driverStatusUsesAppleBilling(Map<String, dynamic> status) {
  return (status['billing_provider'] ?? '').toString().trim().toLowerCase() ==
      'apple';
}

bool get driverAppleIapSupportedOnDevice =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Must match App Store Connect and Go `AppleProductID*`.
abstract final class DriverAppleIapProductIds {
  static const String daily = 'nl.heycaby.driver.access.daily';
  static const String weekly = 'nl.heycaby.driver.access.weekly';
  static const String monthly = 'nl.heycaby.driver.access.monthly';

  static const Set<String> all = {daily, weekly, monthly};

  static String? forPlanCode(String code) {
    switch (code.trim().toLowerCase()) {
      case 'daily':
        return daily;
      case 'weekly':
        return weekly;
      case 'monthly':
        return monthly;
      default:
        return null;
    }
  }
}

Future<bool> purchaseDriverPlatformAccessWithAppleIap({
  required BuildContext context,
  required DriverApi api,
  required String planCode,
}) async {
  if (!driverAppleIapSupportedOnDevice) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.iapOnlyAvailableOnIos)),
      );
    }
    return false;
  }

  final productId = DriverAppleIapProductIds.forPlanCode(planCode);
  if (productId == null) return false;

  final available = await InAppPurchase.instance.isAvailable();
  if (!available) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.iapStoreUnavailable)),
      );
    }
    return false;
  }

  final response = await InAppPurchase.instance
      .queryProductDetails(DriverAppleIapProductIds.all);
  if (response.error != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.iapProductsLoadFailed)),
      );
    }
    return false;
  }

  ProductDetails? product;
  for (final p in response.productDetails) {
    if (p.id == productId) {
      product = p;
      break;
    }
  }
  if (product == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.iapProductsLoadFailed)),
      );
    }
    return false;
  }

  StreamSubscription<List<PurchaseDetails>>? sub;
  try {
    final completer = Completer<PurchaseDetails?>();
    sub = InAppPurchase.instance.purchaseStream.listen(
      (events) {
        for (final purchase in events) {
          if (!DriverAppleIapProductIds.all.contains(purchase.productID)) {
            continue;
          }
          if (purchase.productID != productId) continue;
          switch (purchase.status) {
            case PurchaseStatus.pending:
              break;
            case PurchaseStatus.error:
              if (!completer.isCompleted) {
                completer.completeError(
                  purchase.error ?? Exception('purchase error'),
                );
              }
              break;
            case PurchaseStatus.canceled:
              if (!completer.isCompleted) completer.complete(null);
              break;
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              if (!completer.isCompleted) completer.complete(purchase);
              break;
          }
        }
      },
      onError: (Object e, StackTrace _) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    final started = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      if (!completer.isCompleted) completer.complete(null);
    }

    PurchaseDetails? purchase;
    try {
      purchase = await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () => null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${DriverStrings.iapVerifyFailed} $e')),
        );
      }
      return false;
    }

    if (purchase == null) return false;

    final receipt = purchase.verificationData.serverVerificationData;
    if (receipt.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(DriverStrings.iapVerifyFailed)),
        );
      }
      return false;
    }

    try {
      await api.verifyAppleDriverReceipt(
        receiptData: receipt,
        planCode: planCode,
      );
    } on DioException catch (e) {
      final msg = _dioErrorMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${DriverStrings.iapVerifyFailed} $msg')),
        );
      }
      return false;
    }

    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
    return true;
  } finally {
    await sub?.cancel();
  }
}

Future<bool> restoreDriverPlatformAccessAppleIap({
  required BuildContext context,
  required DriverApi api,
}) async {
  if (!driverAppleIapSupportedOnDevice) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.iapOnlyAvailableOnIos)),
      );
    }
    return false;
  }

  final available = await InAppPurchase.instance.isAvailable();
  if (!available) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DriverStrings.iapStoreUnavailable)),
      );
    }
    return false;
  }

  StreamSubscription<List<PurchaseDetails>>? sub;
  try {
    final completer = Completer<PurchaseDetails?>();
    sub = InAppPurchase.instance.purchaseStream.listen(
      (events) {
        for (final purchase in events) {
          if (!DriverAppleIapProductIds.all.contains(purchase.productID)) {
            continue;
          }
          switch (purchase.status) {
            case PurchaseStatus.pending:
              break;
            case PurchaseStatus.error:
              if (!completer.isCompleted) {
                completer.completeError(
                  purchase.error ?? Exception('purchase error'),
                );
              }
              break;
            case PurchaseStatus.canceled:
              if (!completer.isCompleted) completer.complete(null);
              break;
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              if (!completer.isCompleted) completer.complete(purchase);
              break;
          }
        }
      },
      onError: (Object e, StackTrace _) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    await InAppPurchase.instance.restorePurchases();

    PurchaseDetails? purchase;
    try {
      purchase = await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${DriverStrings.iapRestoreFailed} $e')),
        );
      }
      return false;
    }

    if (purchase == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(DriverStrings.iapNothingToRestore)),
        );
      }
      return false;
    }

    final receipt = purchase.verificationData.serverVerificationData;
    if (receipt.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(DriverStrings.iapVerifyFailed)),
        );
      }
      return false;
    }

    try {
      await api.verifyAppleDriverReceipt(receiptData: receipt, planCode: '');
    } on DioException catch (e) {
      final msg = _dioErrorMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${DriverStrings.iapVerifyFailed} $msg')),
        );
      }
      return false;
    }

    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
    return true;
  } finally {
    await sub?.cancel();
  }
}

String _dioErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final err = data['error'] ?? data['message'];
    if (err != null && err.toString().trim().isNotEmpty) {
      return err.toString();
    }
  }
  return e.message ?? e.toString();
}
