import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart'
    show DriverProfile, ProfilePhotoConnectionException;
import '../theme/app_icons.dart';
import '../utils/driver_account_deletion.dart';
import '../utils/driver_logout.dart';
import '../utils/validation_utils.dart';

/// Full profile screen — name, photo (one-time), rating.
class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  bool _busy = false;

  /// Bumps when a new photo is saved so [CachedNetworkImage] fetches a new file (URL path is unchanged).
  /// Notifier so the profile sheet avatar updates without stale closure values.
  final ValueNotifier<int> _profilePhotoCacheBust = ValueNotifier<int>(0);

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

  Future<void> _pickAndConfirmProfilePhoto(DriverProfile? profile) async {
    if (profile?.profilePhotoLocked == true) {
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
        final themeColors = ref.read(colorsProvider);
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
      url = await ref.read(driverDataServiceProvider).uploadDriverProfilePhotoOnce(
            driverId: id,
            bytes: bytes,
            contentType: contentType,
            fileExtension: ext,
          );
    } on ProfilePhotoConnectionException {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.profilePhotoUploadConnectionError)),
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
                                if (!(profile?.profilePhotoLocked == true))
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
                            DriverStrings.profilePhotoAddHint,
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
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final profileAsync = ref.watch(driverProfileProvider);
    final complianceAsync = ref.watch(driverComplianceProvider);
    final email = HeyCabySupabase.client.auth.currentUser?.email;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          profileAsync.when(
            data: (profile) {
              final compliance = complianceAsync.valueOrNull;
              final rating = profile?.displayRating ?? 0.0;
              final vehicle = profile?.vehicleDisplay ?? '—';

              // ── Documents status badge ──────────────────────────────────
              final _DocStatus docStatus;
              if (compliance?.complianceStatus == 'compliant' ||
                  (profile?.isVerifiedBadge == true)) {
                docStatus = _DocStatus.verified;
              } else if ((compliance?.chauffeurspasNumber ?? '').isNotEmpty ||
                  (compliance?.veriffStatus ?? '').isNotEmpty ||
                  (compliance?.taxiInsuranceProvider ?? '').isNotEmpty ||
                  (compliance?.taxiInsurancePhotoUrl ?? '').isNotEmpty) {
                // Something submitted but not all verified
                docStatus = compliance?.complianceStatus == 'pending_review'
                    ? _DocStatus.submitted
                    : _DocStatus.inReview;
              } else {
                docStatus = _DocStatus.required;
              }

              // ── Vehicle status badge ────────────────────────────────────
              final vvs = compliance?.vehicleVerificationStatus ?? '';
              final _VehicleStatus vehicleStatus;
              if (vvs == 'rdw_verified_taxi') {
                vehicleStatus = _VehicleStatus.verified;
              } else if (vvs == 'rdw_verified_not_taxi') {
                vehicleStatus = _VehicleStatus.notTaxi;
              } else if (vvs == 'rdw_not_found') {
                vehicleStatus = _VehicleStatus.manualReview;
              } else if ((compliance?.vehiclePlate ?? '').isNotEmpty) {
                vehicleStatus = _VehicleStatus.checking;
              } else {
                vehicleStatus = _VehicleStatus.required;
              }

              // ── Vehicle stat card — plate + verification color ──────────
              final plate = (compliance?.vehiclePlate ?? profile?.vehiclePlate ?? '').trim();
              final vehicleCardValue = plate.isNotEmpty ? plate : '—';
              final vehicleCardColor = vvs == 'rdw_verified_taxi'
                  ? colors.success
                  : plate.isNotEmpty
                      ? colors.textMid
                      : null; // null → default (colors.text from _StatCard)
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

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: colors.bg,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    centerTitle: true,
                    title: Text(
                      DriverStrings.profile,
                      style: typo.headingMedium.copyWith(color: colors.text),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: _profilePhotoCacheBust,
                            builder: (context, bust, _) {
                              return _ProfileCardLarge(
                                photoUrl: profile?.profilePhotoUrl,
                                photoCacheBust: bust,
                                headline: headline,
                                subtitleEmail: email,
                                initials: initials,
                                emphasizePlaceholder: !hasName,
                                rating: rating,
                                vehicle: vehicle,
                                profilePhotoLocked:
                                    profile?.profilePhotoLocked ?? false,
                                isVerifiedBadge:
                                    profile?.isVerifiedBadge ?? false,
                                colors: colors,
                                typo: typo,
                                onTapCard: () async {
                                  HapticFeedback.lightImpact();
                                  await _openProfileEditSheet(
                                    profile,
                                    nameFromDb,
                                    email,
                                    _profilePhotoCacheBust,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: AppIcons.star,
                                  iconColor: colors.accent,
                                  label: DriverStrings.driverRating,
                                  value: rating.toStringAsFixed(1),
                                  colors: colors,
                                  typo: typo,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: AppIcons.carFront,
                                  iconColor: vehicleCardColor ?? colors.textMid,
                                  label: DriverStrings.vehicle,
                                  value: vehicleCardValue,
                                  valueColor: vehicleCardColor,
                                  showVerifiedDot: vvs == 'rdw_verified_taxi',
                                  colors: colors,
                                  typo: typo,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            DriverStrings.preferences,
                            style: typo.labelLarge.copyWith(
                                color: colors.textSoft,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          _ActionCard(
                            colors: colors,
                            children: [
                              _ActionTile(
                                icon: AppIcons.menuDocuments,
                                title: DriverStrings.documents,
                                badge: _docStatusBadge(docStatus, colors, typo),
                                colors: colors,
                                typo: typo,
                                onTap: () => context.push('/driver/documents'),
                              ),
                              _CardDivider(colors: colors),
                              _ActionTile(
                                icon: AppIcons.carOutline,
                                title: DriverStrings.vehicle,
                                badge: _vehicleStatusBadge(vehicleStatus, colors, typo),
                                colors: colors,
                                typo: typo,
                                onTap: () => context.push('/driver/vehicle'),
                              ),
                              _CardDivider(colors: colors),
                              _ActionTile(
                                icon: AppIcons.tune,
                                title: DriverStrings.preferences,
                                colors: colors,
                                typo: typo,
                                onTap: () =>
                                    context.push('/driver/preferences'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            DriverStrings.support,
                            style: typo.labelLarge.copyWith(
                                color: colors.textSoft,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          _ActionCard(
                            colors: colors,
                            children: [
                              _ActionTile(
                                icon: AppIcons.chat,
                                title: DriverStrings.support,
                                colors: colors,
                                typo: typo,
                                onTap: () => context.push('/driver/support'),
                              ),
                              _CardDivider(colors: colors),
                              _ActionTile(
                                icon: AppIcons.article,
                                title: DriverStrings.helpArticles,
                                colors: colors,
                                typo: typo,
                                onTap: () =>
                                    context.push('/driver/help-articles'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            DriverStrings.account,
                            style: typo.labelLarge.copyWith(
                                color: colors.textSoft,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          _ActionCard(
                            colors: colors,
                            children: [
                              _DeleteAccountProfileRow(
                                colors: colors,
                                typo: typo,
                                onTap: () => performDriverAccountDeletion(context, ref),
                              ),
                              _CardDivider(colors: colors),
                              _LogoutProfileRow(
                                colors: colors,
                                typo: typo,
                                onTap: () => performDriverLogout(context, ref),
                              ),
                            ],
                          ),
                          SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom + 88),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text(
                'Could not load profile',
                style: typo.bodyMedium.copyWith(color: colors.textSoft),
              ),
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: colors.text.withValues(alpha: 0.2),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Documents / Vehicle status enums ─────────────────────────────────────────

enum _DocStatus { required, inReview, submitted, verified }

enum _VehicleStatus { required, checking, verified, notTaxi, manualReview }

Widget _docStatusBadge(
    _DocStatus s, HeyCabyColorTokens c, HeyCabyTypography t) {
  switch (s) {
    case _DocStatus.verified:
      return _StatusBadge(label: '✓ Geverifieerd', bg: c.success, fg: Colors.white, typo: t);
    case _DocStatus.submitted:
      return _StatusBadge(label: 'Ingediend', bg: const Color(0xFF2563EB), fg: Colors.white, typo: t);
    case _DocStatus.inReview:
      return _StatusBadge(label: 'In behandeling', bg: c.textSoft.withValues(alpha: 0.15), fg: c.textMid, typo: t);
    case _DocStatus.required:
      return _StatusBadge(label: 'Vereist', bg: c.accent.withValues(alpha: 0.15), fg: c.accent, typo: t);
  }
}

Widget _vehicleStatusBadge(
    _VehicleStatus s, HeyCabyColorTokens c, HeyCabyTypography t) {
  switch (s) {
    case _VehicleStatus.verified:
      return _StatusBadge(label: '✓ Geverifieerd', bg: c.success, fg: Colors.white, typo: t);
    case _VehicleStatus.notTaxi:
      return _StatusBadge(label: 'Niet-taxi voertuig', bg: c.error.withValues(alpha: 0.15), fg: c.error, typo: t);
    case _VehicleStatus.manualReview:
      return _StatusBadge(label: 'Handmatige beoordeling', bg: c.accent.withValues(alpha: 0.15), fg: c.accent, typo: t);
    case _VehicleStatus.checking:
      return _StatusBadge(label: 'Controleren...', bg: c.textSoft.withValues(alpha: 0.15), fg: c.textMid, typo: t);
    case _VehicleStatus.required:
      return _StatusBadge(label: 'Vereist', bg: c.accent.withValues(alpha: 0.15), fg: c.accent, typo: t);
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final HeyCabyTypography typo;

  const _StatusBadge({
    required this.label,
    required this.bg,
    required this.fg,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: typo.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Large tappable card — entire area opens the profile editor sheet.
class _ProfileCardLarge extends StatelessWidget {
  final String? photoUrl;

  /// See [_DriverProfileScreenState._photoCacheBust].
  final int photoCacheBust;
  final String headline;
  final String? subtitleEmail;
  final String initials;
  final bool emphasizePlaceholder;
  final double rating;
  final String vehicle;
  final bool profilePhotoLocked;
  final bool isVerifiedBadge;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTapCard;

  const _ProfileCardLarge({
    required this.photoUrl,
    this.photoCacheBust = 0,
    required this.headline,
    required this.subtitleEmail,
    required this.initials,
    required this.emphasizePlaceholder,
    required this.rating,
    required this.vehicle,
    required this.profilePhotoLocked,
    required this.isVerifiedBadge,
    required this.colors,
    required this.typo,
    required this.onTapCard,
  });

  bool get _hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapCard,
        splashColor: colors.accent.withValues(alpha: 0.12),
        highlightColor: colors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _DriverAvatar(
                          photoUrl: photoUrl,
                          photoCacheBust: photoCacheBust,
                          initials: initials,
                          colors: colors,
                          typo: typo,
                          size: 104,
                        ),
                        if (profilePhotoLocked && _hasPhoto)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: colors.card,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.border),
                              ),
                              child: Icon(Icons.lock_rounded,
                                  size: 16, color: colors.textMid),
                            ),
                          )
                        else
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: colors.card, width: 2),
                              ),
                              child: Icon(Icons.edit_rounded,
                                  size: 16, color: colors.card),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  headline,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: typo.titleMedium.copyWith(
                                    color: emphasizePlaceholder
                                        ? colors.textSoft
                                        : colors.text,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: colors.textSoft, size: 26),
                            ],
                          ),
                          if (subtitleEmail != null &&
                              subtitleEmail!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitleEmail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typo.bodySmall
                                  .copyWith(color: colors.textSoft),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(AppIcons.star,
                                  size: 18, color: colors.accent),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: typo.bodyMedium.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: colors.border,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  vehicle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typo.bodySmall
                                      .copyWith(color: colors.textSoft),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isVerifiedBadge)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(AppIcons.verified,
                              size: 18, color: colors.accent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.accentL.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 18, color: colors.accent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          DriverStrings.profileTapHint,
                          textAlign: TextAlign.center,
                          style: typo.labelSmall.copyWith(
                            color: colors.textMid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showVerifiedDot;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
    this.valueColor,
    this.showVerifiedDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.labelSmall
                      .copyWith(color: colors.textSoft, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (showVerifiedDot) ...[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.bodyLarge.copyWith(
                    color: valueColor ?? colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final List<Widget> children;

  const _ActionCard({required this.colors, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? badge;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: colors.textMid, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: typo.bodyMedium
                    .copyWith(color: colors.text, fontWeight: FontWeight.w600),
              ),
            ),
            if (badge != null) ...[
              badge!,
              const SizedBox(width: 6),
            ],
            Icon(AppIcons.chevronRight, color: colors.textSoft),
          ],
        ),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  final HeyCabyColorTokens colors;
  const _CardDivider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1, thickness: 1, color: colors.border.withValues(alpha: 0.8));
  }
}

class _DeleteAccountProfileRow extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _DeleteAccountProfileRow({
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.delete_forever_outlined, color: colors.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DriverStrings.deleteAccount,
                style: typo.bodyMedium.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutProfileRow extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _LogoutProfileRow({
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(AppIcons.menuLogout, color: colors.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DriverStrings.logout,
                style: typo.bodyMedium.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
