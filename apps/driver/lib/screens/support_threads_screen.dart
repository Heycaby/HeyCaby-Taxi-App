import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import '../utils/driver_ticket_navigation.dart';
import '../utils/support_ticket_messages.dart';
import '../widgets/driver_support_inbox_body.dart';

String _supportMessagePreview(dynamic raw) {
  if (raw is! Map) return '';
  final m = Map<String, dynamic>.from(raw);
  final c = m['content'] as String?;
  if (c != null && c.isNotEmpty) return c;
  return m['body'] as String? ?? '';
}

class SupportThreadsScreen extends ConsumerStatefulWidget {
  const SupportThreadsScreen({super.key});

  @override
  ConsumerState<SupportThreadsScreen> createState() =>
      _SupportThreadsScreenState();
}

class _SupportThreadsScreenState extends ConsumerState<SupportThreadsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = HeyCabySupabase.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final res = await client
          .from('tickets')
          .select(
              'id, status, messages, created_at, updated_at, category, ride_request_id')
          .eq('user_type', 'driver')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DriverSupportInboxItem> _mapItems() {
    return _tickets.map((ticket) {
      final messages = normalizeTicketMessages(ticket['messages']);
      final status = (ticket['status'] as String? ?? 'open').toLowerCase();
      final category = ticket['category'] as String? ?? DriverStrings.overige;
      final lastMsg =
          messages.isEmpty ? '' : _supportMessagePreview(messages.last);
      final updatedAt = DateTime.tryParse(ticket['updated_at'] as String? ??
          ticket['created_at'] as String? ??
          '');
      final timeStr = updatedAt != null
          ? DateFormat('dd MMM HH:mm').format(updatedAt.toLocal())
          : null;
      final isClosed = status == 'closed' ||
          status == 'resolved' ||
          status == 'auto_resolved';

      return DriverSupportInboxItem(
        category: category,
        statusLabel:
            isClosed ? DriverStrings.ticketStatusResolved : DriverStrings.open,
        statusTone:
            isClosed ? DriverStatusTone.success : DriverStatusTone.warning,
        preview: lastMsg,
        timeLabel: timeStr,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverSupportInboxBody(
      colors: colors,
      typography: typography,
      loading: _loading,
      items: _mapItems(),
      onBack: () => context.pop(),
      onItemTap: (index) {
        final row = _tickets[index];
        openDriverSupportTicketOrRide(
          context,
          ticketId: row['id'] as String,
          rideRequestId: row['ride_request_id'] as String?,
        );
      },
    );
  }
}
