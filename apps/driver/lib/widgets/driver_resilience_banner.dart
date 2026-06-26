import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_connectivity_provider.dart';
import '../providers/driver_gps_health_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_connectivity_status.dart';
import '../services/location_service.dart';

/// Top-of-screen banner for offline / GPS loss (Program 3E).
class DriverResilienceBanner extends ConsumerWidget {
  const DriverResilienceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(driverConnectivityProvider);
    final gpsLost = !ref.watch(driverGpsHealthProvider) &&
        shouldTrackDriverLocation(ref.watch(driverStateProvider).appState);
    final top = MediaQuery.paddingOf(context).top;

    final offline = connectivity == DriverConnectivityStatus.offline;
    if (!offline && !gpsLost) return const SizedBox.shrink();

    final colors = ref.watch(colorsProvider);
    final message = offline
        ? DriverStrings.connectivityOfflineBanner
        : DriverStrings.gpsLostBanner;
    final icon = offline ? Icons.cloud_off_rounded : Icons.gps_off_rounded;
    final bg = offline
        ? colors.error.withValues(alpha: 0.92)
        : colors.warning.withValues(alpha: 0.92);

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: offline || gpsLost ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Material(
          color: bg,
          elevation: 4,
          child: InkWell(
            onTap: offline
                ? () => ref.read(driverConnectivityProvider.notifier).refresh()
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, color: colors.onAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: colors.onAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (offline)
                    Text(
                      DriverStrings.connectivityRetry,
                      style: TextStyle(
                        color: colors.onAccent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
