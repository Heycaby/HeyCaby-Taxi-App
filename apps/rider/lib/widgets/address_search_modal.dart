import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';

import '../providers/location_provider.dart';

enum AddressType { pickup, destination }

Future<AddressResult?> showAddressSearchModal(
  BuildContext context,
  WidgetRef ref,
  AddressType type,
) async {
  return await showModalBottomSheet<AddressResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddressSearchModal(type: type),
  );
}

class _AddressSearchModal extends ConsumerStatefulWidget {
  final AddressType type;
  const _AddressSearchModal({required this.type});

  @override
  ConsumerState<_AddressSearchModal> createState() => _AddressSearchModalState();
}

class _AddressSearchModalState extends ConsumerState<_AddressSearchModal> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<AddressResult> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

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
    AddressResult resolved = suggestion;

    if (suggestion.lat == 0.0 && suggestion.mapboxId != null) {
      final geo = ref.read(geocodingServiceProvider);
      final full = await geo.retrieve(suggestion.mapboxId!);
      if (full != null) resolved = full;
    }

    if (mounted) {
      Navigator.of(context).pop(resolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    return Container(
      height: mediaQuery.size.height * 0.85,
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
          child: Column(
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Icon(
                      widget.type == AddressType.pickup
                          ? Icons.circle
                          : Icons.location_on,
                      color: widget.type == AddressType.pickup
                          ? colors.accent
                          : colors.error,
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
                          hintText: widget.type == AddressType.pickup
                              ? AppLocalizations.of(context).searchEnterPickupHint
                              : AppLocalizations.of(context).searchEnterDestinationHint,
                          hintStyle: typo.bodyMedium.copyWith(
                            color: colors.textSoft,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: typo.bodyLarge.copyWith(color: colors.text),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          setState(() => _suggestions = []);
                        },
                        child: Icon(Icons.clear, color: colors.textMid, size: 20),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colors.accent,
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            leading: Icon(
                              Icons.location_on_outlined,
                              color: colors.textMid,
                              size: 20,
                            ),
                            title: Text(
                              suggestion.displayName,
                              style: typo.bodyMedium.copyWith(
                                color: colors.text,
                              ),
                            ),
                            subtitle: suggestion.fullAddress.isNotEmpty
                                ? Text(
                                    suggestion.fullAddress,
                                    style: typo.bodySmall.copyWith(
                                      color: colors.textSoft,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => _onSuggestionTap(suggestion),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
