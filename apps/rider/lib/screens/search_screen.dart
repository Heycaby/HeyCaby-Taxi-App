import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_map/heycaby_map.dart';

import '../providers/booking_provider.dart';
import '../providers/local_recent_addresses_provider.dart';
import '../providers/location_provider.dart';
import '../providers/recent_destinations_provider.dart';
import '../services/booking_flow_navigation.dart';
import '../services/booking_pickup_from_location.dart';
import '../widgets/booking/search_address_form.dart';
import '../widgets/booking/search_quick_picks_section.dart';
import '../widgets/schedule_picker.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destinationFocus = FocusNode();

  SearchAddressFocus _activeFocus = SearchAddressFocus.destination;
  List<AddressResult> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;
  bool _isResolvingPickup = false;
  /// When true, [_suggestions] come from on-device recents only (no Mapbox call).
  bool _suggestionsFromLocal = false;

  @override
  void initState() {
    super.initState();
    _destinationFocus.requestFocus();

    ref.read(geocodingServiceProvider).startSession();

    final booking = ref.read(bookingProvider);
    if (booking.pickup != null) {
      _pickupController.text = booking.pickup!.displayName;
    } else if (booking.destination != null) {
      _activeFocus = SearchAddressFocus.pickup;
    }
    if (booking.destination != null) {
      _destinationController.text = booking.destination!.displayName;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapPickupAndIdentity());
    });

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        setState(() => _activeFocus = SearchAddressFocus.pickup);
        _onQueryChanged(_pickupController.text);
      }
    });
    _destinationFocus.addListener(() {
      if (_destinationFocus.hasFocus) {
        setState(() => _activeFocus = SearchAddressFocus.destination);
        _onQueryChanged(_destinationController.text);
      }
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocus.dispose();
    _destinationFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapPickupAndIdentity() async {
    await BookingFlowNavigation.prefillBookingFromIdentity(ref);
    if (!mounted) return;

    if (ref.read(bookingProvider).pickup != null) return;

    setState(() => _isResolvingPickup = true);
    final filled = await fillPickupFromCurrentLocation(ref);
    if (!mounted) return;

    if (filled) {
      final pickup = ref.read(bookingProvider).pickup;
      if (pickup != null) {
        _pickupController.text = pickup.displayName;
      }
    }
    setState(() => _isResolvingPickup = false);
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _suggestionsFromLocal = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    final trimmed = query.trim();

    final localMatches =
        ref.read(localRecentAddressesProvider.notifier).matchingQuery(trimmed);
    if (localMatches.isNotEmpty) {
      setState(() {
        _suggestions = localMatches;
        _suggestionsFromLocal = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _suggestionsFromLocal = false;
      _isLoading = true;
      _suggestions = [];
    });

    final geo = ref.read(geocodingServiceProvider);
    final loc = ref.read(locationProvider).valueOrNull;
    final lang = Localizations.localeOf(context).languageCode;
    final language = lang.length == 2 ? lang : 'en';

    try {
      final results = await geo.search(
        query: query,
        proximityLat: loc?.latitude,
        proximityLng: loc?.longitude,
        language: language,
      );

      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _applyResolvedAddress(AddressResult resolved) async {
    final l10n = AppLocalizations.of(context);
    if (resolved.lat == 0.0 && resolved.lng == 0.0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.searchAddressCouldNotResolve)),
        );
      }
      return;
    }

    if (_activeFocus == SearchAddressFocus.pickup) {
      ref.read(bookingProvider.notifier).setPickup(resolved);
      _pickupController.text = resolved.displayName;
    } else {
      ref.read(bookingProvider.notifier).setDestination(resolved);
      _destinationController.text = resolved.displayName;
      await ref.read(recentDestinationsProvider.notifier).recordDestination(
            fullAddress: resolved.fullAddress,
            lat: resolved.lat,
            lng: resolved.lng,
          );
    }

    await ref.read(localRecentAddressesProvider.notifier).record(resolved);

    if (!mounted) return;
    setState(() {
      _suggestions = [];
      _suggestionsFromLocal = false;
    });

    final booking = ref.read(bookingProvider);
    if (booking.pickup != null && booking.destination != null) {
      await BookingFlowNavigation.prefillBookingFromIdentity(ref);
      if (!mounted) return;
      setState(() {});
      await _maybeAdvanceAfterAddresses();
    } else if (_activeFocus == SearchAddressFocus.destination) {
      _pickupFocus.requestFocus();
    }
  }

  Future<void> _maybeAdvanceAfterAddresses() async {
    final booking = ref.read(bookingProvider);
    if (booking.pickup == null || booking.destination == null) return;
    if (!mounted) return;
    HapticService.lightTap();
    context.push(BookingFlowNavigation.routeAfterAddressesComplete(booking));
  }

  Future<void> _onSuggestionTap(AddressResult suggestion) async {
    final l10n = AppLocalizations.of(context);
    try {
      AddressResult resolved = suggestion;

      if (suggestion.lat == 0.0 && suggestion.mapboxId != null) {
        final geo = ref.read(geocodingServiceProvider);
        final full = await geo.retrieve(suggestion.mapboxId!);
        if (full != null) resolved = full;
      }

      await _applyResolvedAddress(resolved);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchAddressCouldNotResolve)),
      );
    }
  }

  void _onQuickPick(AddressResult r) {
    unawaited(_applyResolvedAddress(r));
  }

  void _swapLocations() {
    final booking = ref.read(bookingProvider);
    final notifier = ref.read(bookingProvider.notifier);
    if (booking.pickup != null && booking.destination != null) {
      final tmp = booking.pickup!;
      notifier.setPickup(booking.destination!);
      notifier.setDestination(tmp);
      _pickupController.text = booking.destination!.displayName;
      _destinationController.text = booking.pickup!.displayName;
    }
  }

  Future<void> _showDateTimePicker() async {
    final result = await showSchedulePicker(context);
    if (result != null && mounted) {
      ref.read(bookingProvider.notifier).setScheduledAt(result);
      ref.read(bookingProvider.notifier).setScheduled();
    }
  }

  Future<void> _onContinuePressed() async {
    FocusScope.of(context).unfocus();
    var booking = ref.read(bookingProvider);
    if (booking.pickup == null || booking.destination == null) return;
    await BookingFlowNavigation.prefillBookingFromIdentity(ref);
    if (!mounted) return;
    booking = ref.read(bookingProvider);
    context.push(BookingFlowNavigation.routeAfterAddressesComplete(booking));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);

    final canContinue =
        booking.pickup != null && booking.destination != null;

    return Scaffold(
      backgroundColor: colors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            SearchAddressHeader(
              colors: colors,
              typo: typo,
              l10n: l10n,
              mode: booking.mode,
              pickupController: _pickupController,
              destinationController: _destinationController,
              pickupFocus: _pickupFocus,
              destinationFocus: _destinationFocus,
              onPickupChanged: _onQueryChanged,
              onDestinationChanged: _onQueryChanged,
              onSwap: _swapLocations,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              onWhenTap: _showDateTimePicker,
              scheduledAt: booking.scheduledAt,
              pickupLoading: _isResolvingPickup,
            ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (_isLoading && _suggestions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: colors.accent,
                              strokeWidth: 2.5,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.loading,
                              style: typo.bodyMedium.copyWith(
                                color: colors.textMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_suggestions.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_suggestionsFromLocal)
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                20,
                                8,
                                20,
                                6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.smartphone_rounded,
                                    size: 18,
                                    color: colors.accent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.searchLocalMatchesHeader,
                                      style: typo.labelLarge.copyWith(
                                        color: colors.textMid,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          AddressSearchSuggestionsList(
                            suggestions: _suggestions,
                            isLoading: false,
                            colors: colors,
                            typo: typo,
                            l10n: l10n,
                            onTap: _onSuggestionTap,
                            shrinkWrap: true,
                          ),
                        ],
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: SearchQuickPicksSection(onPick: _onQuickPick),
                    ),
                ],
              ),
            ),
            if (canContinue)
              Container(
                padding: EdgeInsetsDirectional.fromSTEB(
                  HeyCabySpacing.screenEdge,
                  12,
                  HeyCabySpacing.screenEdge,
                  HeyCabySpacing.component +
                      MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: colors.bg,
                  boxShadow: [
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _onContinuePressed,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.searchAddressesContinue,
                      style: typo.labelLarge.copyWith(
                        color: colors.onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
