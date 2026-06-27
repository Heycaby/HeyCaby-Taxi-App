import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class RiderSupportScreen extends ConsumerWidget {
  const RiderSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

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
          l10n.support,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RecentTicketsSection(colors: colors, typo: typo, l10n: l10n),
          const SizedBox(height: 16),
          _ContactSection(colors: colors, typo: typo, l10n: l10n),
        ],
      ),
    );
  }
}

class _RecentTicketsSection extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _RecentTicketsSection({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _recentTicketsStream(),
      builder: (context, snap) {
        final tickets = _sortByLastUpdate(snap.data ?? []);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.supportRecentHeading,
                    style: typo.titleMedium.copyWith(color: colors.text),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/support/threads'),
                    child: Text(
                      '${l10n.supportSeeAll} →',
                      style: typo.bodySmall.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (tickets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.supportNoThreads,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ),
              ...tickets.map((t) => _TicketRow(
                    ticket: t,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onTap: () => context.push('/support/chat/${t['id']}'),
                  )),
            ],
          ),
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _recentTicketsStream() {
    final client = HeyCabySupabase.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const Stream<List<Map<String, dynamic>>>.empty();
    return client.from('tickets').stream(primaryKey: ['id']).map(
      (rows) => rows
          .where((r) => r['user_type'] == 'rider' && r['user_id'] == userId)
          .map((r) => Map<String, dynamic>.from(r))
          .toList(),
    );
  }

  List<Map<String, dynamic>> _sortByLastUpdate(
      List<Map<String, dynamic>> rows) {
    rows.sort((a, b) {
      final aAt = DateTime.tryParse(
            (a['updated_at'] as String?) ?? (a['created_at'] as String?) ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = DateTime.tryParse(
            (b['updated_at'] as String?) ?? (b['created_at'] as String?) ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    if (rows.length > 3) return rows.take(3).toList();
    return rows;
  }
}

class _TicketRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _TicketRow({
    required this.ticket,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final messages = ticket['messages'] as List? ?? [];
    final status = ticket['status'] as String? ?? 'open';
    final category = ticket['category'] as String? ?? '';
    final updatedAtRaw =
        ticket['updated_at'] as String? ?? ticket['created_at'] as String?;
    final hasUserMsg = messages.any((m) {
      if (m is! Map) return false;
      final map = Map<String, dynamic>.from(m);
      if (map['role'] == 'user') return true;
      return map['sender_type'] == 'rider';
    });

    final s = status.toLowerCase();
    final isClosed = s == 'closed' || s == 'resolved' || s == 'auto_resolved';
    final String statusLabel;
    final Color statusColor;
    if (isClosed) {
      statusLabel = l10n.supportTicketResolved;
      statusColor = colors.success;
    } else if (hasUserMsg) {
      statusLabel = l10n.supportTicketOpen;
      statusColor = colors.warning;
    } else {
      statusLabel = l10n.supportTicketOpen;
      statusColor = colors.textSoft;
    }

    final summary = (ticket['resolution_summary'] as String?)?.trim() ?? '';
    final outcome = (ticket['resolution_outcome'] as String?)?.trim() ?? '';
    final preview = messages.isNotEmpty
        ? (() {
            final raw = messages.last;
            if (raw is! Map) return '';
            final map = Map<String, dynamic>.from(raw);
            final content = (map['content'] as String?)?.trim();
            if (content != null && content.isNotEmpty) return content;
            return (map['body'] as String?)?.trim() ?? '';
          })()
        : '';
    final updatedAt = DateTime.tryParse(updatedAtRaw ?? '');
    final timeLabel = updatedAt == null
        ? ''
        : '${updatedAt.day.toString().padLeft(2, '0')}-'
            '${updatedAt.month.toString().padLeft(2, '0')} '
            '${updatedAt.hour.toString().padLeft(2, '0')}:'
            '${updatedAt.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.isNotEmpty ? category : l10n.supportOtherCategory,
                    style: typo.bodyMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: typo.bodySmall.copyWith(color: statusColor),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(color: colors.textSoft),
                    ),
                  ],
                  if (isClosed && summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.supportResolutionSummary}: $summary',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                  ],
                  if (isClosed && outcome.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.supportResolutionOutcome}: $outcome',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                  ],
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: typo.labelSmall.copyWith(color: colors.textSoft),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSoft, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _ContactSection({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.supportHubContact,
            style: typo.titleMedium.copyWith(color: colors.text),
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.add_comment_outlined,
            label: l10n.supportNewThread,
            colors: colors,
            typo: typo,
            onTap: () => context.push('/support/new'),
          ),
          Divider(color: colors.border, height: 1),
          _ChatWithYazRow(
            colors: colors,
            typo: typo,
            onTap: () => context.push('/support/yaz'),
          ),
          Divider(color: colors.border, height: 1),
          _ContactRow(
            icon: Icons.chat_outlined,
            label: l10n.supportAllThreads,
            colors: colors,
            typo: typo,
            onTap: () => context.push('/support/threads'),
          ),
          Divider(color: colors.border, height: 1),
          _ContactRow(
            icon: Icons.help_outline,
            label: l10n.supportHelpArticles,
            colors: colors,
            typo: typo,
            onTap: () => context.push('/faq'),
          ),
        ],
      ),
    );
  }
}

class _ChatWithYazRow extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ChatWithYazRow({
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.smart_toy_outlined,
                  color: colors.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Chat with Yaz',
                        style: typo.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'AI',
                          style: typo.labelSmall.copyWith(
                            color: colors.card,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Urgent AI support assistant',
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.accent),
      title: Text(label, style: typo.bodyMedium.copyWith(color: colors.text)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: typo.bodySmall.copyWith(color: colors.textSoft),
            ),
      minVerticalPadding: subtitle == null ? 10 : 8,
      trailing: Icon(Icons.chevron_right, color: colors.textSoft),
      onTap: onTap,
    );
  }
}
