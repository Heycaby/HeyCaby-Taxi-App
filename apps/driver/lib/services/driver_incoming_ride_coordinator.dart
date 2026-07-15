import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import 'driver_incoming_ride_prefetch.dart';

/// One presentation gate for FCM, Realtime, notification rows, and restore.
/// Supabase owns availability; local Flutter lifecycle state never rejects an invite.
class DriverIncomingRideCoordinator {
  DriverIncomingRideCoordinator._();

  /// Canonical entry for foreground FCM, notification tap, cold start, and Realtime.
  static Future<void> openIncomingRide({
    required BuildContext context,
    required WidgetRef ref,
    required String rideRequestId,
    String? rideInviteId,
    bool foreground = false,
    bool urgent = true,
  }) =>
      present(
        context: context,
        ref: ref,
        rideRequestId: rideRequestId,
        rideInviteId: rideInviteId,
        foreground: foreground,
        urgent: urgent,
      );

  static final Set<String> _presenting = <String>{};
  static final Map<String, DateTime> _recent = <String, DateTime>{};

  static Future<void> present({
    required BuildContext context,
    required WidgetRef ref,
    required String rideRequestId,
    String? rideInviteId,
    bool foreground = false,
    bool urgent = true,
  }) async {
    final provisionalKey = rideInviteId ?? 'ride:$rideRequestId';
    if (!_claim(provisionalKey)) return;
    String? resolvedKey;

    try {
      final driverId = await ref.read(driverIdProvider.future);
      if (driverId == null || driverId.isEmpty) return;

      dynamic query = HeyCabySupabase.client
          .from('ride_request_invites')
          .select(
            'id, ride_request_id, driver_id, status, expires_at, distance_km, eta_minutes',
          )
          .eq('driver_id', driverId)
          .eq('ride_request_id', rideRequestId);
      if (rideInviteId != null && rideInviteId.isNotEmpty) {
        query = query.eq('id', rideInviteId);
      } else {
        query = query.order('invited_at', ascending: false).limit(1);
      }
      final invite = await query.maybeSingle();
      if (invite == null) {
        if (!context.mounted) return;
        _showTerminal(context, 'invite_missing');
        return;
      }

      final resolvedInviteId = invite['id']?.toString();
      final status = invite['status']?.toString();
      final expiresAt = DateTime.tryParse(
        invite['expires_at']?.toString() ?? '',
      )?.toUtc();
      if (status != 'pending' ||
          expiresAt == null ||
          !expiresAt.isAfter(DateTime.now().toUtc())) {
        if (!context.mounted) return;
        _showTerminal(context, 'invite_expired');
        return;
      }

      final ride = await HeyCabySupabase.client
          .from('ride_requests')
          .select('id, status, driver_id')
          .eq('id', rideRequestId)
          .maybeSingle();
      final rideStatus = ride?['status']?.toString() ?? '';
      if (ride == null ||
          const {
            'accepted',
            'driver_en_route',
            'driver_arrived',
            'in_progress',
            'completed',
            'cancelled',
          }.contains(rideStatus)) {
        if (!context.mounted) return;
        _showTerminal(context, 'invite_not_pending');
        return;
      }

      if (!context.mounted) return;
      final key = resolvedInviteId ?? provisionalKey;
      if (key != provisionalKey && !_claim(key)) return;
      resolvedKey = key;
      unawaited(_trace(resolvedInviteId, 'opened'));

      HapticService.heavyTap();

      if (!context.mounted) return;
      unawaited(_trace(resolvedInviteId, 'viewed'));
      final prefetch = DriverIncomingRidePrefetch(
        inviteId: resolvedInviteId,
        expiresAt: expiresAt,
        distanceKm: (invite['distance_km'] as num?)?.toDouble(),
        etaMinutes: (invite['eta_minutes'] as num?)?.toDouble(),
      );
      await context.push(
        '/driver/ride/new/$rideRequestId',
        extra: prefetch.toRouteExtra(urgent: urgent),
      );
    } catch (_) {
      if (context.mounted) {
        _showTerminal(context, 'invite_missing');
      }
    } finally {
      _presenting.remove(provisionalKey);
      if (rideInviteId != null) _presenting.remove(rideInviteId);
      if (resolvedKey != null) _presenting.remove(resolvedKey);
    }
  }

  static bool _claim(String key) {
    final now = DateTime.now();
    _recent.removeWhere(
      (_, at) => now.difference(at) > const Duration(seconds: 8),
    );
    if (_presenting.contains(key) || _recent.containsKey(key)) return false;
    _presenting.add(key);
    _recent[key] = now;
    return true;
  }

  static Future<void> _trace(String? inviteId, String event) async {
    if (inviteId == null || inviteId.isEmpty) return;
    try {
      await HeyCabySupabase.client.rpc(
        'fn_driver_trace_invite',
        params: {'p_invite_id': inviteId, 'p_event': event},
      );
    } catch (_) {
      // Observability must never block the invite decision surface.
    }
  }

  static void _showTerminal(BuildContext context, String reason) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(DriverStrings.acceptRideErrorMessage(reason))),
    );
  }
}
