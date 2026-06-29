import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';
import '../utils/driver_go_online_runtime_action.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_go_live_body.dart';
import '../widgets/driver_go_online_guidance_sheet.dart';

class GoOnlineScreen extends ConsumerStatefulWidget {
  const GoOnlineScreen({super.key});

  @override
  ConsumerState<GoOnlineScreen> createState() => _GoOnlineScreenState();
}

class _GoOnlineScreenState extends ConsumerState<GoOnlineScreen> {
  bool _loading = false;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  Future<void> _changeStatus(String newStatus) async {
    var position = await requestAndGetLocation();
    if (newStatus == 'available' && position == null) {
      if (!mounted) return;
      HapticService.mediumTap();
      SoundService().playActionBlocked();
      _showLocationRequiredDialog();
      return;
    }
    if (newStatus == 'available') {
      if (!mounted) return;
      final attempt = await attemptDriverGoOnline(
        context: context,
        ref: ref,
        latitude: position!.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      if (attempt.isBlocked) {
        HapticService.mediumTap();
        SoundService().playActionBlocked();
        await showDriverGoOnlineGuidanceSheet(context, ref,
            args: attempt.gateArgs!);
        return;
      }
      if (!attempt.succeeded) return;
      ref
          .read(driverStateProvider.notifier)
          .setStatus(DriverAppState.onlineAvailable);
      SoundService().playStatusOnline();
      context.go('/driver');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(driverApiProvider).setStatus(
            status: newStatus,
            lat: position?.latitude,
            lng: position?.longitude,
          );
      if (newStatus == 'available') {
        ref
            .read(driverStateProvider.notifier)
            .setStatus(DriverAppState.onlineAvailable);
        SoundService().playStatusOnline();
      } else if (newStatus == 'offline') {
        ref
            .read(driverStateProvider.notifier)
            .setStatus(DriverAppState.offline);
        SoundService().playStatusOffline();
      } else if (newStatus == 'on_break') {
        ref
            .read(driverStateProvider.notifier)
            .setStatus(DriverAppState.onBreak);
        SoundService().playStatusOnBreak();
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

  String _errorMessage(dynamic e) {
    if (e is DioException) {
      final res = e.response;
      if (res != null && res.data is Map) {
        final msg = res.data['message'] ?? res.data['error'];
        if (msg != null) return DriverStrings.serverErrorMessage('$msg');
      }
      if (res?.statusCode == 400) {
        return DriverStrings.driverProfileIncompleteForStatus;
      }
    }
    return DriverStrings.failedToUpdateStatus;
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
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverGoLiveBody(
      colors: colors,
      typography: typography,
      loading: _loading,
      onBack: _handleBack,
      onGoOnline: () => _changeStatus('available'),
      onBreak: () => _changeStatus('on_break'),
      onOffline: () => _changeStatus('offline'),
    );
  }
}
