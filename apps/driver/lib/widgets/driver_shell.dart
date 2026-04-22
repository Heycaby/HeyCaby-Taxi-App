import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../l10n/driver_tell_friend_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_locale_provider.dart';
import '../theme/app_icons.dart';
import '../utils/driver_logout.dart';
import 'driver_profile_realtime_listener.dart';
import 'ride_invite_realtime_listener.dart';
import 'driver_notifications_listener.dart';

class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> with WidgetsBindingObserver {
  bool _scheduledDriverBootstrap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // After Veriff in the external browser, refresh compliance when user returns.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(driverComplianceProvider);
      ref.invalidate(driverProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_scheduledDriverBootstrap) {
      _scheduledDriverBootstrap = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(driverDataServiceProvider).bootstrapDriverRow();
        if (!mounted) return;
        ref.invalidate(driverIdProvider);
        ref.invalidate(driverProfileProvider);
      });
    }

    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final location = GoRouterState.of(context).uri.toString();
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    final tellFriendStrings = driverTellFriendStringsFor(locale);

    // Home | Work | Community | Tell a friend | Me
    int currentIndex = 0;
    if (location.startsWith('/driver/work')) {
      currentIndex = 1;
    } else if (location.startsWith('/driver/community')) {
      currentIndex = 2;
    } else if (location.startsWith('/driver/tell-friend')) {
      currentIndex = 3;
    } else if (location.startsWith('/driver/me')) {
      currentIndex = 4;
    }

    return Scaffold(
      backgroundColor: colors.bg,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              ListTile(
                leading: Icon(AppIcons.menuProfile, color: colors.text),
                title: Text(DriverStrings.profile, style: typo.bodyMedium.copyWith(color: colors.text)),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/driver/me');
                },
              ),
              ListTile(
                leading: Icon(AppIcons.navTellFriend, color: colors.text),
                title: Text(
                  tellFriendStrings.navLabel,
                  style: typo.bodyMedium.copyWith(color: colors.text),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/driver/tell-friend');
                },
              ),
              ListTile(
                leading: Icon(AppIcons.menuDocuments, color: colors.text),
                title: Text(DriverStrings.documents, style: typo.bodyMedium.copyWith(color: colors.text)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/driver/documents');
                },
              ),
              ListTile(
                leading: Icon(AppIcons.menuSupport, color: colors.text),
                title: Text(DriverStrings.support, style: typo.bodyMedium.copyWith(color: colors.text)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/driver/support');
                },
              ),
              ListTile(
                leading: Icon(AppIcons.menuSettings, color: colors.text),
                title: Text(DriverStrings.settings, style: typo.bodyMedium.copyWith(color: colors.text)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/driver/preferences');
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(AppIcons.menuLogout, color: colors.error),
                title: Text(DriverStrings.logout, style: typo.bodyMedium.copyWith(color: colors.error)),
                onTap: () async {
                  Navigator.pop(context);
                  await performDriverLogout(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          const DriverProfileRealtimeListener(),
          const RideInviteRealtimeListener(),
          const DriverNotificationsListener(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: AppIcons.navHome,
                  label: DriverStrings.home,
                  isActive: currentIndex == 0,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/driver'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: AppIcons.navWork,
                  label: DriverStrings.work,
                  isActive: currentIndex == 1,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/driver/work'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: AppIcons.navCommunity,
                  label: DriverStrings.community,
                  isActive: currentIndex == 2,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/driver/community'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: AppIcons.navTellFriend,
                  label: tellFriendStrings.navLabel,
                  isActive: currentIndex == 3,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/driver/tell-friend'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: AppIcons.navProfile,
                  label: DriverStrings.me,
                  isActive: currentIndex == 4,
                  colors: colors,
                  typo: typo,
                  onTap: () => context.go('/driver/me'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? colors.accent : colors.textSoft;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: typo.labelSmall.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
