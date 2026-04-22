import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_state_provider.dart';

class RateRiderScreen extends ConsumerStatefulWidget {
  const RateRiderScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RateRiderScreen> createState() => _RateRiderScreenState();
}

class _RateRiderScreenState extends ConsumerState<RateRiderScreen> {
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _loading = false;
  static const int _maxCommentLength = 100;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars < 1) {
      HapticService.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }
    HapticService.mediumTap();
    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'ride_request_id': widget.rideId,
        'driver_rating_of_rider': _stars,
        'driver_rated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final comment = _commentController.text.trim();
      if (comment.isNotEmpty) {
        payload['rider_comment'] = comment;
      }
      await ref.read(driverApiProvider).rateRider(payload: payload);
      HapticService.success();
      ref.read(driverStateProvider.notifier).clearActiveRide();
      if (!mounted) return;
      context.go('/driver');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for rating!')),
      );
    } catch (e) {
      HapticService.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _skip() {
    HapticService.lightTap();
    ref.read(driverStateProvider.notifier).clearActiveRide();
    context.go('/driver');
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text('Rate rider', style: typo.titleMedium.copyWith(color: colors.text)),
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.text),
          onPressed: _skip,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'How was your rider?',
                style: typo.headingMedium.copyWith(color: colors.text),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 24),

              // Animated star row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  final filled = _stars >= star;
                  return GestureDetector(
                    onTap: () {
                      HapticService.selectionClick();
                      setState(() => _stars = star);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedScale(
                        scale: filled ? 1.25 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_outline_rounded,
                            key: ValueKey(filled),
                            size: 40,
                            color: filled ? colors.accent : colors.border,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

              const SizedBox(height: 24),
              TextField(
                controller: _commentController,
                maxLength: _maxCommentLength,
                maxLines: 3,
                style: typo.bodyMedium.copyWith(color: colors.text),
                decoration: InputDecoration(
                  hintText: 'Optional note',
                  hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
                  filled: true,
                  fillColor: colors.card,
                  counterText: '',
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
                onChanged: (_) => setState(() {}),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 8),
              Text(
                '${_commentController.text.length}/$_maxCommentLength',
                style: typo.labelSmall.copyWith(color: colors.textSoft),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                      disabledBackgroundColor: colors.border,
                      disabledForegroundColor: colors.textMid,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                child: _loading
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: colors.onAccent,
                          strokeWidth: 2.5,
                        ),
                      )
                      : Text(
                          'Submit',
                          style: typo.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : _skip,
                child: Text(
                  'Skip',
                  style: typo.labelLarge.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
