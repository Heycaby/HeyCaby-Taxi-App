import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/favorites_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/rider_driver_profile_service.dart';
import '../widgets/rider_driver_info_card.dart';

class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 0;

  final _feedbackController = TextEditingController();
  bool _noteExpanded = false;
  bool _isSubmitting = false;

  RiderDriverSheetInfo? _driverInfo;
  String? _driverId;

  static const int _saveDriverMinRating = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadDriver());
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadDriver() async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final map = await RiderDriverProfileService.fetchForRide(
        rideRequestId: rideId,
        riderToken: identity.riderToken,
      );
      if (!mounted || map == null) return;
      setState(() {
        _driverInfo = RiderDriverSheetInfo.fromJson(
          map,
          fallbackDriverLabel: AppLocalizations.of(context).driver,
        );
        _driverId = (map['driver_id'] as String?)?.trim();
      });
    } catch (_) {
      // Card shows fallback when profile unavailable.
    }
  }

  void _onOverallRatingChanged(int value) {
    HapticService.selectionClick();
    setState(() => _rating = value);
  }

  Future<void> _promptSaveDriverAfterSubmit() async {
    final driverId = _driverId;
    if (driverId == null || driverId.isEmpty) return;

    final favorites = ref.read(favoritesProvider).valueOrNull;
    if (favorites != null &&
        favorites.any((driver) => driver.driverId == driverId)) {
      return;
    }

    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showHeyCabyConfirmSheet(
      context,
      colors: colors,
      typography: typo,
      title: l10n.saveDriverModalTitle,
      message: l10n.saveDriverModalBody,
      dismissLabel: l10n.saveDriverModalDismiss,
      confirmLabel: l10n.saveDriverModalConfirm,
      icon: Icons.favorite_rounded,
      iconColor: colors.accent,
      confirmDestructive: false,
    );
    if (!mounted || !confirmed) return;

    final rideRequestId = ref.read(rideRequestProvider).rideRequestId;
    if (rideRequestId == null) return;

    final identity = await ref.read(riderIdentityProvider.future);
    final result = await ref.read(favoritesProvider.notifier).addFavorite(
          rideRequestId: rideRequestId,
          driverId: driverId,
          riderToken: identity.riderToken,
        );

    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).driverSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (result.reason == 'favorite_limit_reached') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).favoritesLimitReached),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;

    HapticService.mediumTap();
    setState(() => _isSubmitting = true);

    try {
      final rideRequestId = ref.read(rideRequestProvider).rideRequestId;
      if (rideRequestId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).failedToSubmitRating),
            ),
          );
        }
        return;
      }

      final identity = await ref.read(riderIdentityProvider.future);
      final comment = _feedbackController.text.trim();

      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_rate_driver',
        params: {
          'p_ride_request_id': rideRequestId,
          'p_rating': _rating,
          if (comment.isNotEmpty) 'p_comment': comment,
          if (identity.riderToken != null && identity.riderToken!.isNotEmpty)
            'p_rider_token': identity.riderToken,
        },
      );

      final result = Map<String, dynamic>.from(response as Map);
      if (result['ok'] != true) {
        throw Exception(result['error'] ?? 'rating_failed');
      }

      final driverIdFromRpc = (result['driver_id'] as String?)?.trim();
      if (driverIdFromRpc != null && driverIdFromRpc.isNotEmpty) {
        _driverId ??= driverIdFromRpc;
      }

      if (!mounted) return;
      HapticService.success();

      if (_rating >= _saveDriverMinRating) {
        await _promptSaveDriverAfterSubmit();
      }

      if (mounted) context.go('/home');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Rating submit error: $e');
        debugPrint('$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToSubmitRating),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _canSubmit => _rating > 0;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final driverInfo = _driverInfo ??
        RiderDriverSheetInfo(
          fullName: l10n.driver,
        );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _RatingTopBar(
              colors: colors,
              typo: typo,
              title: l10n.rateYourDriver,
              onClose: _isSubmitting ? null : () => context.go('/home'),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RiderDriverInfoCard(
                            driverInfo: driverInfo,
                            colors: colors,
                            typo: typo,
                            l10n: l10n,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.howWasYourRide,
                            textAlign: TextAlign.center,
                            style: typo.headingSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _StarRating(
                            rating: _rating,
                            colors: colors,
                            onRatingChanged: _onOverallRatingChanged,
                          ),
                          const SizedBox(height: 32),
                          _OptionalNote(
                            colors: colors,
                            typo: typo,
                            expanded: _noteExpanded,
                            hint: l10n.tellUsMore,
                            label: l10n.ratingAddNoteOptional,
                            controller: _feedbackController,
                            onToggle: () {
                              HapticService.lightTap();
                              setState(() => _noteExpanded = !_noteExpanded);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _RatingActionDock(
              colors: colors,
              typo: typo,
              submitLabel: l10n.submitRating,
              skipLabel: l10n.skip,
              canSubmit: _canSubmit,
              isSubmitting: _isSubmitting,
              onSubmit: _submitRating,
              onSkip: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingTopBar extends StatelessWidget {
  const _RatingTopBar({
    required this.colors,
    required this.typo,
    required this.title,
    required this.onClose,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: colors.textMid, size: 22),
            tooltip: title,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: typo.titleMedium.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _OptionalNote extends StatelessWidget {
  const _OptionalNote({
    required this.colors,
    required this.typo,
    required this.expanded,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onToggle,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool expanded;
  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return TextButton(
        onPressed: onToggle,
        style: TextButton.styleFrom(
          foregroundColor: colors.textSoft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          style: typo.bodyMedium.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          style: typo.bodyMedium.copyWith(color: colors.text),
          maxLines: 3,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
            filled: true,
            fillColor: colors.card,
            contentPadding: const EdgeInsetsDirectional.all(16),
            counterStyle: typo.bodySmall.copyWith(color: colors.textSoft),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: onToggle,
            child: Text(
              label,
              style: typo.bodySmall.copyWith(color: colors.textSoft),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingActionDock extends StatelessWidget {
  const _RatingActionDock({
    required this.colors,
    required this.typo,
    required this.submitLabel,
    required this.skipLabel,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onSkip,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String submitLabel;
  final String skipLabel;
  final bool canSubmit;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        24,
        8,
        24,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: !canSubmit || isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: colors.onAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      submitLabel,
                      style: typo.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          TextButton(
            onPressed: isSubmitting ? null : onSkip,
            child: Text(
              skipLabel,
              style: typo.bodyMedium.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int rating;
  final HeyCabyColorTokens colors;
  final ValueChanged<int> onRatingChanged;

  const _StarRating({
    required this.rating,
    required this.colors,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= rating;
        return GestureDetector(
          onTap: () => onRatingChanged(starValue),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
            child: AnimatedScale(
              scale: filled ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: filled ? colors.warning : colors.border,
                size: 52,
              ),
            ),
          ),
        );
      }),
    );
  }
}
