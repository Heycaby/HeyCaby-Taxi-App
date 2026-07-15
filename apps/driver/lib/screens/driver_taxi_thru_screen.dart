import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_taxi_thru_rider_post.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';

class DriverTaxiThruScreen extends ConsumerStatefulWidget {
  const DriverTaxiThruScreen({super.key});

  @override
  ConsumerState<DriverTaxiThruScreen> createState() =>
      _DriverTaxiThruScreenState();
}

class _DriverTaxiThruScreenState extends ConsumerState<DriverTaxiThruScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driverColors = DriverColors.fromTheme(colors);
    final driverTypo = DriverTypography.fromTheme(typo);
    final async = ref.watch(driverTaxiThruRiderPostsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          DriverStrings.taxiThruTitle,
          style: typo.titleLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textMid),
            onPressed: () {
              HapticService.lightTap();
              ref.invalidate(driverTaxiThruRiderPostsProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => _LoadingBody(colors: colors, typo: typo),
          error: (_, __) => _ErrorBody(
            colors: colors,
            typo: typo,
            driverColors: driverColors,
            driverTypo: driverTypo,
            onRetry: () => ref.invalidate(driverTaxiThruRiderPostsProvider),
          ),
          data: (snap) {
            if (!snap.enabled) {
              return _DisabledBody(colors: colors, typo: typo);
            }
            if (snap.posts.isEmpty) {
              return _EmptyBody(colors: colors, typo: typo);
            }
            return _PostsList(
              colors: colors,
              typo: typo,
              driverColors: driverColors,
              driverTypo: driverTypo,
              posts: snap.posts,
              onAccept: _onAcceptPost,
            );
          },
        ),
      ),
    );
  }

  void _onAcceptPost(DriverTaxiThruRiderPost post) {
    HapticService.mediumTap();
    context.push(
      '/driver/ride/new/${post.id}',
      extra: const {'urgent': false},
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: colors.accent,
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.colors,
    required this.typo,
    required this.driverColors,
    required this.driverTypo,
    required this.onRetry,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final DriverColors driverColors;
  final DriverTypography driverTypo;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: colors.textMid, size: 48),
            const SizedBox(height: 16),
            Text(
              DriverStrings.taxiThruLoadError,
              style: typo.bodyMedium.copyWith(color: colors.textMid),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            DriverButton(
              label: DriverStrings.taxiThruRetry,
              onPressed: onRetry,
              colors: driverColors,
              typography: driverTypo,
              variant: DriverButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DisabledBody extends StatelessWidget {
  const _DisabledBody({required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, color: colors.textMid, size: 48),
            const SizedBox(height: 16),
            Text(
              DriverStrings.taxiThruDisabled,
              style: typo.bodyMedium.copyWith(color: colors.textMid),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.colors, required this.typo});

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, color: colors.textMid, size: 48),
            const SizedBox(height: 16),
            Text(
              DriverStrings.taxiThruEmpty,
              style: typo.bodyMedium.copyWith(color: colors.textMid),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostsList extends StatelessWidget {
  const _PostsList({
    required this.colors,
    required this.typo,
    required this.driverColors,
    required this.driverTypo,
    required this.posts,
    required this.onAccept,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final DriverColors driverColors;
  final DriverTypography driverTypo;
  final List<DriverTaxiThruRiderPost> posts;
  final ValueChanged<DriverTaxiThruRiderPost> onAccept;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
          child: _RiderPostCard(
            post: post,
            colors: colors,
            typo: typo,
            driverColors: driverColors,
            driverTypo: driverTypo,
            onAccept: () => onAccept(post),
          ),
        );
      },
    );
  }
}

class _RiderPostCard extends StatelessWidget {
  const _RiderPostCard({
    required this.post,
    required this.colors,
    required this.typo,
    required this.driverColors,
    required this.driverTypo,
    required this.onAccept,
  });

  final DriverTaxiThruRiderPost post;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final DriverColors driverColors;
  final DriverTypography driverTypo;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.22),
          width: 1.1,
        ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TAXI TERUG',
                  style: typo.labelSmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              if (post.driverToPickupKm != null)
                Text(
                  post.driverDistanceLabel,
                  style: typo.labelSmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _RouteRow(
            colors: colors,
            typo: typo,
            icon: Icons.my_location_rounded,
            iconColor: colors.accent,
            label: post.pickupLabel,
          ),
          const SizedBox(height: 8),
          _RouteRow(
            colors: colors,
            typo: typo,
            icon: Icons.location_on_rounded,
            iconColor: colors.success,
            label: post.destinationLabel,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (post.offeredFare != null)
                Text(
                  post.fareLabel,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              if (post.estimatedDistanceKm != null) ...[
                const SizedBox(width: 12),
                Text(
                  post.distanceLabel,
                  style: typo.bodySmall.copyWith(color: colors.textMid),
                ),
              ],
              if (post.estimatedDurationMin != null) ...[
                const SizedBox(width: 8),
                Text(
                  '· ${post.durationLabel}',
                  style: typo.bodySmall.copyWith(color: colors.textMid),
                ),
              ],
              const Spacer(),
              DriverButton(
                label: DriverStrings.taxiThruAccept,
                onPressed: onAccept,
                colors: driverColors,
                typography: driverTypo,
                size: DriverButtonSize.sm,
                expanded: false,
              ),
            ],
          ),
          if (post.pickupContactName != null &&
              post.pickupContactName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.pickupContactName!,
              style: typo.labelSmall.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: typo.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
