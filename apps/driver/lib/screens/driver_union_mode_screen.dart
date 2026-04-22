import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';

/// Step 12 — Driver Union Mode screen.
class DriverUnionModeScreen extends ConsumerStatefulWidget {
  const DriverUnionModeScreen({super.key});

  @override
  ConsumerState<DriverUnionModeScreen> createState() => _DriverUnionModeScreenState();
}

class _DriverUnionModeScreenState extends ConsumerState<DriverUnionModeScreen> {
  RealtimeChannel? _signalsChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _signalsChannel = Supabase.instance.client
          .channel('market_signals')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'driver_market_signals',
            callback: (_) => ref.invalidate(marketSignalsProvider),
          )
          .subscribe();
    });
  }

  @override
  void dispose() {
    if (_signalsChannel != null) {
      Supabase.instance.client.removeChannel(_signalsChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    final dashboardAsync = ref.watch(unionDashboardProvider);
    final signalsAsync = ref.watch(marketSignalsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DriverStrings.driverUnionMode,
              style: typo.headingLarge.copyWith(color: colors.text, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(
              DriverStrings.driverUnionModeSubtitle,
              style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(unionDashboardProvider);
            ref.invalidate(marketSignalsProvider);
            await Future.wait([
              ref.read(unionDashboardProvider.future),
              ref.read(marketSignalsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              dashboardAsync.when(
                data: (rows) => _MarketBalanceCard(rows: rows, colors: colors, typo: typo),
                loading: () => _LoadingCard(colors: colors),
                error: (_, __) => _ErrorCard(text: 'Could not load dashboard', colors: colors, typo: typo),
              ),
              const SizedBox(height: 12),
              dashboardAsync.when(
                data: (rows) => _AverageFareCard(rows: rows, colors: colors, typo: typo),
                loading: () => _LoadingCard(colors: colors),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              dashboardAsync.when(
                data: (rows) => _ZoneSaturationCard(rows: rows, colors: colors, typo: typo),
                loading: () => _LoadingCard(colors: colors),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              dashboardAsync.when(
                data: (rows) => _CollectiveSurgeCard(rows: rows, colors: colors, typo: typo),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              _SignalsCard(
                signalsAsync: signalsAsync,
                colors: colors,
                typo: typo,
                onCompose: () => _showComposeSignal(context, ref, colors, typo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final HeyCabyColorTokens colors;
  const _LoadingCard({required this.colors});
  @override
  Widget build(BuildContext context) => Container(
        height: 120,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Center(child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2)),
      );
}

class _ErrorCard extends StatelessWidget {
  final String text;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  const _ErrorCard({required this.text, required this.colors, required this.typo});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Text(text, style: typo.bodyMedium.copyWith(color: colors.textSoft)),
      );
}

class _MarketBalanceCard extends StatelessWidget {
  final List<UnionDashboardRow> rows;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  const _MarketBalanceCard({required this.rows, required this.colors, required this.typo});

  @override
  Widget build(BuildContext context) {
    final passengers = rows.fold<int>(0, (a, b) => a + b.passengersWaiting);
    final drivers = rows.fold<int>(0, (a, b) => a + b.driversOnline);
    final balance = passengers > drivers ? 'high_demand' : (drivers > passengers ? 'saturated' : 'balanced');
    final balanceColor = balance == 'high_demand'
        ? colors.success
        : (balance == 'balanced' ? colors.warning : colors.error);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Marktbalans', style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricPill(label: 'Passagiers', value: '$passengers', colors: colors, typo: typo),
              const SizedBox(width: 8),
              _MetricPill(label: 'Chauffeurs', value: '$drivers', colors: colors, typo: typo),
              const SizedBox(width: 8),
              _MetricPill(label: 'Balans', value: balance == 'high_demand' ? 'Groen' : (balance == 'balanced' ? 'Amber' : 'Rood'), colors: colors, typo: typo, valueColor: balanceColor),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (_, c) {
              final total = (passengers + drivers).clamp(1, 1000000);
              final leftW = c.maxWidth * (passengers / total);
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(width: leftW, height: 10, color: colors.accent),
                    Expanded(child: Container(height: 10, color: colors.border)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color? valueColor;
  const _MetricPill({required this.label, required this.value, required this.colors, required this.typo, this.valueColor});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: typo.labelSmall.copyWith(color: colors.textSoft)),
              const SizedBox(height: 4),
              Text(value, style: typo.titleMedium.copyWith(color: valueColor ?? colors.text, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _AverageFareCard extends StatelessWidget {
  final List<UnionDashboardRow> rows;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  const _AverageFareCard({required this.rows, required this.colors, required this.typo});

  @override
  Widget build(BuildContext context) {
    final top = [...rows]..sort((a, b) => (b.avgOfferedFare ?? 0).compareTo(a.avgOfferedFare ?? 0));
    final list = top.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gemiddelde ritprijs', style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final r in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(r.zoneName ?? '—', style: typo.bodyMedium.copyWith(color: colors.text))),
                  Text(
                    r.avgOfferedFare != null ? '€${r.avgOfferedFare!.toStringAsFixed(2)}' : '—',
                    style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoneSaturationCard extends StatelessWidget {
  final List<UnionDashboardRow> rows;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  const _ZoneSaturationCard({required this.rows, required this.colors, required this.typo});

  Color dot(String? balance) {
    switch (balance) {
      case 'high_demand':
        return colors.success;
      case 'saturated':
        return colors.error;
      default:
        return colors.textSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Zone bezetting', style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final r = rows[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: dot(r.marketBalance), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(r.zoneName ?? '—', style: typo.bodySmall.copyWith(color: colors.text)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectiveSurgeCard extends StatelessWidget {
  final List<UnionDashboardRow> rows;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  const _CollectiveSurgeCard({required this.rows, required this.colors, required this.typo});

  @override
  Widget build(BuildContext context) {
    final fares = rows.map((r) => r.avgOfferedFare).whereType<double>().toList();
    if (fares.isEmpty) return const SizedBox.shrink();
    final avg = fares.reduce((a, b) => a + b) / fares.length;
    final candidate = rows.firstWhere(
      (r) => r.marketBalance == 'high_demand' && (r.avgOfferedFare ?? avg) < avg * 0.85,
      orElse: () => const UnionDashboardRow(),
    );
    if (candidate.zoneName == null) return const SizedBox.shrink();
    final suggested = (avg * 1.05);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.25)),
      ),
      child: Text(
        '${candidate.zoneName} heeft hoge vraag — overweeg €${suggested.toStringAsFixed(2)}/km',
        style: typo.bodyMedium.copyWith(color: colors.text),
      ),
    );
  }
}

class _SignalsCard extends StatelessWidget {
  final AsyncValue<List<DriverMarketSignal>> signalsAsync;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onCompose;

  const _SignalsCard({
    required this.signalsAsync,
    required this.colors,
    required this.typo,
    required this.onCompose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chauffeurssignalen', style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: onCompose,
                icon: Icon(Icons.add, color: colors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          signalsAsync.when(
            data: (signals) {
              if (signals.isEmpty) {
                return Text('Nog geen signalen.', style: typo.bodySmall.copyWith(color: colors.textSoft));
              }
              return Column(
                children: signals.take(10).map((s) => _SignalRow(signal: s, colors: colors, typo: typo)).toList(),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2)),
            error: (_, __) => Text('Could not load signals', style: typo.bodySmall.copyWith(color: colors.textSoft)),
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends ConsumerWidget {
  final DriverMarketSignal signal;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _SignalRow({required this.signal, required this.colors, required this.typo});

  String iconFor(String t) {
    switch (t) {
      case 'police':
        return '🚔';
      case 'road_closure':
        return '🚧';
      case 'event':
        return '🎉';
      case 'high_demand':
        return '⬆️';
      case 'low_demand':
        return '⬇️';
      default:
        return '📍';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            iconFor(signal.signalType),
            style: typo.bodyLarge.copyWith(fontSize: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(signal.zoneId, style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600)),
                if (signal.description != null && signal.description!.isNotEmpty)
                  Text(signal.description!, style: typo.bodySmall.copyWith(color: colors.textSoft)),
              ],
            ),
          ),
          Text('${signal.upvotes}', style: typo.bodySmall.copyWith(color: colors.textSoft)),
          IconButton(
            onPressed: () async {
              await ref.read(driverDataServiceProvider).upvoteMarketSignal(signal);
              ref.invalidate(marketSignalsProvider);
            },
            icon: Icon(Icons.thumb_up_alt_outlined, color: colors.textSoft, size: 18),
          ),
        ],
      ),
    );
  }
}

void _showComposeSignal(
  BuildContext context,
  WidgetRef ref,
  HeyCabyColorTokens colors,
  HeyCabyTypography typo,
) {
  final zoneCtrl = TextEditingController();
  String type = 'high_demand';
  final descCtrl = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(
        builder: (_, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nieuw signaal', style: typo.headingLarge.copyWith(color: colors.text)),
              const SizedBox(height: 12),
              TextField(
                controller: zoneCtrl,
                decoration: const InputDecoration(labelText: 'Zone ID'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in ['police', 'road_closure', 'event', 'high_demand', 'low_demand'])
                    ChoiceChip(
                      label: Text(t),
                      selected: type == t,
                      onSelected: (_) => setState(() => type = t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Omschrijving (optioneel)'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final zoneId = zoneCtrl.text.trim();
                  if (zoneId.isEmpty) return;
                  await ref.read(driverDataServiceProvider).createOrUpvoteMarketSignal(
                        zoneId: zoneId,
                        signalType: type,
                        description: descCtrl.text,
                      );
                  ref.invalidate(marketSignalsProvider);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Plaatsen'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
