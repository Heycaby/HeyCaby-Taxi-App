import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/location_provider.dart';
import '../providers/saved_addresses_provider.dart';

/// Bottom sheet to add or edit a saved place (home, work, etc.). Multiple rows with the
/// same [initialType] (e.g. several homes) are allowed once the DB unique on
/// `(rider_identity_id, type)` is removed.
class AddAddressSheet extends ConsumerStatefulWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String initialType;
  final SavedAddress? editAddress;

  const AddAddressSheet({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    this.initialType = 'home',
    this.editAddress,
  });

  bool get isEditing => editAddress != null;

  @override
  ConsumerState<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<AddAddressSheet> {
  final _labelController = TextEditingController();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  late String _selectedType;
  List<AddressResult> _suggestions = [];
  AddressResult? _selectedAddress;
  Timer? _debounce;
  bool _isSearching = false;
  bool _isSaving = false;
  int _searchRequestId = 0;

  static const _types = ['home', 'work', 'gym', 'custom'];

  @override
  void initState() {
    super.initState();
    final editing = widget.editAddress;
    if (editing != null) {
      _selectedType = _types.contains(editing.type) ? editing.type : 'custom';
      _labelController.text = editing.label;
      _searchController.text = editing.fullAddress;
      _selectedAddress = AddressResult(
        displayName: editing.label,
        fullAddress: editing.fullAddress,
        lat: editing.latitude,
        lng: editing.longitude,
      );
      return;
    }
    _selectedType = widget.initialType;
    if (_types.contains(_selectedType)) {
      _labelController.text = _labelForType(_selectedType);
    } else {
      _selectedType = 'home';
      _labelController.text = _labelForType('home');
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  bool _labelIsPreset() {
    final t = _labelController.text.trim();
    if (t.isEmpty) return true;
    for (final type in _types) {
      if (t == _labelForType(type)) return true;
    }
    return false;
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() => _selectedAddress = null);
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }
    final requestId = ++_searchRequestId;
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(query, requestId),
    );
  }

  Future<void> _search(String query, int requestId) async {
    if (!mounted || requestId != _searchRequestId) return;
    setState(() => _isSearching = true);
    final geo = ref.read(geocodingServiceProvider);
    final loc = ref.read(locationProvider).valueOrNull;
    final results = await geo.search(
      query: query,
      proximityLat: loc?.latitude,
      proximityLng: loc?.longitude,
    );
    if (!mounted || requestId != _searchRequestId) return;
    setState(() {
      _suggestions = results;
      _isSearching = false;
    });
  }

  Future<void> _onSuggestionTap(AddressResult suggestion) async {
    _debounce?.cancel();
    _searchRequestId++;
    FocusScope.of(context).unfocus();

    setState(() {
      _suggestions = [];
      _isSearching = true;
    });

    AddressResult resolved = suggestion;
    if (suggestion.lat == 0.0 && suggestion.mapboxId != null) {
      final geo = ref.read(geocodingServiceProvider);
      final full = await geo.retrieve(suggestion.mapboxId!);
      if (full != null) resolved = full;
    }
    if (!mounted) return;
    setState(() {
      _selectedAddress = resolved;
      _searchController.text = resolved.fullAddress.isNotEmpty
          ? resolved.fullAddress
          : resolved.displayName;
      _suggestions = [];
      _isSearching = false;
    });
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    final addr = _selectedAddress;
    if (label.isEmpty || addr == null) return;

    setState(() => _isSaving = true);
    final notifier = ref.read(savedAddressesProvider.notifier);
    if (widget.isEditing) {
      final outcome = await notifier.updateAddress(
        addressId: widget.editAddress!.id,
        type: _selectedType,
        label: label,
        fullAddress: addr.fullAddress,
        latitude: addr.lat,
        longitude: addr.lng,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      switch (outcome) {
        case SavedAddressUpdateOutcome.success:
          Navigator.of(context).pop(true);
        case SavedAddressUpdateOutcome.notFound:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.l10n.editSavedAddressNotFound)),
          );
        case SavedAddressUpdateOutcome.sessionRequired:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.l10n.savedAddressesSessionRequired)),
          );
        case SavedAddressUpdateOutcome.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.l10n.connectionProblem)),
          );
      }
      return;
    }

    final outcome = await notifier.add(
          type: _selectedType,
          label: label,
          fullAddress: addr.fullAddress,
          latitude: addr.lat,
          longitude: addr.lng,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);
    switch (outcome) {
      case SavedAddressAddOutcome.success:
        Navigator.of(context).pop(true);
      case SavedAddressAddOutcome.limitReached:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.savedAddressesLimitReached)),
        );
      case SavedAddressAddOutcome.sessionRequired:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.savedAddressesSessionRequired)),
        );
      case SavedAddressAddOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.connectionProblem)),
        );
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'home':
        return widget.l10n.savedAddressLabelHome;
      case 'work':
        return widget.l10n.savedAddressLabelWork;
      case 'gym':
        return widget.l10n.savedAddressLabelGym;
      default:
        return widget.l10n.savedAddressLabelCustom;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'gym':
        return Icons.fitness_center_rounded;
      case 'home':
        return Icons.home_rounded;
      default:
        return Icons.star_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    final c = widget.colors;
    final typo = widget.typo;
    final l10n = widget.l10n;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: c.text.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.accent.withValues(alpha: 0.14),
                    c.surface,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: keyboardH),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isEditing
                                    ? l10n.editSavedAddressSheetTitle
                                    : l10n.addSavedAddressSheetTitle,
                                style: typo.headingMedium.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.isEditing
                                    ? l10n.editSavedAddressSheetBody
                                    : l10n.noSavedAddressesEmptyBody,
                                style: typo.bodySmall.copyWith(
                                  color: c.textSoft,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded, color: c.textMid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.savedAddressCategoryLabel,
                      style: typo.labelMedium.copyWith(
                        color: c.textMid,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _types.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final type = _types[i];
                          final selected = _selectedType == type;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedType = type;
                                  if (_labelIsPreset()) {
                                    _labelController.text = _labelForType(type);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected ? c.accent : c.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected ? c.accent : c.border,
                                    width: selected ? 0 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: c.accent
                                                .withValues(alpha: 0.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _iconForType(type),
                                      color: selected ? c.onAccent : c.textMid,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _labelForType(type),
                                      style: typo.labelLarge.copyWith(
                                        color: selected ? c.onAccent : c.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.savedAddressNameLabel,
                      style: typo.labelMedium.copyWith(
                        color: c.textMid,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _labelController,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(40),
                      ],
                      style: typo.bodyLarge.copyWith(color: c.text),
                      decoration: InputDecoration(
                        hintText: l10n.savedAddressNameHint,
                        hintStyle: typo.bodyMedium.copyWith(color: c.textSoft),
                        filled: true,
                        fillColor: c.bgAlt,
                        contentPadding: const EdgeInsetsDirectional.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: c.accent, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.savedAddressSearchLabel,
                      style: typo.labelMedium.copyWith(
                        color: c.textMid,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      style: typo.bodyLarge.copyWith(color: c.text),
                      decoration: InputDecoration(
                        hintText: l10n.savedAddressSearchHint,
                        hintStyle: typo.bodyMedium.copyWith(color: c.textSoft),
                        filled: true,
                        fillColor: c.bgAlt,
                        prefixIcon:
                            Icon(Icons.search_rounded, color: c.textSoft),
                        contentPadding: const EdgeInsetsDirectional.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: c.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: c.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: c.accent, width: 2),
                        ),
                      ),
                    ),
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_suggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.border),
                            boxShadow: [
                              BoxShadow(
                                color: c.text.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: _suggestions.take(6).map((s) {
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    unawaited(_onSuggestionTap(s));
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding:
                                        const EdgeInsetsDirectional.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: c.accentL,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.place_outlined,
                                            color: c.accent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.displayName,
                                                style: typo.bodyMedium.copyWith(
                                                  color: c.text,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (s.fullAddress.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  s.fullAddress,
                                                  style:
                                                      typo.bodySmall.copyWith(
                                                    color: c.textSoft,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    if (_selectedAddress != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsetsDirectional.all(14),
                        decoration: BoxDecoration(
                          color: c.accentL,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: c.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: c.accent, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedAddress!.fullAddress,
                                style: typo.bodySmall.copyWith(
                                  color: c.textMid,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: (_selectedAddress != null &&
                                _labelController.text.trim().isNotEmpty &&
                                !_isSaving)
                            ? _save
                            : null,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: c.onAccent,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.isEditing
                                    ? l10n.saveChanges
                                    : l10n.saveButton,
                                style: typo.labelLarge.copyWith(
                                  color: c.onAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showAddSavedAddressSheet(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
  required AppLocalizations l10n,
  String initialType = 'home',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddAddressSheet(
      colors: colors,
      typo: typo,
      l10n: l10n,
      initialType: initialType,
    ),
  );
}

Future<bool?> showEditSavedAddressSheet(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
  required AppLocalizations l10n,
  required SavedAddress address,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddAddressSheet(
      colors: colors,
      typo: typo,
      l10n: l10n,
      editAddress: address,
    ),
  );
}
