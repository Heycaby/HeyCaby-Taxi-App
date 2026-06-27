import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../constants/benelux_airports.dart';
import '../../screens/location_required_screen.dart';
import '../../services/booking_airport_selection.dart';

class HomePopularAirportsSection extends ConsumerWidget {
  const HomePopularAirportsSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airports = homePopularAirports;
    if (airports.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
            child: Text(
              l10n.homePopularAirportsTitle,
              style: typo.labelLarge.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final airport in airports)
                _AirportChip(
                  colors: colors,
                  typo: typo,
                  label: _chipLabel(airport),
                  onTap: () async {
                    final ok = await ensureLocationForBooking(
                      context: context,
                      ref: ref,
                    );
                    if (!ok || !context.mounted) return;
                    await startBookingWithAirportDestination(
                      ref: ref,
                      context: context,
                      airport: airport,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _chipLabel(BeneluxAirport airport) {
    switch (airport.iata) {
      case 'AMS':
        return l10n.homeAirportChipSchiphol;
      case 'RTM':
        return l10n.homeAirportChipRotterdam;
      case 'EIN':
        return l10n.homeAirportChipEindhoven;
      case 'BRU':
        return l10n.homeAirportChipBrussels;
      default:
        return '${airport.iata} · ${airport.city}';
    }
  }
}

class _AirportChip extends StatelessWidget {
  const _AirportChip({
    required this.colors,
    required this.typo,
    required this.label,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flight_takeoff_rounded,
                  size: 16,
                  color: colors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: typo.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
