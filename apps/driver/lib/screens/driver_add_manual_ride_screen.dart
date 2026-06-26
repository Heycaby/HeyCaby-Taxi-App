import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_location_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_manual_ride_entry_body.dart';

class DriverAddManualRideScreen extends ConsumerStatefulWidget {
  const DriverAddManualRideScreen({super.key});

  @override
  ConsumerState<DriverAddManualRideScreen> createState() =>
      _DriverAddManualRideScreenState();
}

class _DriverAddManualRideScreenState
    extends ConsumerState<DriverAddManualRideScreen> {
  final _pickupCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();
  final _passengerCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _dropoffFocus = FocusNode();
  String _paymentMethod = 'cash';
  bool _saving = false;
  bool _loadingDropoff = false;
  List<AddressResult> _dropoffSuggestions = const [];
  Timer? _dropoffDebounce;
  static const _recentAddressesKey = 'driver_manual_ride_recent_addresses_v1';

  @override
  void initState() {
    super.initState();
    unawaited(_prefillPickupFromCurrentLocation());
    ref.read(geocodingServiceProvider).startSession();
  }

  @override
  void dispose() {
    _dropoffDebounce?.cancel();
    _dropoffFocus.dispose();
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _fareCtrl.dispose();
    _passengerCtrl.dispose();
    super.dispose();
  }

  int? _fareToCents(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<List<AddressResult>> _loadRecentAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentAddressesKey) ?? const [];
    return raw
        .map((e) {
          try {
            final m = jsonDecode(e);
            if (m is Map<String, dynamic>) {
              return AddressResult(
                displayName: (m['display_name'] as String?) ?? '',
                fullAddress: (m['full_address'] as String?) ?? '',
                lat: (m['lat'] as num?)?.toDouble() ?? 0,
                lng: (m['lng'] as num?)?.toDouble() ?? 0,
                mapboxId: m['mapbox_id'] as String?,
                city: m['city'] as String?,
              );
            }
          } catch (_) {}
          return null;
        })
        .whereType<AddressResult>()
        .toList();
  }

  Future<void> _saveRecentAddress(AddressResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadRecentAddresses();
    final merged = <AddressResult>[
      result,
      ...existing.where((e) =>
          e.fullAddress.toLowerCase() != result.fullAddress.toLowerCase()),
    ];
    final limited = merged.take(8).toList();
    final encoded = limited
        .map((e) => jsonEncode({
              'display_name': e.displayName,
              'full_address': e.fullAddress,
              'lat': e.lat,
              'lng': e.lng,
              'mapbox_id': e.mapboxId,
              'city': e.city,
            }))
        .toList();
    await prefs.setStringList(_recentAddressesKey, encoded);
  }

  Future<void> _prefillPickupFromCurrentLocation() async {
    final pos = ref.read(driverLocationProvider).valueOrNull;
    if (pos == null) return;
    final reverse = await ref.read(geocodingServiceProvider).reverseGeocode(
          lat: pos.latitude,
          lng: pos.longitude,
        );
    if (!mounted) return;
    if (reverse == null) return;
    if (_pickupCtrl.text.trim().isNotEmpty) return;
    _pickupCtrl.text = reverse.fullAddress.isNotEmpty
        ? reverse.fullAddress
        : reverse.displayName;
  }

  void _onDropoffChanged(String query) {
    _dropoffDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _dropoffSuggestions = const []);
      return;
    }
    _dropoffDebounce = Timer(
      const Duration(milliseconds: 280),
      () => _searchDropoffSuggestions(query),
    );
  }

  Future<void> _searchDropoffSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _loadingDropoff = true);
    final q = query.trim().toLowerCase();
    final recent = await _loadRecentAddresses();
    final recentHits = recent
        .where((e) =>
            e.fullAddress.toLowerCase().contains(q) ||
            e.displayName.toLowerCase().contains(q))
        .toList();

    final pos = ref.read(driverLocationProvider).valueOrNull;
    final apiHits = await ref.read(geocodingServiceProvider).search(
          query: query,
          proximityLat: pos?.latitude,
          proximityLng: pos?.longitude,
        );
    if (!mounted) return;
    final merged = <AddressResult>[
      ...recentHits,
      ...apiHits.where((api) => recentHits.every((r) =>
          r.fullAddress.toLowerCase() != api.fullAddress.toLowerCase())),
    ];
    setState(() {
      _dropoffSuggestions = merged.take(6).toList();
      _loadingDropoff = false;
    });
  }

  Future<void> _selectDropoffSuggestion(AddressResult suggestion) async {
    AddressResult selected = suggestion;
    if (selected.lat == 0.0 && (selected.mapboxId?.isNotEmpty ?? false)) {
      final resolved =
          await ref.read(geocodingServiceProvider).retrieve(selected.mapboxId!);
      if (resolved != null) selected = resolved;
    }
    final text = selected.fullAddress.isNotEmpty
        ? selected.fullAddress
        : selected.displayName;
    _dropoffCtrl.text = text;
    await _saveRecentAddress(selected);
    if (!mounted) return;
    setState(() => _dropoffSuggestions = const []);
    _dropoffFocus.unfocus();
  }

  Future<void> _saveRide() async {
    if (!_formKey.currentState!.validate()) return;
    final fareCents = _fareToCents(_fareCtrl.text);
    if (fareCents == null) return;

    final pos = ref.read(driverLocationProvider).valueOrNull;
    setState(() => _saving = true);
    try {
      final result = await ref.read(driverApiProvider).createManualRide(
            pickupAddress: _pickupCtrl.text.trim().isEmpty
                ? null
                : _pickupCtrl.text.trim(),
            dropoffAddress: _dropoffCtrl.text.trim(),
            fareCents: fareCents,
            paymentMethod: _paymentMethod,
            passengerName: _passengerCtrl.text.trim().isEmpty
                ? null
                : _passengerCtrl.text.trim(),
            pickupLat: pos?.latitude,
            pickupLng: pos?.longitude,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      if (!result.success) {
        final msg = result.message.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.isEmpty
                  ? DriverStrings.manualRideSaveFailed
                  : '${DriverStrings.manualRideSaveFailed} ($msg)',
            ),
          ),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text(DriverStrings.manualRideSuccessTitle),
          content: Text(DriverStrings.manualRideSuccessBody(_fareCtrl.text.trim())),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(DriverStrings.done),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/driver');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final serverMsg = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['error']?.toString() ??
              e.response!.data['message']?.toString())
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverMsg == null || serverMsg.isEmpty
                ? DriverStrings.manualRideSaveFailed
                : '${DriverStrings.manualRideSaveFailed} ($serverMsg)',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(DriverStrings.manualRideSaveFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final farePreview = _fareToCents(_fareCtrl.text);
    final farePreviewText = farePreview == null
        ? 'Set fare to preview trip summary'
        : 'You keep 100%: EUR ${(farePreview / 100).toStringAsFixed(2)} • ${_paymentMethod.toUpperCase()}';

    return DriverManualRideEntryBody(
      colors: colors,
      typography: typography,
      formKey: _formKey,
      pickupController: _pickupCtrl,
      dropoffController: _dropoffCtrl,
      fareController: _fareCtrl,
      passengerController: _passengerCtrl,
      paymentMethod: _paymentMethod,
      saving: _saving,
      loadingDropoffSuggestions: _loadingDropoff,
      dropoffSuggestions: _dropoffSuggestions
          .map(
            (item) => DriverManualRideSuggestion(
              title: item.displayName.isNotEmpty
                  ? item.displayName
                  : item.fullAddress,
              subtitle: item.fullAddress,
            ),
          )
          .toList(),
      farePreviewText: farePreviewText,
      onDropoffChanged: _onDropoffChanged,
      onSuggestionSelected: (index) =>
          _selectDropoffSuggestion(_dropoffSuggestions[index]),
      onPaymentMethodChanged: (method) =>
          setState(() => _paymentMethod = method),
      onFareChanged: () => setState(() {}),
      onSave: _saveRide,
      onCancel: () => context.go('/driver'),
      onClose: () => context.go('/driver'),
      dropoffFocusNode: _dropoffFocus,
      validateDropoff: (v) => (v == null || v.trim().isEmpty)
          ? DriverStrings.manualRideDropoffRequired
          : null,
      validateFare: (v) =>
          _fareToCents(v ?? '') == null ? DriverStrings.manualRideFareRequired : null,
    );
  }
}
