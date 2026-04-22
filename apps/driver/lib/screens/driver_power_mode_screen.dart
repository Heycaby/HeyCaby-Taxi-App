import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';

/// Step 11 — Driver Power Mode screen.
class DriverPowerModeScreen extends ConsumerStatefulWidget {
  const DriverPowerModeScreen({super.key});

  @override
  ConsumerState<DriverPowerModeScreen> createState() => _DriverPowerModeScreenState();
}

class _DriverPowerModeScreenState extends ConsumerState<DriverPowerModeScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final driverId = await ref.read(driverIdProvider.future);
      if (!mounted || driverId == null) return;
      _channel = Supabase.instance.client
          .channel('driver_power')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'driver_power_suggestions',
            callback: (_) => ref.invalidate(powerSuggestionsProvider),
          )
          .subscribe();
    });
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final cardsAsync = ref.watch(powerSuggestionsProvider);

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
              DriverStrings.driverPowerMode,
              style: typo.headingLarge.copyWith(color: colors.text, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(
              DriverStrings.driverPowerModeSubtitle,
              style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: cardsAsync.when(
          data: (cards) {
            if (cards.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Alles ziet er goed uit 👍 We laten je weten als er kansen zijn.',
                    style: typo.bodyLarge.copyWith(color: colors.textSoft),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _PowerCard(
                card: cards[i],
                colors: colors,
                typo: typo,
                onDismiss: () async {
                  final driverId = await ref.read(driverIdProvider.future);
                  if (driverId == null) return;
                  await ref
                      .read(driverDataServiceProvider)
                      .dismissPowerCard(cardId: cards[i].id, driverId: driverId);
                  ref.invalidate(powerSuggestionsProvider);
                },
              ),
            );
          },
          loading: () => Center(child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2)),
          error: (_, __) => Center(
            child: Text('Could not load Power Mode', style: typo.bodyMedium.copyWith(color: colors.textSoft)),
          ),
        ),
      ),
    );
  }
}

class _PowerCard extends StatelessWidget {
  final DriverPowerCard card;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onDismiss;

  const _PowerCard({
    required this.card,
    required this.colors,
    required this.typo,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final type = card.cardType;
    final title = card.title ?? _fallbackTitle(type);
    final subtitle = card.subtitle;

    final Color? headerColor = switch (type) {
      'high_demand' => colors.accent,
      'surge_opportunity' => colors.warning,
      _ => null,
    };

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headerColor != null)
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: typo.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onDismiss,
                      icon: Icon(Icons.close, color: colors.textSoft, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                _PowerCardBody(card: card, colors: colors, typo: typo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fallbackTitle(String type) {
    return switch (type) {
      'price_suggestion' => 'Tariefsuggestie',
      'return_trip' => DriverStrings.returnTrips,
      'idle_warning' => 'Je staat stil',
      'goal_tracker' => 'Doel tracker',
      _ => 'Suggestie',
    };
  }
}

class _PowerCardBody extends StatelessWidget {
  final DriverPowerCard card;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _PowerCardBody({required this.card, required this.colors, required this.typo});

  @override
  Widget build(BuildContext context) {
    switch (card.cardType) {
      case 'high_demand':
      case 'surge_opportunity':
        return Row(
          children: [
            Expanded(
              child: Text(
                card.valueA != null ? card.valueA!.toStringAsFixed(0) : '—',
                style: typo.displayMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              onPressed: card.actionUrl == null
                  ? null
                  : () => launchUrl(
                        Uri.parse(card.actionUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
              child: const Text('Navigeer'),
            ),
          ],
        );
      case 'return_trip':
        return FilledButton(
          onPressed: () => context.push('/driver/return-trips'),
          child: const Text('Rit bekijken'),
        );
      case 'idle_warning':
        return FilledButton(
          onPressed: () => context.pop(),
          child: const Text('Drukke zones bekijken'),
        );
      case 'goal_tracker':
        final earned = card.valueA ?? 0;
        final target = card.valueB ?? 0;
        final frac = target > 0 ? (earned / target).clamp(0.0, 1.0) : 0.0;
        return Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: frac,
                strokeWidth: 10,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '€${earned.toStringAsFixed(0)} of €${target.toStringAsFixed(0)}',
                style: typo.bodyMedium.copyWith(color: colors.text),
              ),
            ),
          ],
        );
      case 'price_suggestion':
      default:
        return Text(
          'Bekijk suggestie in Driver Hub.',
          style: typo.bodySmall.copyWith(color: colors.textSoft),
        );
    }
  }
}
