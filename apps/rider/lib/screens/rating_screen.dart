import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/rating_route_args.dart';
import '../providers/ride_request_provider.dart';
import '../services/rider_driver_profile_service.dart';
import '../widgets/rider_driver_info_card.dart';
import '../widgets/save_driver_favorite_prompt.dart';

enum RatingPresentation { route, modal }

enum _ModalPhase { thankYou, rating }

/// Post-trip driver rating. Plain [StatefulWidget] so async submit never keeps
/// Riverpod watch subscriptions on a route that is about to dispose.
class RatingScreen extends StatefulWidget {
  const RatingScreen({
    super.key,
    this.routeArgs,
    this.presentation = RatingPresentation.route,
    this.showPaymentThankYouFirst = false,
  });

  final RatingRouteArgs? routeArgs;
  final RatingPresentation presentation;
  final bool showPaymentThankYouFirst;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  static const _sessionService = RiderSessionService();

  int _rating = 0;

  final _feedbackController = TextEditingController();
  bool _noteExpanded = false;
  bool _isSubmitting = false;

  RiderDriverSheetInfo? _driverInfo;
  String? _driverId;
  String? _rideRequestId;
  String? _riderToken;

  static const int _saveDriverMinRating = 4;

  late _ModalPhase _modalPhase;
  Timer? _thankYouAutoAdvanceTimer;

  ProviderContainer get _container =>
      ProviderScope.containerOf(context, listen: false);

