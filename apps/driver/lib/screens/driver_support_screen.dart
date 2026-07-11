import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import '../utils/driver_ticket_navigation.dart';
import '../widgets/driver_help_hub_body.dart';

class DriverSupportScreen extends ConsumerStatefulWidget {
  const DriverSupportScreen({super.key});

  @override
  ConsumerState<DriverSupportScreen> createState() =>
      _DriverSupportScreenState();
}

class _DriverSupportScreenState extends ConsumerState<DriverSupportScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _staffUser = false;
  bool _fleetManager = false;

  @override
  void initState() {
    super.initState();
    _staffUser = _isStaffUser();
    _loadTickets();
    _loadFleetAccess();
  }

  bool _isStaffUser() {
    final user = HeyCabySupabase.client.auth.currentUser;
    if (user == null) return false;
    final appMeta = user.appMetadata;
    final role = (appMeta['role'] ?? appMeta['user_role'])?.toString();
    return role == 'admin' || role == 'super_admin';
  }

  Future<void> _loadFleetAccess() async {
    final res =
        await ref.read(driverDataServiceProvider).fetchFleetHandoverVehicles();
    if (!mounted) return;
    final raw = res?['items'];
    final hasVehicles = raw is List && raw.isNotEmpty;
    setState(() => _fleetManager = res?['ok'] == true && hasVehicles);
  }

  Future<void> _loadTickets() async {
    try {
      final client = HeyCabySupabase.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final res = await client
          .from('tickets')
          .select('id, status, messages, created_at, category, ride_request_id')
          .eq('user_type', 'driver')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3);
      if (!mounted) return;
      setState(() {
        _tickets = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DriverHelpHubTicketPreview> _mapTickets() {
    return _tickets.map((ticket) {
      final status = ticket['status'] as String? ?? 'open';
      final category = ticket['category'] as String? ?? '';
      final messages = _normalizeMessages(ticket['messages']);
      final hasDriverReply = messages.any((m) {
        if (m is! Map) return false;
        final map = Map<String, dynamic>.from(m);
        if (map['role'] == 'user') return true;
        return map['sender_type'] == 'driver';
      });

      late String statusLabel;
      late DriverStatusTone statusTone;
      if (status == 'closed' || status == 'resolved') {
        statusLabel = DriverStrings.ticketStatusResolved;
        statusTone = DriverStatusTone.success;
      } else if (hasDriverReply) {
        statusLabel = DriverStrings.ticketStatusInProgress;
        statusTone = DriverStatusTone.warning;
      } else {
        statusLabel = DriverStrings.ticketStatusNoResponse;
        statusTone = DriverStatusTone.error;
      }

      return DriverHelpHubTicketPreview(
        category: category.isNotEmpty ? category : DriverStrings.overige,
        statusLabel: statusLabel,
        statusTone: statusTone,
      );
    }).toList();
  }

  List<dynamic> _normalizeMessages(dynamic raw) {
    if (raw is List) return raw;
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return const [];
      try {
        final decoded = jsonDecode(t);
        if (decoded is List) return decoded;
        if (decoded is Map) return [decoded];
      } catch (_) {
        return [raw];
      }
    }
    if (raw is Map) return [raw];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverHelpHubBody(
      colors: colors,
      typography: typography,
      ticketsLoading: _loading,
      tickets: _mapTickets(),
      onBack: () => context.pop(),
      onViewAllTickets: () => context.push('/driver/support/threads'),
      onTicketTap: (index) {
        final ticket = _tickets[index];
        openDriverSupportTicketOrRide(
          context,
          ticketId: ticket['id'] as String,
          rideRequestId: ticket['ride_request_id'] as String?,
        );
      },
      onNewMessage: () => context.push('/driver/support/new'),
      onChatWithLee: () => context.push('/driver/support/lee'),
      onViewThreads: () => context.push('/driver/support/threads'),
      onViewFaq: () => context.push('/driver/faq'),
      onShiftHandoverAudit: _staffUser
          ? () => context.push('/driver/admin/shift-handovers')
          : null,
      onFleetAllowlist:
          _fleetManager ? () => context.push('/driver/fleet/allowlist') : null,
    );
  }
}
