import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../providers/booking_provider.dart';
import '../providers/rider_profile_completeness_provider.dart';
import '../providers/settings_provider.dart';
import '../services/rider_device_permission_snapshot.dart';
import '../services/rider_permission_backend_sync.dart';
import '../services/sound_service.dart';
import '../utils/rider_account_deletion.dart';
import '../widgets/email_modal.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _scrollController = ScrollController();
  final GlobalKey _profileSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fromOnboarding =
          GoRouterState.of(context).uri.queryParameters['fromOnboarding'] ==
              'true';

      final settings = ref.read(settingsProvider).valueOrNull;
      if (settings?.userName != null) {
        _nameController.text = settings!.userName!;
      }
      _syncPermissionsFromDevice();

      if (fromOnboarding) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _nameFocus.requestFocus();
          final box = _profileSectionKey.currentContext;
          if (box != null) {
            Scrollable.ensureVisible(
              box,
              alignment: 0.12,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPermissionsFromDevice();
    }
  }

  Future<void> _syncPermissionsFromDevice() async {
    final snap = await RiderDevicePermissionSnapshot.read();
    await RiderPermissionBackendSync.push(
      locationGranted: snap.locationGranted,
      notificationsGranted: snap.notificationsGranted,
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    await ref.read(settingsProvider.notifier).setNotificationsEnabled(value);
    await _playToggleFeedback();
    bool osEnabled = false;
    if (value) {
      final status = await Permission.notification.request();
      if (!status.isGranted && !status.isProvisional) {
        await openAppSettings();
      } else {
        osEnabled = true;
        try {
          await HeyCabyFcmRegistration.sync(appRole: 'rider');
        } catch (_) {
          // Keep toggle UX responsive even if token sync fails.
        }
      }
    }
    await _syncPermissionsFromDevice();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await _showToggleResultModal(
      title: l10n.accountNotificationsNeededBody,
      message: value
          ? (osEnabled
              ? 'Notifications are enabled. You can receive ride updates and alerts.'
              : 'Notifications are turned on in-app, but iOS permission is still off. Enable it in Settings to receive alerts.')
          : 'Notifications are turned off for this app preference.',
    );
  }

  Future<void> _toggleLocation(bool value) async {
    await ref.read(settingsProvider.notifier).setLocationEnabled(value);
    await _playToggleFeedback();
    bool osEnabled = false;
    if (value) {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted && status != PermissionStatus.limited) {
        await openAppSettings();
      } else {
        osEnabled = true;
      }
    }
    await _syncPermissionsFromDevice();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await _showToggleResultModal(
      title: l10n.accountLocationNeededBody,
      message: value
          ? (osEnabled
              ? 'Location is enabled. HeyCaby can use your location for pickup and nearby driver matching.'
              : 'Location is turned on in-app, but iOS permission is still off. Enable it in Settings to use booking features.')
          : 'Location is turned off for this app preference.',
    );
  }

  Future<void> _showToggleResultModal({
    required String title,
    required String message,
  }) async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: colors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: typo.bodyMedium.copyWith(
                  color: colors.textMid,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.dialogOk,
                    style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playToggleFeedback() async {
    HapticService.lightTap();
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    try {
      await SoundService().playNotification();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameFocus.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await ref.read(settingsProvider.notifier).setUserName(name);
      await ref.read(riderIdentityProvider.notifier).saveBookingName(name);
      ref.read(bookingProvider.notifier).setPickupContactName(name);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final colors = ref.read(colorsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.nameSavedSuccess, style: TextStyle(color: colors.text)),
            backgroundColor: colors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveNameAndContinue() async {
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.onboardingNameRequired,
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await ref.read(settingsProvider.notifier).setUserName(name);
    await ref.read(riderIdentityProvider.notifier).saveBookingName(name);
    ref.read(bookingProvider.notifier).setPickupContactName(name);
    if (mounted) context.go('/home');
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.logoutConfirmTitle, style: typo.headingMedium.copyWith(color: colors.text)),
        content: Text(l10n.logoutConfirmMessage, style: typo.bodyMedium.copyWith(color: colors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: typo.bodyLarge.copyWith(color: colors.accent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: heyCabyElevatedErrorStyle(colors).merge(
              ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            child: Text(
              l10n.logout,
              style: typo.labelLarge.copyWith(color: colors.onError),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await HeyCabyFcmRegistration.unregisterAll(appRole: 'rider');
      await ref.read(riderIdentityProvider.notifier).clearSession();
      await ref.read(settingsProvider.notifier).clearUserName();
      ref.read(bookingProvider.notifier).reset();
      if (mounted) context.go('/home');
    }
  }

  void _showLanguagePicker(HeyCabyColorTokens colors, HeyCabyTypography typo) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                _DragHandle(colors: colors),
                for (final lang in [('en', 'English'), ('nl', 'Nederlands'), ('ar', 'العربية')])
                  ListTile(
                    title: Text(lang.$2, style: typo.bodyLarge.copyWith(color: colors.text)),
                    trailing: settings?.language == lang.$1
                        ? Icon(Icons.check, color: colors.accent)
                        : null,
                    onTap: () {
                      ref.read(settingsProvider.notifier).setLanguage(lang.$1);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThemePicker(HeyCabyColorTokens colors, HeyCabyTypography typo) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final themes = kThemes.entries.toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                _DragHandle(colors: colors),
                for (final entry in themes)
                  ListTile(
                    title: Text(entry.value.name, style: typo.bodyLarge.copyWith(color: colors.text)),
                    trailing: settings?.theme == entry.key
                        ? Icon(Icons.check, color: colors.accent)
                        : null,
                    onTap: () async {
                      await ref.read(settingsProvider.notifier).setTheme(entry.key);
                      await ref.read(themeProvider.notifier).setTheme(entry.key);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _currentLanguageLabel() {
    final lang = ref.watch(settingsProvider).valueOrNull?.language;
    switch (lang) {
      case 'nl': return 'Nederlands';
      case 'ar': return 'العربية';
      default: return 'English';
    }
  }

  String _currentThemeLabel() {
    final themeId = ref.watch(settingsProvider).valueOrNull?.theme;
    if (themeId != null) {
      final theme = kThemes[migrateThemeId(themeId)];
      if (theme != null) return theme.name;
    }
    return kThemes[kRiderDefaultTheme]?.name ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final fromOnboarding =
        GoRouterState.of(context).uri.queryParameters['fromOnboarding'] ==
            'true';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 32),
          children: [
            _buildHeader(colors, typo, l10n),
            if (fromOnboarding) ...[
              const SizedBox(height: 12),
              _buildOnboardingBanner(colors, typo, l10n),
            ],
            SizedBox(height: fromOnboarding ? 20 : 28),
            _buildProfileSection(colors, typo, l10n, fromOnboarding: fromOnboarding),
            const SizedBox(height: 24),
            _buildSettingsSection(colors, typo, l10n),
            const SizedBox(height: 16),
            _buildActionCard(
              icon: Icons.home_outlined,
              iconBg: colors.accent.withValues(alpha: 0.12),
              iconColor: colors.accent,
              title: l10n.savedAddresses,
              subtitle: l10n.savedAddressesSubtitle,
              colors: colors, typo: typo,
              onTap: () async {
                final identity = await ref.read(riderIdentityProvider.future);
                if (!context.mounted) return;
                if (identity.hasSession && identity.identityId != null) {
                  context.push('/saved-addresses');
                } else {
                  final ok = await showEmailModal(context, ref);
                  if (ok && context.mounted) {
                    context.push('/saved-addresses');
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.star_outline,
              iconBg: colors.warning.withValues(alpha: 0.15),
              iconColor: colors.warning,
              title: l10n.myDrivers,
              subtitle: l10n.favouriteDriversAccountSubtitle,
              colors: colors, typo: typo,
              onTap: () async {
                final identity = await ref.read(riderIdentityProvider.future);
                if (!context.mounted) return;
                if (identity.hasSession && identity.email != null) {
                  context.push('/favorites');
                  return;
                }
                final ok = await showEmailModal(context, ref);
                if (ok && context.mounted) {
                  context.push('/favorites');
                }
              },
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.description_outlined,
              iconBg: colors.accent.withValues(alpha: 0.15),
              iconColor: colors.accent,
              title: l10n.reportARide,
              subtitle: l10n.reportARideSubtitle,
              colors: colors, typo: typo,
              onTap: () => context.push('/report'),
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.chat_bubble_outline,
              iconBg: colors.success.withValues(alpha: 0.15),
              iconColor: colors.success,
              title: l10n.support,
              subtitle: l10n.supportSubtitle,
              colors: colors, typo: typo,
              onTap: () => context.push('/support'),
            ),
            const SizedBox(height: 24),
            _buildNavRow(Icons.help_outline, l10n.faq, colors, typo, () => context.push('/faq')),
            const SizedBox(height: 8),
            _buildNavRow(Icons.article_outlined, l10n.termsOfService, colors, typo, () => context.push('/terms')),
            const SizedBox(height: 8),
            _buildNavRow(Icons.privacy_tip_outlined, l10n.privacyPolicy, colors, typo, () => context.push('/privacy')),
            const SizedBox(height: 24),
            _buildDeleteAccountButton(colors, typo, l10n),
            const SizedBox(height: 12),
            _buildLogoutButton(colors, typo, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingBanner(
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n,
  ) {
    return Material(
      color: colors.accentL,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined, color: colors.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.onboardingProfileBannerMessage,
                style: typo.bodyMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(HeyCabyColorTokens colors, HeyCabyTypography typo, AppLocalizations l10n) {
    final completeness = ref.watch(riderProfileCompletenessProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.account,
                style: typo.displayMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (!completeness.isComplete) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: colors.accentL,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '${completeness.percent}% · ${l10n.homeCompleteProfile}',
                    style: typo.labelMedium.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          style: IconButton.styleFrom(
            backgroundColor: colors.card,
            foregroundColor: colors.text,
          ),
          icon: const Icon(Icons.close_rounded, size: 22),
        ),
      ],
    );
  }

  Widget _buildProfileSection(
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n, {
    required bool fromOnboarding,
  }) {
    final identity = ref.watch(riderIdentityProvider).valueOrNull;
    return Container(
      key: fromOnboarding ? _profileSectionKey : null,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.accent.withValues(alpha: 0.11),
                  colors.card,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.accountProfileHeading,
                  style: typo.headingSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.accountProfileCardSubtitle,
                  style: typo.bodyMedium.copyWith(
                    color: colors.textMid,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.accountBookingNameLabel,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(200),
                  ],
                  onSubmitted: (_) =>
                      fromOnboarding ? _saveNameAndContinue() : _saveName(),
                  style: typo.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.accountBookingNameHint,
                    hintStyle: typo.bodyLarge.copyWith(color: colors.textSoft),
                    filled: true,
                    fillColor: colors.bgAlt,
                    contentPadding: const EdgeInsetsDirectional.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.accent, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.accountBookingNameDescription,
                  style: typo.bodySmall.copyWith(
                    color: colors.textSoft,
                    height: 1.45,
                  ),
                ),
                if (fromOnboarding && identity?.email == null) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.onboardingNextAddEmail,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.border.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.email,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (identity?.email != null)
                  _buildVerifiedEmailCard(colors, typo, l10n, identity!.email!)
                else
                  _buildAddEmailRow(colors, typo, l10n),
                const SizedBox(height: 20),
                Text(
                  l10n.accountProfilePreferencesLabel,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _buildSettingRow(
                  Icons.language_rounded,
                  l10n.language,
                  _currentLanguageLabel(),
                  colors,
                  typo,
                  onTap: () => _showLanguagePicker(colors, typo),
                ),
                const SizedBox(height: 10),
                _buildSettingRow(
                  Icons.palette_outlined,
                  l10n.theme,
                  _currentThemeLabel(),
                  colors,
                  typo,
                  onTap: () => _showThemePicker(colors, typo),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed:
                        fromOnboarding ? _saveNameAndContinue : _saveName,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      fromOnboarding ? l10n.saveAndContinue : l10n.saveButton,
                      style: typo.labelLarge.copyWith(
                        color: colors.onAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedEmailCard(
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n,
    String email,
  ) {
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colors.bgAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.accentL,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.email_rounded, color: colors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: typo.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.verified_rounded, color: colors.success, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.verified,
                      style: typo.labelLarge.copyWith(
                        color: colors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String label, String value, HeyCabyColorTokens colors, HeyCabyTypography typo, {VoidCallback? onTap, Widget? trailing}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: colors.bgAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border.withValues(alpha: 0.75)),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.accent, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: typo.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  style: typo.bodyMedium.copyWith(color: colors.textMid),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              if (trailing != null) trailing,
              if (trailing == null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: colors.textSoft, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddEmailRow(HeyCabyColorTokens colors, HeyCabyTypography typo, AppLocalizations l10n) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final result = await showEmailModal(context, ref);
          if (result && mounted) setState(() {});
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            color: colors.bgAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accentL,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.email_rounded, color: colors.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.addEmail,
                  style: typo.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.add,
                  style: typo.labelLarge.copyWith(
                    color: colors.onAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(HeyCabyColorTokens colors, HeyCabyTypography typo, AppLocalizations l10n) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final locationEnabled = settings?.locationEnabled ?? true;
    final notificationsEnabled = settings?.notificationsEnabled ?? false;
    return Container(
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: colors.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [BoxShadow(color: colors.text.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.accountSettingsHeading, style: typo.bodySmall.copyWith(color: colors.textSoft)),
        const SizedBox(height: 16),
        _buildToggleRow(l10n.accountLocationNeededBody, locationEnabled, colors, typo, _toggleLocation),
        const SizedBox(height: 8),
        _buildLinkRow(l10n.openLocationSettings, colors, typo, () => openAppSettings()),
        const SizedBox(height: 20),
        _buildToggleRow(l10n.accountNotificationsNeededBody, notificationsEnabled, colors, typo, _toggleNotifications),
        const SizedBox(height: 8),
        _buildLinkRow(l10n.openNotificationSettings, colors, typo, () => openAppSettings()),
      ]),
    );
  }

  Widget _buildToggleRow(String title, bool value, HeyCabyColorTokens colors, HeyCabyTypography typo, ValueChanged<bool> onChanged) {
    final l10n = AppLocalizations.of(context);
    return Row(children: [
      Expanded(child: Text(title, style: typo.bodySmall.copyWith(color: colors.text))),
      const SizedBox(width: 12),
      Text(value ? l10n.toggleOn : l10n.toggleOff, style: typo.labelLarge.copyWith(color: value ? colors.accent : colors.textMid, fontWeight: FontWeight.w700)),
      const SizedBox(width: 8),
      Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: colors.accent),
    ]);
  }

  Widget _buildLinkRow(String text, HeyCabyColorTokens colors, HeyCabyTypography typo, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(text, style: typo.bodyMedium.copyWith(color: colors.accent, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.accent, size: 18),
        ]),
      ),
    );
  }

  Widget _buildActionCard({required IconData icon, required Color iconBg, required Color iconColor, required String title, required String subtitle, required HeyCabyColorTokens colors, required HeyCabyTypography typo, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: colors.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 0.5),
          boxShadow: [BoxShadow(color: colors.text.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: typo.bodySmall.copyWith(color: colors.textMid)),
          ])),
          Icon(Icons.chevron_right, color: colors.textSoft, size: 20),
        ]),
      ),
    );
  }

  Widget _buildNavRow(IconData icon, String label, HeyCabyColorTokens colors, HeyCabyTypography typo, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: colors.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Row(children: [
          Icon(icon, color: colors.textMid, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: typo.bodyLarge.copyWith(color: colors.text))),
          Icon(Icons.chevron_right, color: colors.textSoft, size: 20),
        ]),
      ),
    );
  }

  Widget _buildDeleteAccountButton(HeyCabyColorTokens colors, HeyCabyTypography typo, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => performRiderAccountDeletion(context, ref),
      child: Container(
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.error.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_forever_outlined, color: colors.error, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.deleteMyAccount,
              style: typo.bodyLarge.copyWith(color: colors.error, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(HeyCabyColorTokens colors, HeyCabyTypography typo, AppLocalizations l10n) {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.error.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.logout, color: colors.error, size: 20),
          const SizedBox(width: 8),
          Text(l10n.logout, style: typo.bodyLarge.copyWith(color: colors.error, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  final HeyCabyColorTokens colors;
  const _DragHandle({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
    ]);
  }
}
