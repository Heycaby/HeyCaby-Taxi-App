import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../widgets/booking/booking_flow_screen_header.dart';
import '../providers/ride_request_provider.dart';

class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 0;
  int _punctuality = 0;
  int _cleanliness = 0;
  int _attitude = 0;
  int _drivingSafety = 0;
  int _communication = 0;

  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  List<String> _getQuickFeedback(AppLocalizations l10n) => [
        l10n.ratingGreatDriver,
        l10n.ratingCleanVehicle,
        l10n.ratingSafeDriving,
        l10n.ratingFriendly,
        l10n.ratingOnTime,
        l10n.ratingProfessional,
      ];

  final Set<String> _selectedFeedback = {};

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _onOverallRatingChanged(int value) {
    HapticService.selectionClick();
    setState(() {
      _rating = value;
      _punctuality = value;
      _cleanliness = value;
      _attitude = value;
      _drivingSafety = value;
      _communication = value;
    });
  }

  String _buildRiderComment() {
    final tags = _selectedFeedback.toList()..sort();
    final text = _feedbackController.text.trim();
    final buf = StringBuffer();
    if (tags.isNotEmpty) {
      buf.write(tags.join(', '));
    }
    if (text.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.write(text);
    }
    return buf.toString();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    if (_punctuality < 1 ||
        _cleanliness < 1 ||
        _attitude < 1 ||
        _drivingSafety < 1 ||
        _communication < 1) {
      return;
    }

    HapticService.mediumTap();
    setState(() => _isSubmitting = true);

    try {
      final rideRequestId = ref.read(rideRequestProvider).rideRequestId;
      if (rideRequestId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).failedToSubmitRating)),
          );
        }
        return;
      }

      final comment = _buildRiderComment();
      final payload = <String, dynamic>{
        'rider_rating_of_driver': _rating,
        'punctuality': _punctuality,
        'cleanliness': _cleanliness,
        'attitude': _attitude,
        'driving_safety': _drivingSafety,
        'communication': _communication,
        'rider_rated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (comment.isNotEmpty) {
        payload['rider_comment'] = comment;
      }

      final client = HeyCabySupabase.client;
      final updated = await client
          .from('ride_ratings')
          .update(payload)
          .eq('ride_request_id', rideRequestId)
          .select('ride_request_id');

      if (updated.isEmpty) {
        await client.from('ride_ratings').insert({
          'ride_request_id': rideRequestId,
          ...payload,
        });
      }

      if (mounted) {
        HapticService.success();
        context.go('/home');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Rating submit error: $e');
        debugPrint('$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failedToSubmitRating)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool get _canSubmit =>
      _rating > 0 &&
      _punctuality > 0 &&
      _cleanliness > 0 &&
      _attitude > 0 &&
      _drivingSafety > 0 &&
      _communication > 0;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.rateYourDriver,
              subtitle: l10n.howWasYourRide,
              icon: Icons.star_rounded,
              onBack: () {
                if (!_isSubmitting) context.go('/home');
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.accentL,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.text.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: colors.accent,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _StarRating(
                    rating: _rating,
                    colors: colors,
                    onRatingChanged: _onOverallRatingChanged,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsetsDirectional.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: colors.text.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Text(
                    l10n.ratingCategorySectionTitle,
                    style: typo.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.ratingCategorySubtitle,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                  const SizedBox(height: 16),
                  _CategoryStarRow(
                    label: l10n.ratingDimensionPunctuality,
                    value: _punctuality,
                    colors: colors,
                    typo: typo,
                    onChanged: (v) => setState(() => _punctuality = v),
                  ),
                  _CategoryStarRow(
                    label: l10n.ratingDimensionCleanliness,
                    value: _cleanliness,
                    colors: colors,
                    typo: typo,
                    onChanged: (v) => setState(() => _cleanliness = v),
                  ),
                  _CategoryStarRow(
                    label: l10n.ratingDimensionAttitude,
                    value: _attitude,
                    colors: colors,
                    typo: typo,
                    onChanged: (v) => setState(() => _attitude = v),
                  ),
                  _CategoryStarRow(
                    label: l10n.ratingDimensionDrivingSafety,
                    value: _drivingSafety,
                    colors: colors,
                    typo: typo,
                    onChanged: (v) => setState(() => _drivingSafety = v),
                  ),
                  _CategoryStarRow(
                    label: l10n.ratingDimensionCommunication,
                    value: _communication,
                    colors: colors,
                    typo: typo,
                    onChanged: (v) => setState(() => _communication = v),
                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.whatDidYouLike,
                    style: typo.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getQuickFeedback(l10n).map((tag) {
                      final isSelected = _selectedFeedback.contains(tag);
                      return _FeedbackChip(
                        label: tag,
                        isSelected: isSelected,
                        colors: colors,
                        typo: typo,
                        onTap: () {
                          HapticService.lightTap();
                          setState(() {
                            if (isSelected) {
                              _selectedFeedback.remove(tag);
                            } else {
                              _selectedFeedback.add(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.additionalFeedback,
                    style: typo.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _feedbackController,
                    style: typo.bodyMedium.copyWith(color: colors.text),
                    maxLines: 4,
                    maxLength: 5000,
                    decoration: InputDecoration(
                      hintText: l10n.tellUsMore,
                      hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
                      filled: true,
                      fillColor: colors.card,
                      contentPadding: const EdgeInsetsDirectional.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.accent, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: colors.card,
                boxShadow: [
                  BoxShadow(
                    color: colors.text.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: !_canSubmit || _isSubmitting ? null : _submitRating,
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: colors.onAccent,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              l10n.submitRating,
                              style: typo.labelLarge.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => context.go('/home'),
                    child: Text(
                      l10n.skip,
                      style: typo.labelLarge.copyWith(
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
    );
  }
}

class _CategoryStarRow extends StatelessWidget {
  final String label;
  final int value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<int> onChanged;

  const _CategoryStarRow({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typo.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (index) {
              final star = index + 1;
              return GestureDetector(
                onTap: () {
                  HapticService.selectionClick();
                  onChanged(star);
                },
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: AnimatedScale(
                    scale: value >= star ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      value >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: value >= star ? colors.warning : colors.border,
                      size: 28,
                    ),
                  ),
                ),
              );
            }),
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
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: AnimatedScale(
              scale: filled ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey(filled),
                  color: filled ? colors.warning : colors.border,
                  size: 48,
                ),
              ),
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: 60 * index))
            .fadeIn(duration: 300.ms)
            .scale(begin: const Offset(0.7, 0.7), curve: Curves.easeOutBack);
      }),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _FeedbackChip({
    required this.label,
    required this.isSelected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentL : colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: typo.bodyMedium.copyWith(
            color: isSelected ? colors.accent : colors.text,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
