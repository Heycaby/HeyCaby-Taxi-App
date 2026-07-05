import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';

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
            SnackBar(
                content:
                    Text(AppLocalizations.of(context).failedToSubmitRating)),
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
          SnackBar(
              content: Text(AppLocalizations.of(context).failedToSubmitRating)),
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
            _RatingTopBar(
              colors: colors,
              typo: typo,
              title: l10n.rateYourDriver,
              onClose: _isSubmitting ? null : () => context.go('/home'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 28),
                children: [
                  _RatingHeroCard(
                    rating: _rating,
                    colors: colors,
                    typo: typo,
                    title: l10n.howWasYourRide,
                    subtitle: l10n.ratingCategorySubtitle,
                    onRatingChanged: _onOverallRatingChanged,
                  ),
                  const SizedBox(height: 16),
                  _RatingCategoryCard(
                    colors: colors,
                    typo: typo,
                    title: l10n.ratingCategorySectionTitle,
                    children: [
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
                  const SizedBox(height: 16),
                  _FeedbackTagsCard(
                    colors: colors,
                    typo: typo,
                    title: l10n.whatDidYouLike,
                    tags: _getQuickFeedback(l10n),
                    selectedTags: _selectedFeedback,
                    onToggle: (tag) {
                      HapticService.lightTap();
                      setState(() {
                        if (_selectedFeedback.contains(tag)) {
                          _selectedFeedback.remove(tag);
                        } else {
                          _selectedFeedback.add(tag);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _FeedbackTextCard(
                    colors: colors,
                    typo: typo,
                    title: l10n.additionalFeedback,
                    hint: l10n.tellUsMore,
                    controller: _feedbackController,
                  ),
                ],
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
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: colors.text),
            tooltip: title,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: typo.titleLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _RatingHeroCard extends StatelessWidget {
  const _RatingHeroCard({
    required this.rating,
    required this.colors,
    required this.typo,
    required this.title,
    required this.subtitle,
    required this.onRatingChanged,
  });

  final int rating;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String subtitle;
  final ValueChanged<int> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.07),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.warning.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              Icons.star_rounded,
              color: colors.warning,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: typo.titleLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: typo.bodyMedium.copyWith(
              color: colors.textSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _StarRating(
            rating: rating,
            colors: colors,
            onRatingChanged: onRatingChanged,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(
          begin: 0.04,
          end: 0,
          duration: 280.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _RatingCategoryCard extends StatelessWidget {
  const _RatingCategoryCard({
    required this.colors,
    required this.typo,
    required this.title,
    required this.children,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _RatingSurface(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionIcon(colors: colors, icon: Icons.tune_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FeedbackTagsCard extends StatelessWidget {
  const _FeedbackTagsCard({
    required this.colors,
    required this.typo,
    required this.title,
    required this.tags,
    required this.selectedTags,
    required this.onToggle,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final List<String> tags;
  final Set<String> selectedTags;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _RatingSurface(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              final isSelected = selectedTags.contains(tag);
              return _FeedbackChip(
                label: tag,
                isSelected: isSelected,
                colors: colors,
                typo: typo,
                onTap: () => onToggle(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTextCard extends StatelessWidget {
  const _FeedbackTextCard({
    required this.colors,
    required this.typo,
    required this.title,
    required this.hint,
    required this.controller,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _RatingSurface(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            style: typo.bodyMedium.copyWith(color: colors.text),
            maxLines: 4,
            maxLength: 5000,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
              filled: true,
              fillColor: colors.bg,
              contentPadding: const EdgeInsetsDirectional.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: colors.accent, width: 2),
              ),
            ),
          ),
        ],
      ),
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
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        14,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
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
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: isSubmitting ? null : onSkip,
            child: Text(
              skipLabel,
              style: typo.labelLarge.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSurface extends StatelessWidget {
  const _RatingSurface({
    required this.colors,
    required this.child,
  });

  final HeyCabyColorTokens colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.colors, required this.icon});

  final HeyCabyColorTokens colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.accentL,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: colors.accent, size: 22),
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
                      value >= star
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
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
