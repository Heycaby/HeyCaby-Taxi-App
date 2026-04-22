import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/location_service.dart';
import '../services/driver_platform_fee_gate.dart';
import '../services/sound_service.dart';
import '../utils/driver_go_online_policy.dart';

class GoOnlineScreen extends ConsumerStatefulWidget {
  const GoOnlineScreen({super.key});

  @override
  ConsumerState<GoOnlineScreen> createState() => _GoOnlineScreenState();
}

class _GoOnlineScreenState extends ConsumerState<GoOnlineScreen> {
  bool _loading = false;

  Future<void> _changeStatus(String newStatus) async {
    var position = await requestAndGetLocation();
    if (newStatus == 'available' && position == null) {
      if (!mounted) return;
      _showLocationRequiredDialog();
      return;
    }
    if (newStatus == 'available') {
      final compliance = await ref.read(driverComplianceProvider.future);
      final isReviewAccount =
          HeyCabySupabase.client.auth.currentUser?.userMetadata?['review_account'] ==
              true;
      if (!driverMayGoOnline(compliance, isReviewAccount: isReviewAccount)) {
        if (!mounted) return;
        _showBijnaKlaarModal();
        return;
      }
      final feeOk = await ensureDriverPlatformFeeAllowsOnline(context, ref);
      if (!feeOk) return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(driverApiProvider).setStatus(
            status: newStatus,
            lat: position?.latitude,
            lng: position?.longitude,
          );
      if (newStatus == 'available') {
        ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onlineAvailable);
        SoundService().playNotification();
      } else if (newStatus == 'offline') {
        ref.read(driverStateProvider.notifier).setStatus(DriverAppState.offline);
        SoundService().playNotification();
      } else if (newStatus == 'on_break') {
        ref.read(driverStateProvider.notifier).setStatus(DriverAppState.onBreak);
      }
      if (!mounted) return;
      context.go('/driver');
    } catch (e) {
      if (!mounted) return;
      final msg = _errorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showBijnaKlaarModal() {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Animated lock → open icon
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_open_rounded, size: 34, color: colors.accent),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Bijna klaar om te rijden 🚀',
              textAlign: TextAlign.center,
              style: typo.headingMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Voltooi je verificatie om online te gaan. Het duurt minder dan 10 minuten en je hoeft het maar één keer te doen.',
              textAlign: TextAlign.center,
              style: typo.bodyMedium.copyWith(
                color: colors.textMid,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/driver/me');
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Nu beginnen →',
                style: typo.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Je kunt de app al verkennen terwijl we je documenten beoordelen.',
              textAlign: TextAlign.center,
              style: typo.bodySmall.copyWith(color: colors.textSoft),
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(dynamic e) {
    if (e is DioException) {
      final res = e.response;
      if (res != null && res.data is Map) {
        final msg = res.data['message'] ?? res.data['error'];
        if (msg != null) return 'Server: $msg';
      }
      if (res?.statusCode == 400) {
        return 'Server rejected request. Check that your driver profile is complete.';
      }
    }
    return 'Failed to update status. Please try again.';
  }

  void _showLocationRequiredDialog() {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_off, color: colors.textSoft),
            const SizedBox(width: 12),
            Text(DriverStrings.locationRequired, style: typo.titleMedium),
          ],
        ),
        content: Text(
          DriverStrings.locationRequiredMessage,
          style: typo.bodyMedium.copyWith(color: colors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(DriverStrings.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            child: Text(DriverStrings.enableLocation),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final pos = await requestAndGetLocation();
              if (pos != null && mounted) _changeStatus('available');
            },
            child: Text(DriverStrings.tryAgain),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go online'),
        leading: _loading
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/driver'),
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Change your status',
                style: typo.titleMedium.copyWith(color: colors.textMid),
              ),
              const SizedBox(height: 24),
              _StatusCard(
                icon: Icons.check_circle,
                label: 'Go Online',
                subtitle: 'Accept ride requests',
                color: colors.accent,
                onTap: _loading ? null : () => _changeStatus('available'),
                colors: colors,
                typo: typo,
              ),
              const SizedBox(height: 12),
              _StatusCard(
                icon: Icons.free_breakfast,
                label: 'Take a break',
                subtitle: 'Pause requests',
                color: colors.warning,
                onTap: _loading ? null : () => _changeStatus('on_break'),
                colors: colors,
                typo: typo,
              ),
              const SizedBox(height: 12),
              _StatusCard(
                icon: Icons.power_off,
                label: 'End shift',
                subtitle: 'Go offline',
                color: colors.error,
                onTap: _loading ? null : () => _changeStatus('offline'),
                colors: colors,
                typo: typo,
              ),
              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: typo.titleMedium.copyWith(color: colors.text),
                    ),
                    Text(
                      subtitle,
                      style: typo.bodySmall.copyWith(color: colors.textSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