  @override
  void initState() {
    super.initState();
    _modalPhase = widget.showPaymentThankYouFirst
        ? _ModalPhase.thankYou
        : _ModalPhase.rating;
    if (_modalPhase == _ModalPhase.thankYou) {
      HapticService.success();
      _thankYouAutoAdvanceTimer = Timer(
        const Duration(milliseconds: 2800),
        _advanceFromThankYou,
      );
    }
    _rideRequestId = widget.routeArgs?.rideRequestId;
    _riderToken = widget.routeArgs?.riderToken;
    _driverInfo = widget.routeArgs?.driverInfo;
    _driverId = _driverInfo?.driverId?.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ride = _container.read(rideRequestProvider);
      _rideRequestId ??= ride.rideRequestId;
      _riderToken ??= ride.riderToken;
      unawaited(_hydrateRideContext());
    });
  }

  Future<void> _hydrateRideContext() async {
    final rideId = _rideRequestId;
    if (rideId == null || rideId.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final dbToken = await _sessionService.fetchRideRiderToken(
      rideId,
      hintToken: _riderToken,
    );
    if (dbToken != null && dbToken.isNotEmpty) {
      _riderToken = dbToken;
      await _sessionService.bindToken(dbToken);
    }
    if (!mounted) return;
    if (_driverInfo == null) {
      await _loadDriver();
    } else {
      setState(() {});
    }
  }

  Future<String?> _resolveRiderTokenForSubmit() async {
    final rideId = _rideRequestId;
    if (rideId == null || rideId.isEmpty) return null;

    final dbToken = await _sessionService.fetchRideRiderToken(
      rideId,
      hintToken: _riderToken,
    );
    if (dbToken != null && dbToken.isNotEmpty) {
      await _sessionService.bindToken(dbToken);
      _riderToken = dbToken;
      return dbToken;
    }

    final routeToken = _riderToken?.trim();
    if (routeToken != null && routeToken.isNotEmpty) {
      await _sessionService.bindToken(routeToken);
      return routeToken;
    }

    return null;
  }

  @override
  void dispose() {
    _thankYouAutoAdvanceTimer?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  void _advanceFromThankYou() {
    if (!mounted || _modalPhase != _ModalPhase.thankYou) return;
    _thankYouAutoAdvanceTimer?.cancel();
    setState(() => _modalPhase = _ModalPhase.rating);
  }

  Future<void> _loadDriver() async {
    final rideId = _rideRequestId;
    if (rideId == null || rideId.isEmpty) return;
    try {
      final token = await _resolveRiderTokenForSubmit();
      final map = await RiderDriverProfileService.fetchForRide(
        rideRequestId: rideId,
        riderToken: token,
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

  Future<void> _submitRating() async {
    if (_rating == 0 || _isSubmitting) return;

    final rideRequestId = _rideRequestId;
    if (rideRequestId == null || rideRequestId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failedToSubmitRating),
          ),
        );
      }
      return;
    }

    HapticService.mediumTap();
    setState(() => _isSubmitting = true);

    final container = _container;
    try {
      final riderToken = await _resolveRiderTokenForSubmit();
      if (riderToken == null || riderToken.isEmpty) {
        throw Exception('missing_rider_token');
      }
      await _sessionService.bindToken(riderToken);

      final comment = _feedbackController.text.trim();

      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_rate_driver',
        params: {
          'p_ride_request_id': rideRequestId,
          'p_rating': _rating,
          'p_rider_token': riderToken,
          if (comment.isNotEmpty) 'p_comment': comment,
        },
      );

      if (response is! Map) {
        throw Exception('invalid_rpc_response');
      }
      final result = Map<String, dynamic>.from(response);
      if (result['ok'] != true) {
        final errorCode = result['error']?.toString() ?? 'rating_failed';
        if (kDebugMode) debugPrint('Rating RPC rejected: $errorCode');
        throw Exception(errorCode);
      }

      final driverIdFromRpc = (result['driver_id'] as String?)?.trim();
      if (driverIdFromRpc != null && driverIdFromRpc.isNotEmpty) {
        _driverId ??= driverIdFromRpc;
      }

      if (!mounted) return;
      HapticService.success();

      final driverId = _driverId;
      SaveDriverFavoriteOutcome saveOutcome = SaveDriverFavoriteOutcome.skipped;
      if (_rating >= _saveDriverMinRating &&
          driverId != null &&
          driverId.isNotEmpty) {
        saveOutcome = await maybeShowSaveDriverFavoritePrompt(
          context,
          container: container,
          rideRequestId: rideRequestId,
          driverId: driverId,
          riderToken: riderToken,
        );
      }

      if (!mounted) return;
      await _completePostRideFlow();
      queueFavoriteSaveFeedback(container, saveOutcome);
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _canSubmit => _rating > 0;

  Future<void> _completePostRideFlow() async {
    final container = _container;
    final router = GoRouter.of(context);
    if (widget.presentation == RatingPresentation.modal) {
      Navigator.of(context).pop();
    }
    router.go('/home');
    Future.microtask(() {
      container.read(rideRequestProvider.notifier).reset();
    });
  }

  void _leaveWithoutRating() {
    unawaited(_completePostRideFlow());
  }

  @override
  Widget build(BuildContext context) {
    final colors = _container.read(colorsProvider);
    final typo = _container.read(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final driverInfo = _driverInfo ??
        RiderDriverSheetInfo(
          fullName: l10n.driver,
        );

    final content = Column(
      children: [
        _RatingTopBar(
          colors: colors,
          typo: typo,
          title: l10n.rateYourDriver,
          onClose: _isSubmitting ? null : _leaveWithoutRating,
          showDragHandle: widget.presentation == RatingPresentation.modal,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 24),
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
          onSkip: _isSubmitting ? null : _leaveWithoutRating,
        ),
      ],
    );

    if (widget.presentation == RatingPresentation.modal) {
      final bottom = MediaQuery.paddingOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
        child: GlassPanel(
          colors: colors,
          typography: typo,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          borderRadius: BorderRadius.circular(28),
          tintColor: colors.card,
          borderColor: colors.border.withValues(alpha: 0.55),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _modalPhase == _ModalPhase.thankYou
                ? _ModalThankYouBody(
                    key: const ValueKey('thank_you'),
                    colors: colors,
                    typo: typo,
                    message: l10n.paymentThankYou,
                    continueLabel: l10n.continueButton,
                    onContinue: _advanceFromThankYou,
                  )
                : _ModalRatingBody(
                    key: const ValueKey('rating'),
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    driverInfo: driverInfo,
                    rating: _rating,
                    noteExpanded: _noteExpanded,
                    feedbackController: _feedbackController,
                    canSubmit: _canSubmit,
                    isSubmitting: _isSubmitting,
                    onClose: _isSubmitting ? null : _leaveWithoutRating,
                    onRatingChanged: _onOverallRatingChanged,
                    onToggleNote: () {
                      HapticService.lightTap();
                      setState(() => _noteExpanded = !_noteExpanded);
                    },
                    onSubmit: _submitRating,
                    onSkip: _isSubmitting ? null : _leaveWithoutRating,
                  ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(child: content),
    );
  }
}

class _ModalThankYouBody extends StatelessWidget {
  const _ModalThankYouBody({
    super.key,
    required this.colors,
    required this.typo,
    required this.message,
    required this.continueLabel,
    required this.onContinue,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String message;
  final String continueLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: colors.accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: typo.headingSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onContinue,
              child: Text(
                continueLabel,
                style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalRatingBody extends StatelessWidget {
  const _ModalRatingBody({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.driverInfo,
    required this.rating,
    required this.noteExpanded,
    required this.feedbackController,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onClose,
    required this.onRatingChanged,
    required this.onToggleNote,
    required this.onSubmit,
    required this.onSkip,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final RiderDriverSheetInfo driverInfo;
  final int rating;
  final bool noteExpanded;
  final TextEditingController feedbackController;
  final bool canSubmit;
  final bool isSubmitting;
  final VoidCallback? onClose;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onToggleNote;
  final VoidCallback onSubmit;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RatingTopBar(
          colors: colors,
          typo: typo,
          title: l10n.rateYourDriver,
          onClose: onClose,
          showDragHandle: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.accentL,
                backgroundImage: (driverInfo.profilePhotoUrl != null &&
                        driverInfo.profilePhotoUrl!.isNotEmpty)
                    ? NetworkImage(driverInfo.profilePhotoUrl!)
                    : null,
                child: (driverInfo.profilePhotoUrl == null ||
                        driverInfo.profilePhotoUrl!.isEmpty)
                    ? Icon(Icons.person_rounded, color: colors.accent, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  driverInfo.fullName,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.howWasYourRide,
          textAlign: TextAlign.center,
          style: typo.titleSmall.copyWith(
            color: colors.textMid,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _StarRating(
          rating: rating,
          colors: colors,
          onRatingChanged: onRatingChanged,
        ),
        const SizedBox(height: 8),
        _OptionalNote(
          colors: colors,
          typo: typo,
          expanded: noteExpanded,
          hint: l10n.tellUsMore,
          label: l10n.ratingAddNoteOptional,
          controller: feedbackController,
          onToggle: onToggleNote,
        ),
        _RatingActionDock(
          colors: colors,
          typo: typo,
          submitLabel: l10n.submitRating,
          skipLabel: l10n.skip,
          canSubmit: canSubmit,
          isSubmitting: isSubmitting,
          onSubmit: onSubmit,
          onSkip: onSkip,
        ),
      ],
    );
  }
}

class _RatingTopBar extends StatelessWidget {
  const _RatingTopBar({
    required this.colors,
    required this.typo,
    required this.title,
    required this.onClose,
    this.showDragHandle = false,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final VoidCallback? onClose;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) ...[
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
        Padding(
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
        ),
      ],
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
  final VoidCallback? onSkip;

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
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                color: filled ? colors.warning : colors.textMid,
                size: 44,
              ),
            ),
          ),
        );
      }),
    );
  }
}
