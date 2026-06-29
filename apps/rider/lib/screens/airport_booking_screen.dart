import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../widgets/booking/booking_flow_screen_header.dart';
import '../constants/benelux_airports.dart';
import '../services/booking_airport_selection.dart';

/// Pick a Benelux airport as destination for a fast airport drop-off flow.
class AirportBookingScreen extends ConsumerStatefulWidget {
  const AirportBookingScreen({super.key});

  @override
  ConsumerState<AirportBookingScreen> createState() =>
      _AirportBookingScreenState();
}

class _AirportBookingScreenState extends ConsumerState<AirportBookingScreen> {
  final _searchController = TextEditingController();
  List<BeneluxAirport> _filtered = List.of(kBeneluxAirports);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    setState(() => _filtered = filterAirports(q));
  }

  String _countryLabel(String code, AppLocalizations l10n) {
    switch (code) {
      case 'NL':
        return l10n.airportSectionNetherlands;
      case 'BE':
        return l10n.airportSectionBelgium;
      case 'LU':
        return l10n.airportSectionLuxembourg;
      default:
        return code;
    }
  }

  Future<void> _selectAirport(BeneluxAirport a) async {
    await startBookingWithAirportDestination(
      ref: ref,
      context: context,
      airport: a,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final byCountry = <String, List<BeneluxAirport>>{};
    for (final a in _filtered) {
      byCountry.putIfAbsent(a.countryCode, () => []).add(a);
    }
    final countryOrder = ['NL', 'BE', 'LU'];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.airportBookingScreenTitle,
              subtitle: l10n.airportBookingScreenSubtitle,
              icon: Icons.flight_takeoff_rounded,
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(80),
                ],
                style: typo.bodyLarge.copyWith(color: colors.text),
                decoration: InputDecoration(
                  hintText: l10n.airportBookingSearchHint,
                  hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: colors.textSoft),
                  filled: true,
                  fillColor: colors.card,
                  contentPadding:
                      const EdgeInsetsDirectional.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.accent, width: 2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.airportBookingNoResults,
                          textAlign: TextAlign.center,
                          style: typo.bodyMedium.copyWith(color: colors.textMid),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        0,
                        16,
                        24,
                      ),
                      children: [
                        for (final c in countryOrder) ...[
                          if ((byCountry[c] ?? []).isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Text(
                                _countryLabel(c, l10n),
                                style: typo.titleSmall.copyWith(
                                  color: colors.textSoft,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            for (final a in byCountry[c]!)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _AirportTile(
                                  airport: a,
                                  colors: colors,
                                  typo: typo,
                                  onTap: () => _selectAirport(a),
                                ),
                              ),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AirportTile extends StatelessWidget {
  final BeneluxAirport airport;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _AirportTile({
    required this.airport,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = airport;
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accentL,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flight_takeoff_rounded,
                  color: colors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            a.iata,
                            style: typo.labelLarge.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.name,
                            style: typo.bodyLarge.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.fullAddress,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSoft,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: colors.textSoft, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
