import 'dart:async' show unawaited;
import 'dart:typed_data' show Uint8List;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_runtime_providers.dart';
import '../services/driver_data_service.dart'
    show
        DriverComplianceSnapshot,
        DriverProfile,
        ProfilePhotoConnectionException,
        ProfilePhotoLimitException,
        VehiclePhotoLimitException;
import '../theme/app_icons.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../models/driver_runtime_models.dart';
import '../utils/driver_readiness_routes.dart';
import '../widgets/driver_identity_body.dart';
import '../widgets/driver_hub_saved_by_riders_section.dart';
import '../widgets/driver_rating_sheet.dart';
import '../utils/validation_utils.dart';

/// Full profile screen — name, photo (one-time), rating.
class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({
    super.key,
    this.initialAction,
    this.returnAfterAction = false,
  });

  final String? initialAction;
  final bool returnAfterAction;

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _VehiclePhotoTip extends StatelessWidget {
  const _VehiclePhotoTip({
    required this.colors,
    required this.typography,
    required this.text,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 17,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: typography.bodyMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  bool _busy = false;
  bool _initialActionStarted = false;

  /// Bumps when a new photo is saved so [CachedNetworkImage] fetches a new file (URL path is unchanged).
  /// Notifier so the profile sheet avatar updates without stale closure values.
  final ValueNotifier<int> _profilePhotoCacheBust = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runInitialAction());
    });
  }

  Future<void> _runInitialAction() async {
    if (_initialActionStarted || !mounted) return;
    final action = widget.initialAction?.trim();
    if (action == null || action.isEmpty) return;
    _initialActionStarted = true;

    final profile = await ref.read(driverProfileProvider.future);
    if (!mounted) return;
    if (action == 'profile_photo') {
      await _pickAndConfirmProfilePhoto(profile);
      return;
    }
    if (action == 'vehicle_photo') {
      final compliance = await ref.read(driverComplianceProvider.future);
      if (!mounted) return;
      await _pickAndConfirmVehiclePhoto(profile, compliance);
    }
  }

  void _finishInitialAction(String action) {
    if (!widget.returnAfterAction ||
        widget.initialAction != action ||
        !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _profilePhotoCacheBust.dispose();
    super.dispose();
  }

  /// After DB writes, invalidate + await refetch so Me tab shows new name/photo immediately.
  void _refreshDriverProfileAfterMutation() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.invalidate(driverProfileProvider);
      try {
        await ref.read(driverProfileProvider.future);
      } catch (_) {
        // Surface nothing — SnackBar already confirmed save; pull-to-refresh could retry.
      }
      if (mounted) setState(() {});
    });
  }

  /// Required before any profile write — creates `drivers` row if missing.
  Future<String?> _ensureDriverIdOrExplain() async {
    var id = await ref.read(driverIdProvider.future);
    if (id != null) return id;
    setState(() => _busy = true);
    final created = await ref.read(driverDataServiceProvider).ensureDriverId();
    if (!mounted) return null;
    setState(() => _busy = false);
    if (created != null) {
      // Never invalidate while an overlay (e.g. profile sheet) may still be building —
      // can assert _dependents.isEmpty / wrong build scope.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(driverIdProvider);
        ref.invalidate(driverProfileProvider);
      });
      return created;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.profileDriverSetupFailed)),
      );
    }
    return null;
  }

  String _initialsFromNameOrEmail(String? fullName, String? email) {
    final n = fullName?.trim() ?? '';
    if (n.isNotEmpty) {
      final parts = n.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final a = parts[0].isNotEmpty ? parts[0][0] : '';
        final b = parts[1].isNotEmpty ? parts[1][0] : '';
        return ('$a$b').toUpperCase();
      }
      return n[0].toUpperCase();
    }
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  int _profilePhotoChangesRemaining(DriverProfile? profile) {
    final hasPhoto = (profile?.profilePhotoUrl ?? '').trim().isNotEmpty;
    final explicitCount = profile?.profilePhotoChangeCount ?? 0;
    // Backward compatible: old accounts may have a photo but no explicit counter yet.
    final used = explicitCount > 0 ? explicitCount : (hasPhoto ? 1 : 0);
    final remaining = 2 - used;
    return remaining < 0 ? 0 : remaining;
  }

  bool _checklistComplete(
    DriverReadinessState? readiness,
    String key,
    bool fallback,
  ) {
    if (readiness == null) return fallback;
    for (final item in readiness.checklist) {
      if (item.key == key) return item.complete;
    }
    return fallback;
  }

  List<DriverIdentityRequirement> _completionItems({
    required DriverProfile? profile,
    required DriverComplianceSnapshot? compliance,
    required DriverRuntimeSnapshot? runtime,
  }) {
    final readiness = runtime?.readiness;
    final hasProfilePhoto = (profile?.profilePhotoUrl ?? '').trim().isNotEmpty;
    final hasVehiclePhoto =
        profile?.vehiclePhotoUrls.any((url) => url.trim().isNotEmpty) ?? false;
    final plateVerified = runtime?.plateVerified ??
        (compliance?.vehicleVerificationStatus == 'rdw_verified_taxi');
    final termsAccepted =
        runtime?.termsAccepted ?? compliance?.termsAcceptedAt != null;

    return [
      DriverIdentityRequirement(
        key: 'vehicle_plate',
        label: DriverStrings.profileRequirementPlate,
        complete: _checklistComplete(readiness, 'vehicle_plate', plateVerified),
      ),
      DriverIdentityRequirement(
        key: 'terms_of_service',
        label: DriverStrings.profileRequirementTerms,
        complete:
            _checklistComplete(readiness, 'terms_of_service', termsAccepted),
      ),
      DriverIdentityRequirement(
        key: 'profile_photo',
        label: DriverStrings.profileRequirementDriverPhoto,
        complete:
            _checklistComplete(readiness, 'profile_photo', hasProfilePhoto),
      ),
      DriverIdentityRequirement(
        key: 'vehicle_photos',
        label: DriverStrings.profileRequirementVehiclePhoto,
        complete:
            _checklistComplete(readiness, 'vehicle_photos', hasVehiclePhoto),
      ),
    ];
  }

  String _vehicleDescriptor(
    DriverProfile? profile,
    DriverComplianceSnapshot? compliance,
  ) {
    final parts = <String>[];
    void add(String? value) {
      final v = value?.trim();
      if (v == null || v.isEmpty || v == '—') return;
      if (!parts.any((p) => p.toLowerCase() == v.toLowerCase())) {
        parts.add(v);
      }
    }

    add(profile?.vehicleColour);
    add(profile?.vehicleMake ?? compliance?.rdwMerk);
    add(profile?.vehicleModel ?? compliance?.rdwHandelsbenaming);
    if (profile?.vehicleYear != null) add('${profile!.vehicleYear}');
    return parts.join(' · ');
  }

  void _openRequirement(String key) {
    switch (key) {
      case 'profile_photo':
        unawaited(
          _pickAndConfirmProfilePhoto(
            ref.read(driverProfileProvider).valueOrNull,
          ),
        );
        return;
      case 'vehicle_photos':
        unawaited(
          _pickAndConfirmVehiclePhoto(
            ref.read(driverProfileProvider).valueOrNull,
            ref.read(driverComplianceProvider).valueOrNull,
          ),
        );
        return;
      case 'vehicle_plate':
        context.push('/driver/vehicle');
        return;
      case 'terms_of_service':
        context.push('/driver/terms');
        return;
      case 'indemnification_quiz':
        context.push('/driver/indemnification');
        return;
      default:
        final route = flutterRouteForReadinessItem(
          DriverReadinessItem(key: key, label: '', complete: false),
        );
        if (route != null) context.push(route);
    }
  }

  Future<void> _pickAndConfirmProfilePhoto(DriverProfile? profile) async {
    final remaining = _profilePhotoChangesRemaining(profile);
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.profilePhotoLockedMessage)),
      );
      return;
    }

    final id = await _ensureDriverIdOrExplain();
    if (id == null || !mounted) return;

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1536,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;

    final lower = x.path.toLowerCase();
    var ext = 'jpg';
    var contentType = 'image/jpeg';
    if (lower.endsWith('.png')) {
      ext = 'png';
      contentType = 'image/png';
    }
    final bytes = await x.readAsBytes();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(DriverStrings.profilePhotoConfirmTitle),
          content: SingleChildScrollView(
            child: Text(DriverStrings.profilePhotoConfirmBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(DriverStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(DriverStrings.profilePhotoConfirmYes),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    String? url;
    try {
      url = await ref
          .read(driverDataServiceProvider)
          .uploadDriverProfilePhotoOnce(
            driverId: id,
            bytes: bytes,
            contentType: contentType,
            fileExtension: ext,
          );
    } on ProfilePhotoLimitException {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.profilePhotoLockedMessage)),
      );
      return;
    } on ProfilePhotoConnectionException {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DriverStrings.profilePhotoUploadConnectionError),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (url != null) {
      // Same storage path → same public URL; drop disk cache + bust query so UI shows new bytes.
      try {
        await DefaultCacheManager().removeFile(url);
      } catch (_) {}
      if (!mounted) return;
      _profilePhotoCacheBust.value++;
      _refreshDriverProfileAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.profilePhotoSaved)),
      );
      _finishInitialAction('profile_photo');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.profilePhotoUploadFailed)),
      );
    }
  }

  Future<void> _saveNameFromSheet(String name, String driverId) async {
    final t = name.trim();
    if (t.isEmpty) return;
    setState(() => _busy = true);
    final okSave = await ref
        .read(driverDataServiceProvider)
        .updateDriverFullName(driverId, t);
    if (!mounted) return;
    setState(() => _busy = false);
    if (okSave) {
      _refreshDriverProfileAfterMutation();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.profileNameSaved)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.profileNameSaveFailed)),
      );
    }
  }

  Future<ImageSource?> _chooseVehiclePhotoSource({String? currentPhotoUrl}) {
    final colors = DriverColors.fromTheme(ref.read(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.read(typographyProvider));

    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: colors.card,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DriverStrings.vehiclePhotoGuidanceTitle,
                  style: typography.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DriverStrings.vehiclePhotoGuidanceBody,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                if (currentPhotoUrl?.startsWith('http') == true) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            currentPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: colors.surface,
                              child: Icon(
                                Icons.local_taxi_rounded,
                                color: colors.primary,
                                size: 48,
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.card.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: colors.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DriverStrings.vehiclePhotoGoodExample,
                                    style: typography.labelSmall.copyWith(
                                      color: colors.text,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _VehiclePhotoTip(
                  colors: colors,
                  typography: typography,
                  text: DriverStrings.vehiclePhotoTipWholeCar,
                ),
                const SizedBox(height: 10),
                _VehiclePhotoTip(
                  colors: colors,
                  typography: typography,
                  text: DriverStrings.vehiclePhotoTipPlate,
                ),
                const SizedBox(height: 10),
                _VehiclePhotoTip(
                  colors: colors,
                  typography: typography,
                  text: DriverStrings.vehiclePhotoTipLighting,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(DriverStrings.vehiclePhotoTakePhoto),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(DriverStrings.vehiclePhotoChooseLibrary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmVehiclePhotoPreview({
    required Uint8List bytes,
    required String vehicleLabel,
    required String plate,
  }) async {
    final colors = DriverColors.fromTheme(ref.read(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.read(typographyProvider));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ColoredBox(
              color: colors.card,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DriverStrings.vehiclePhotoPreviewTitle,
                        style: typography.titleLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plate.isEmpty ? DriverStrings.vehicle : plate,
                              style: typography.titleMedium.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                                letterSpacing: plate.isEmpty ? 0 : 1.0,
                              ),
                            ),
                            if (vehicleLabel.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                vehicleLabel,
                                style: typography.bodyMedium.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              DriverStrings.vehiclePhotoRiderPreviewHint,
                              style: typography.bodySmall.copyWith(
                                color: colors.textMuted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(DriverStrings.vehiclePhotoUseThis),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(DriverStrings.vehiclePhotoRetake),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return result == true;
  }

  Future<void> _pickAndConfirmVehiclePhoto(
    DriverProfile? profile,
    DriverComplianceSnapshot? compliance,
  ) async {
    final id = await _ensureDriverIdOrExplain();
    if (id == null || !mounted) return;

    final currentPhotoUrl = profile?.vehiclePhotoUrls
        .where((url) => url.trim().startsWith('http'))
        .firstOrNull;
    final source = await _chooseVehiclePhotoSource(
      currentPhotoUrl: currentPhotoUrl,
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      maxWidth: 1800,
      imageQuality: 88,
    );
    if (x == null || !mounted) return;

    final lower = x.path.toLowerCase();
    var ext = 'jpg';
    var contentType = 'image/jpeg';
    if (lower.endsWith('.png')) {
      ext = 'png';
      contentType = 'image/png';
    }

    final bytes = await x.readAsBytes();
    if (!mounted) return;

    final plate =
        (compliance?.vehiclePlate ?? profile?.vehiclePlate ?? '').trim();
    final vehicleLabel = _vehicleDescriptor(profile, compliance);
    final approved = await _confirmVehiclePhotoPreview(
      bytes: bytes,
      vehicleLabel: vehicleLabel,
      plate: plate,
    );
    if (!approved || !mounted) return;

    setState(() => _busy = true);
    List<String>? updated;
    try {
      updated =
          await ref.read(driverDataServiceProvider).uploadDriverVehiclePhoto(
                driverId: id,
                bytes: bytes,
                contentType: contentType,
                fileExtension: ext,
              );
    } on VehiclePhotoLimitException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.vehiclePhotoLimitReached)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    if (updated != null && updated.isNotEmpty) {
      ref.invalidate(driverProfileProvider);
      ref.invalidate(driverRuntimeSnapshotProvider);
      try {
        await ref.read(driverProfileProvider.future);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.vehiclePhotoSaved)),
      );
      _finishInitialAction('vehicle_photo');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.vehiclePhotoUploadFailed)),
      );
    }
  }

  Future<void> _openProfileEditSheet(
    DriverProfile? profile,
    String? nameFromDb,
    String? email,
    ValueNotifier<int> profilePhotoCacheBust,
  ) async {
    final id = await _ensureDriverIdOrExplain();
    if (!mounted || id == null) return;

    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final nameController =
        TextEditingController(text: nameFromDb?.trim() ?? '');

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(ctx).bottom),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: colors.text.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: colors.border.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        Text(
                          DriverStrings.profileEditSheetTitle,
                          style: typo.titleMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DriverStrings.profileEditSheetSubtitle,
                          style: typo.bodySmall
                              .copyWith(color: colors.textSoft, height: 1.35),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              await _pickAndConfirmProfilePhoto(profile);
                              if (mounted) setModalState(() {});
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                ValueListenableBuilder<int>(
                                  valueListenable: profilePhotoCacheBust,
                                  builder: (context, bust, _) {
                                    return _DriverAvatar(
                                      photoUrl: ref
                                              .read(driverProfileProvider)
                                              .valueOrNull
                                              ?.profilePhotoUrl ??
                                          profile?.profilePhotoUrl,
                                      photoCacheBust: bust,
                                      initials: _initialsFromNameOrEmail(
                                          nameFromDb, email),
                                      colors: colors,
                                      typo: typo,
                                      size: 120,
                                    );
                                  },
                                ),
                                if (_profilePhotoChangesRemaining(
                                      ref
                                              .read(driverProfileProvider)
                                              .valueOrNull ??
                                          profile,
                                    ) >
                                    0)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: colors.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: colors.card, width: 3),
                                      ),
                                      child: Icon(Icons.camera_alt_rounded,
                                          size: 22, color: colors.card),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _profilePhotoChangesRemaining(
                                      ref
                                              .read(driverProfileProvider)
                                              .valueOrNull ??
                                          profile,
                                    ) >
                                    0
                                ? DriverStrings.profilePhotoAddHint
                                : DriverStrings.profilePhotoLockedMessage,
                            style: typo.labelSmall
                                .copyWith(color: colors.textSoft),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            DriverStrings.profilePhotoChangesRemaining(
                              _profilePhotoChangesRemaining(
                                ref.read(driverProfileProvider).valueOrNull ??
                                    profile,
                              ),
                            ),
                            textAlign: TextAlign.center,
                            style: typo.labelSmall
                                .copyWith(color: colors.textSoft),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: DriverStrings.profileEditNameTitle,
                            hintText: DriverStrings.profileEditNameSubtitle,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () async {
                            final t = nameController.text.trim();
                            if (t.isEmpty) return;
                            // Close sheet first — await pop so the route tears down before we
                            // invalidate providers / dispose the controller (see post-await dispose).
                            await Navigator.of(ctx).maybePop();
                            await Future<void>.delayed(Duration.zero);
                            if (!mounted) return;
                            await _saveNameFromSheet(t, id);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(DriverStrings.saveAction),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(DriverStrings.cancel),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      // Do NOT use .whenComplete(dispose): the sheet's Future completes while the route may
      // still be animating/unmounting — TextField then hits a disposed controller (and framework
      // asserts _dependents.isEmpty). Dispose after the next frame once the route is gone.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final profileAsync = ref.watch(driverProfileProvider);
    final complianceAsync = ref.watch(driverComplianceProvider);
    final runtimeAsync = ref.watch(driverRuntimeSnapshotProvider);
    final savedByRidersInline = savedByRidersInlineCopy(
      ref.watch(driverFavoriteSummaryProvider).valueOrNull,
    );
    final email = HeyCabySupabase.client.auth.currentUser?.email;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          profileAsync.when(
            data: (profile) {
              final compliance = complianceAsync.valueOrNull;
              final rating = profile?.displayRating ?? 5.0;
              final vehicle = profile?.vehicleDisplay ?? '—';
              final vvs = compliance?.vehicleVerificationStatus ?? '';
              final plate =
                  (compliance?.vehiclePlate ?? profile?.vehiclePlate ?? '')
                      .trim();
              final vehicleCardValue = plate.isNotEmpty ? plate : '—';
              final nameFromDb = profile?.fullName?.trim();
              final bool hasName;
              final String headline;
              if (nameFromDb != null && nameFromDb.isNotEmpty) {
                hasName = true;
                headline = nameFromDb;
              } else {
                hasName = false;
                headline = DriverStrings.profileNamePlaceholder;
              }
              final initials = _initialsFromNameOrEmail(nameFromDb, email);
              final apkExpiry = compliance?.apkExpiry != null
                  ? '${compliance!.apkExpiry!.day}/${compliance.apkExpiry!.month}/${compliance.apkExpiry!.year}'
                  : null;
              final runtime = runtimeAsync.valueOrNull;
              final vehiclePhotoUrl =
                  profile?.vehiclePhotoUrls.isNotEmpty == true
                      ? profile!.vehiclePhotoUrls.first
                      : null;
              final vehicleDescriptor = _vehicleDescriptor(profile, compliance);

              return DriverIdentityBody(
                colors: colors,
                typography: typography,
                model: DriverIdentityViewModel(
                  headline: headline,
                  initials: initials,
                  profilePhotoUrl: profile?.profilePhotoUrl,
                  vehiclePhotoUrl: vehiclePhotoUrl,
                  email: email,
                  emphasizePlaceholder: !hasName,
                  rating: rating,
                  foundingNumber: profile?.foundingNumber,
                  showFoundingShield: (profile?.isFoundingDriver ?? false) &&
                      ((profile?.foundingNumber ?? 0) >= 1) &&
                      ((profile?.foundingNumber ?? 0) <= 200),
                  isVerifiedBadge: profile?.isVerifiedBadge ?? false,
                  vehiclePlate: vehicleCardValue,
                  vehicleDisplay: vehicle,
                  showVehicleVerified: vvs == 'rdw_verified_taxi',
                  apkExpiryLabel: apkExpiry,
                  vehicleDescriptor:
                      vehicleDescriptor.isEmpty ? null : vehicleDescriptor,
                  vehicleSeats: profile?.passengerSeats,
                  completionItems: _completionItems(
                    profile: profile,
                    compliance: compliance,
                    runtime: runtime,
                  ),
                  savedByRidersCountLine: savedByRidersInline?.countLine,
                  savedByRidersNamesLine: savedByRidersInline?.namesLine,
                ),
                onEditProfile: () async {
                  HapticService.lightTap();
                  await _openProfileEditSheet(
                    profile,
                    nameFromDb,
                    email,
                    _profilePhotoCacheBust,
                  );
                },
                onOpenVehicle: () => context.push('/driver/vehicle'),
                onAddVehiclePhoto: () async {
                  HapticService.lightTap();
                  await _pickAndConfirmVehiclePhoto(profile, compliance);
                },
                onOpenRatings: () => showDriverRatingSheet(
                  context: context,
                  colors: colors,
                  typography: typography,
                ),
                onOpenSettings: () => context.push('/driver/settings'),
                onOpenRequirement: _openRequirement,
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
            error: (_, __) => Center(
              child: Text(
                DriverStrings.profileLoadFailed,
                style: typography.bodyMedium.copyWith(color: colors.textMuted),
              ),
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: colors.text.withValues(alpha: 0.2),
                child: Center(
                  child: CircularProgressIndicator(color: colors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final String? photoUrl;

  /// Increment after a new upload so the image URL differs for [CachedNetworkImage] (same path, new file).
  final int photoCacheBust;
  final String? initials;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final double size;

  const _DriverAvatar({
    this.photoUrl,
    this.photoCacheBust = 0,
    this.initials,
    required this.colors,
    required this.typo,
    required this.size,
  });

  String? _displayUrl(String base) {
    final t = base.trim();
    if (t.isEmpty) return null;
    if (photoCacheBust <= 0) return t;
    final u = Uri.parse(t);
    final q = Map<String, String>.from(u.queryParameters);
    q['v'] = '$photoCacheBust';
    return u.replace(queryParameters: q).toString();
  }

  @override
  Widget build(BuildContext context) {
    final raw = photoUrl?.trim();
    final url = raw != null && raw.isNotEmpty ? _displayUrl(raw) : null;
    if (url != null && isValidImageUrl(url)) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: colors.accentL,
              alignment: Alignment.center,
              child:
                  Icon(AppIcons.person, size: size * 0.5, color: colors.accent),
            ),
            errorWidget: (_, __, ___) => Container(
              color: colors.accentL,
              alignment: Alignment.center,
              child:
                  Icon(AppIcons.person, size: size * 0.5, color: colors.accent),
            ),
          ),
        ),
      );
    }
    final letter = (initials != null && initials!.isNotEmpty) ? initials! : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.accentL,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: typo.displayMedium.copyWith(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: colors.accent,
        ),
      ),
    );
  }
}
