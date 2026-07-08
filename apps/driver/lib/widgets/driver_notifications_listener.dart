import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/driver_notification_router.dart';
import '../utils/driver_rider_cancelled_flow.dart';
import '../models/driver_shift_handover_prompt_args.dart';
import '../utils/driver_shift_handover_security_alert.dart';
import '../utils/driver_taxi_session_revoked_flow.dart';
import '../widgets/driver_shift_handover_prompt.dart';
import '../services/sound_service.dart';

/// Supabase-first in-app notifications with Realtime refetch + light backup poll.
class DriverNotificationsListener extends ConsumerStatefulWidget {
  const DriverNotificationsListener({super.key});

  @override
  ConsumerState<DriverNotificationsListener> createState() =>
      _DriverNotificationsListenerState();
}

class _DriverNotificationsListenerState
    extends ConsumerState<DriverNotificationsListener>
    with WidgetsBindingObserver {
  static const _notifications = AppNotificationsService();

  Timer? _backupPollTimer;
  Timer? _debounceTimer;
  RealtimeChannel? _realtimeChannel;
  bool _busy = false;
  bool _notificationsDisabled = false;
  final Set<String> _handledIds = <String>{};

  String? _lastSubscribedUid;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = HeyCabySupabase.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      final uid = event.session?.user.id;
      if (uid != null && uid.isNotEmpty && uid != _lastSubscribedUid) {
        _subscribeRealtime();
        _poll();
      }
    });
    _subscribeRealtime();
    _poll();
    _backupPollTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backupPollTimer?.cancel();
    _debounceTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _poll();
    }
  }

  void _subscribeRealtime() {
    final uid = HeyCabySupabase.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    _lastSubscribedUid = uid;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _notifications.subscribeToTableChanges(
      channelName: 'driver-notifications-$uid',
      onChange: (_) => _schedulePoll(),
      filterUserId: uid,
      filterUserType: 'driver',
    );
  }

  void _schedulePoll() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), _poll);
  }

  Future<void> _poll() async {
    if (_busy || !mounted || _notificationsDisabled) return;
    _busy = true;
    try {
      final api = ref.read(driverApiProvider);
      final unread = await api.getNotifications(unreadOnly: true, limit: 20);
      if (!mounted || unread.isEmpty) return;

      // API returns newest first; we show older first for natural order.
      final ordered = unread.reversed.toList();
      for (final n in ordered) {
        if (_handledIds.contains(n.id)) continue;
        _handledIds.add(n.id);

        final category = (n.category ?? '').toLowerCase();
        if (category == 'ride_phase') {
          final rideId = n.data?['ride_request_id']?.toString();
          if (rideId != null && rideId.isNotEmpty && mounted) {
            await handleDriverRiderCancelled(
              ref: ref,
              context: context,
              rideId: rideId,
            );
          }
          await api.markNotificationRead(n.id);
          continue;
        }
        if (category == 'incoming_ride') {
          final rideId = n.data?['ride_request_id']?.toString();
          if (rideId != null && rideId.isNotEmpty && mounted) {
            final path = GoRouterState.of(context).uri.path;
            if (!path.startsWith('/driver/ride/new/')) {
              unawaited(SoundService().playRideRequest());
              context.push('/driver/ride/new/$rideId');
            }
          }
          await api.markNotificationRead(n.id);
          continue;
        }
        if (category == 'shift_handover') {
          final requestId = n.data?['request_id']?.toString();
          if (requestId != null && requestId.isNotEmpty && mounted) {
            await showDriverShiftHandoverPrompt(
              context: context,
              ref: ref,
              args: DriverShiftHandoverPromptArgs.fromNotification(
                requestId: requestId,
                data: n.data,
                title: n.title,
                body: n.body,
              ),
            );
          }
          await api.markNotificationRead(n.id);
          continue;
        }
        if (category == 'shift_handover_fleet' ||
            category == 'shift_handover_private_attempt') {
          if (mounted) {
            await showDriverShiftHandoverSecurityAlert(
              context: context,
              ref: ref,
              category: category,
              title: n.title,
              body: n.body,
            );
          }
          await api.markNotificationRead(n.id);
          continue;
        }
        if (category == 'taxi_session_revoked') {
          if (mounted) {
            await handleDriverTaxiSessionRevoked(
              context: context,
              ref: ref,
              plate: n.data?['plate']?.toString() ??
                  n.data?['plate_normalized']?.toString(),
              reason: n.data?['reason']?.toString(),
              voluntaryEnd: n.data?['status']?.toString() == 'approved',
            );
          }
          await api.markNotificationRead(n.id);
          continue;
        }

        if (!mounted) return;
        await dispatchDriverNotification(
          context: context,
          category: n.category,
          title: n.title,
          body: n.body,
          data: n.data,
          fromTap: false,
          foreground: true,
        );
        await api.markNotificationRead(n.id);
      }
    } on DioException catch (e) {
      // Go fallback only: stop polling if unauthorized for legacy HTTP path.
      if (e.response?.statusCode == 401) {
        _notificationsDisabled = true;
      }
    } catch (_) {
      // Silent: notification polling should never break core UX.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
