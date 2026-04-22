import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

class DriverSupportScreen extends ConsumerWidget {
  const DriverSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          DriverStrings.ondersteuning,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RecentTicketsSection(colors: colors, typo: typo),
          const SizedBox(height: 16),
          _ContactSection(colors: colors, typo: typo),
        ],
      ),
    );
  }
}

class _RecentTicketsSection extends ConsumerWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _RecentTicketsSection({
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRecentTickets(),
      builder: (context, snap) {
        final tickets = snap.data ?? [];
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
                    DriverStrings.recenteRitten,
                    style: typo.titleMedium.copyWith(color: colors.text),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/driver/support/threads'),
                    child: Text(
                      '${DriverStrings.alleZien} →',
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
                    DriverStrings.geenBerichten,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ),
              ...tickets.map((t) => _TicketRow(
                    ticket: t,
                    colors: colors,
                    typo: typo,
                    onTap: () => context
                        .push('/driver/support/chat/${t['id']}'),
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentTickets() async {
    try {
      final client = HeyCabySupabase.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];
      final res = await client
          .from('tickets')
          .select('id, status, messages, created_at, category')
          .eq('user_type', 'driver')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }
}

class _TicketRow extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _TicketRow({
    required this.ticket,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final messages = ticket['messages'] as List? ?? [];
    final status = ticket['status'] as String? ?? 'open';
    final category = ticket['category'] as String? ?? '';
    final hasDriverReply = messages.any((m) {
      if (m is! Map) return false;
      final map = Map<String, dynamic>.from(m);
      if (map['role'] == 'user') return true;
      return map['sender_type'] == 'driver';
    });

    String statusLabel;
    Color statusColor;
    if (status == 'closed' || status == 'resolved') {
      statusLabel = DriverStrings.ticketStatusResolved;
      statusColor = colors.success;
    } else if (hasDriverReply) {
      statusLabel = DriverStrings.ticketStatusInProgress;
      statusColor = colors.warning;
    } else {
      statusLabel = DriverStrings.ticketStatusNoResponse;
      statusColor = colors.error;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.isNotEmpty ? category : DriverStrings.overige,
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

  const _ContactSection({required this.colors, required this.typo});

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
            'Contact',
            style: typo.titleMedium.copyWith(color: colors.text),
          ),
          const SizedBox(height: 8),
          _ContactRow(
            icon: Icons.add_comment_outlined,
            label: DriverStrings.nieuwBericht,
            colors: colors,
            typo: typo,
            onTap: () => context.push('/driver/support/new'),
          ),
          Divider(color: colors.border, height: 1),
          _ContactRow(
            icon: Icons.chat_outlined,
            label: DriverStrings.berichten,
            colors: colors,
            typo: typo,
            onTap: () => context.push('/driver/support/threads'),
          ),
          Divider(color: colors.border, height: 1),
          _ContactRow(
            icon: Icons.help_outline,
            label: DriverStrings.helpArtikelen,
            colors: colors,
            typo: typo,
            onTap: () => context.push('/driver/faq'),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: colors.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: typo.bodyMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSoft, size: 20),
          ],
        ),
      ),
    );
  }
}
