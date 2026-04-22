import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

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
          .select('id, status, messages, created_at, updated_at, category')
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

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          DriverStrings.berichten,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? Center(
                  child: Text(
                    DriverStrings.geenBerichten,
                    style: typo.bodyMedium.copyWith(color: colors.textSoft),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ThreadRow(
                    ticket: _tickets[i],
                    colors: colors,
                    typo: typo,
                    onTap: () {
                      final id = _tickets[i]['id'] as String;
                      context.push('/driver/support/chat/$id');
                    },
                  ),
                ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ThreadRow({
    required this.ticket,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final messages = ticket['messages'] as List? ?? [];
    final status = ticket['status'] as String? ?? 'open';
    final category = ticket['category'] as String? ?? DriverStrings.overige;
    final lastMsg = messages.isEmpty
        ? ''
        : _supportMessagePreview(messages.last);
    final updatedAt = DateTime.tryParse(
        ticket['updated_at'] as String? ?? ticket['created_at'] as String? ?? '');
    final timeStr = updatedAt != null
        ? DateFormat('dd MMM HH:mm').format(updatedAt.toLocal())
        : '';

    final isClosed = status == 'closed' || status == 'resolved';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category,
                        style: typo.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isClosed
                              ? colors.success.withValues(alpha: 0.1)
                              : colors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isClosed
                              ? DriverStrings.ticketStatusResolved
                              : DriverStrings.open,
                          style: typo.labelSmall.copyWith(
                            color: isClosed ? colors.success : colors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: typo.labelSmall.copyWith(color: colors.textSoft),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, color: colors.textSoft, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
