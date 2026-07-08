import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';

import '../providers/location_provider.dart';

Future<AddressResult?> showHomeAddressModal(
  BuildContext context,
  WidgetRef ref,
) async {
  return await showModalBottomSheet<AddressResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const _HomeAddressModal(),
  );
}

class _HomeAddressModal extends ConsumerStatefulWidget {
  const _HomeAddressModal();

  @override
  ConsumerState<_HomeAddressModal> createState() => _HomeAddressModalState();
}

class _HomeAddressModalState extends ConsumerState<_HomeAddressModal> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<AddressResult> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    ref.read(geocodingServiceProvider).startSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final geo = ref.read(geocodingServiceProvider);
    final loc = ref.read(locationProvider).valueOrNull;

    final results = await geo.search(
      query: query,
      proximityLat: loc?.latitude,
      proximityLng: loc?.longitude,
    );

    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _isLoading = false;
    });
  }

  Future<void> _onSuggestionTap(AddressResult suggestion) async {
    final l10n = AppLocalizations.of(context);
    AddressResult resolved = suggestion;

    if (suggestion.lat == 0.0 && suggestion.mapboxId != null) {
      final geo = ref.read(geocodingServiceProvider);
      final full = await geo.retrieve(suggestion.mapboxId!);
      if (full != null) resolved = full;
    }

    // Save to Supabase
    setState(() => _isSaving = true);
    
    try {
      final supabase = HeyCabySupabase.client;
      final identity = ref.read(riderIdentityProvider).valueOrNull;
      
      if (identity?.identityId != null) {
        await supabase.from('rider_identities').update({
          'home_address': resolved.fullAddress,
          'home_lat': resolved.lat,
          'home_lng': resolved.lng,
        }).eq('id', identity!.identityId!);
      }

      if (mounted) {
        Navigator.of(context).pop(resolved);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToSaveHome),
            backgroundColor: ref.watch(colorsProvider).error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(24),
          topEnd: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsetsDirectional.only(bottom: keyboardHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.addYourHome,
                              style: typo.headingLarge.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, color: colors.textMid),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.homeAddressDesc,
                        style: typo.bodyMedium.copyWith(color: colors.textMid),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsetsDirectional.all(16),
                        decoration: BoxDecoration(
                          color: colors.bgAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _focusNode.hasFocus ? colors.accent : colors.border,
                            width: _focusNode.hasFocus ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.home_outlined,
                              color: colors.textMid,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                maxLength: 200,
                                focusNode: _focusNode,
                                onChanged: _onQueryChanged,
                                decoration: InputDecoration(
                                  hintText: l10n.enterHomeAddress,
                                  hintStyle: typo.bodyMedium.copyWith(
                                    color: colors.textSoft,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                style: typo.bodyMedium.copyWith(color: colors.text),
                              ),
                            ),
                            if (_controller.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  setState(() => _suggestions = []);
                                },
                                child: Icon(Icons.clear, color: colors.textMid, size: 18),
                              ),
                          ],
                        ),
                      ),
                      if (_isSaving) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                color: colors.accent,
                                strokeWidth: 2,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.saving,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else if (_isLoading) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: CircularProgressIndicator(
                            color: colors.accent,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ..._suggestions.take(5).map((suggestion) {
                          return InkWell(
                            onTap: () => _onSuggestionTap(suggestion),
                            child: Container(
                              padding: const EdgeInsetsDirectional.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    color: colors.textMid,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          suggestion.displayName,
                                          style: typo.bodyMedium.copyWith(
                                            color: colors.text,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (suggestion.fullAddress.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            suggestion.fullAddress,
                                            style: typo.bodySmall.copyWith(
                                              color: colors.textSoft,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ] else ...[
                        const SizedBox(height: 24),
                      ],
                    ],
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
