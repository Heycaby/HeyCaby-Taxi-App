import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../widgets/booking/booking_flow_screen_header.dart';

String _supportMessagePreview(dynamic raw) {
  if (raw is! Map) return '';
  final m = Map<String, dynamic>.from(raw);
  final c = m['content'] as String?;
  if (c != null && c.isNotEmpty) return c;
  return m['body'] as String? ?? '';
}

bool _ticketClosed(String? status) {
  if (status == null) return false;
  final s = status.toLowerCase();
  return s == 'closed' || s == 'resolved' || s == 'auto_resolved';
}

class RiderSupportThreadsScreen extends ConsumerStatefulWidget {
  const RiderSupportThreadsScreen({super.key});

  @override
  ConsumerState<RiderSupportThreadsScreen> createState() =>
      _RiderSupportThreadsScreenState();
}

class _RiderSupportThreadsScreenState
    extends ConsumerState<RiderSupportThreadsScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final client = HeyCabySupabase.client;
      String? userId = client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        try {
          final authRes = await client.auth.signInAnonymously();
          userId = authRes.user?.id;
        } catch (_) {
          userId = null;
        }
      }
      if (userId == null) {
        if (mounted) {
          setState(() {
            _tickets = const [];
            _loading = false;
            _loadError = 'not_signed_in';
          });
        }
        return;
      }

      dynamic res;
      try {
        res = await client
            .from('tickets')
            .select(
              'id, status, messages, created_at, updated_at, category, resolution_summary, resolution_outcome',
            )
            .eq('user_type', 'rider')
            .eq('user_id', userId)
            .order('updated_at', ascending: false)
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        res = await client
            .from('tickets')
            .select(
              'id, status, messages, created_at, updated_at, category',
            )
            .eq('user_type', 'rider')
            .eq('user_id', userId)
            .order('updated_at', ascending: false)
            .timeout(const Duration(seconds: 12));
      }

      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString().toLowerCase().contains('timeout')
              ? 'timeout'
              : 'load_failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final ongoing =
        _tickets.where((t) => !_ticketClosed(t['status'] as String?)).toList();
    final closed =
        _tickets.where((t) => _ticketClosed(t['status'] as String?)).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.supportThreadsTitle,
              icon: Icons.forum_outlined,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                _loadError == 'timeout'
                                    ? 'Support messages are taking too long to load. Please try again.'
                                    : 'Could not load support messages. Please try again.',
                                textAlign: TextAlign.center,
                                style: typo.bodyMedium
                                    .copyWith(color: colors.textSoft),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: FilledButton(
                                onPressed: _load,
                                child: Text(l10n.tryAgain),
                              ),
                            ),
                          ],
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _tickets.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 180),
                                    Center(
                                      child: Text(
                                        l10n.supportNoThreads,
                                        style: typo.bodyMedium.copyWith(
                                          color: colors.textSoft,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    if (ongoing.isNotEmpty) ...[
                                      Text(
                                        l10n.supportSectionOngoing,
                                        style: typo.titleSmall.copyWith(
                                          color: colors.textSoft,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...ongoing.map(
                                        (t) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: _ThreadRow(
                                            ticket: t,
                                            colors: colors,
                                            typo: typo,
                                            l10n: l10n,
                                            onTap: () {
                                              final id = t['id'] as String;
                                              context.push('/support/chat/$id');
                                            },
                                          ),
                                        ),
                                      ),
                                      if (closed.isNotEmpty)
                                        const SizedBox(height: 16),
                                    ],
                                    if (closed.isNotEmpty) ...[
                                      Text(
                                        l10n.supportSectionClosed,
                                        style: typo.titleSmall.copyWith(
                                          color: colors.textSoft,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...closed.map(
                                        (t) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: _ThreadRow(
                                            ticket: t,
                                            colors: colors,
                                            typo: typo,
                                            l10n: l10n,
                                            onTap: () {
                                              final id = t['id'] as String;
                                              context.push('/support/chat/$id');
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _ThreadRow({
    required this.ticket,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final messages = (ticket['messages'] as List?) ?? [];
    final category = ticket['category'] as String? ?? '';
    final categoryLabels = <String, String>{
      'ride_issue': l10n.supportCategoryRideIssue,
      'payment': l10n.supportCategoryPayment,
      'account': l10n.supportCategoryAccount,
      'other': l10n.supportOtherCategory,
      'ai_support': l10n.supportChatWithYaz,
    };
    final updated =
        ticket['updated_at'] as String? ?? ticket['created_at'] as String?;
    final preview =
        messages.isEmpty ? '' : _supportMessagePreview(messages.last);
    final closed = _ticketClosed(ticket['status'] as String?);
    final summary = (ticket['resolution_summary'] as String?)?.trim() ?? '';
    final outcome = (ticket['resolution_outcome'] as String?)?.trim() ?? '';

    String timeStr = '';
    final parsed = DateTime.tryParse(updated ?? '');
    if (parsed != null) {
      timeStr = DateFormat('d MMM HH:mm').format(parsed.toLocal());
    }

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryLabels[category] ?? l10n.supportOtherCategory,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      closed
                          ? l10n.supportTicketResolved
                          : l10n.supportTicketOpen,
                      style: typo.labelSmall.copyWith(
                        color: closed ? colors.success : colors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typo.bodySmall.copyWith(color: colors.textSoft),
                      ),
                    ],
                    if (closed && summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.supportResolutionSummary}: $summary',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typo.bodySmall.copyWith(color: colors.textMid),
                      ),
                    ],
                    if (closed && outcome.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.supportResolutionOutcome}: $outcome',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typo.bodySmall.copyWith(color: colors.textMid),
                      ),
                    ],
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        timeStr,
                        style: typo.labelSmall.copyWith(
                          color: colors.textSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSoft),
            ],
          ),
        ),
      ),
    );
  }
}
