import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_runtime_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Driver-facing projection of the backend-owned Mollie connection state.
class DriverMollieConnectScreen extends ConsumerStatefulWidget {
  const DriverMollieConnectScreen({super.key});

  @override
  ConsumerState<DriverMollieConnectScreen> createState() =>
      _DriverMollieConnectScreenState();
}

class _DriverMollieConnectScreenState
    extends ConsumerState<DriverMollieConnectScreen>
    with WidgetsBindingObserver {
  static const _service = DriverMollieConnectService();

  DriverMollieConnectResult? _connection;
  bool _loading = true;
  bool _openingMollie = false;
  bool _oauthWasOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _oauthWasOpened) {
      _oauthWasOpened = false;
      _syncStatus();
    }
  }

  Future<void> _loadStatus() async {
    if (mounted) setState(() => _loading = true);
    final result = await _service.status();
    if (!mounted) return;
    setState(() {
      _connection = result;
      _loading = false;
    });
  }

  Future<void> _syncStatus() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await _service.sync();
    if (!mounted) return;
    setState(() {
      _connection = result;
      _loading = false;
    });
    if (!result.ok && result.error == 'mollie_not_connected') {
      await _loadStatus();
    }
  }

  Future<void> _connect() async {
    if (_openingMollie) return;
    setState(() => _openingMollie = true);
    final result = await _service.start();
    if (!mounted) return;
    final uri = Uri.tryParse(result.authorizeUrl ?? '');
    if (!result.ok || uri == null) {
      setState(() {
        _openingMollie = false;
        _connection = result;
      });
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() {
      _openingMollie = false;
      _oauthWasOpened = launched;
    });
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.mollieLaunchFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final config = ref.watch(driverRemoteConfigProvider).valueOrNull;
    final rolloutEnabled = config?.mollieConnectEnabled == true;
    final status = _connection?.status ?? 'not_connected';
    final ready = _connection?.canReceivePrepaidRides == true;
    final connected = status != 'not_connected' && _connection?.ok == true;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.sm,
            DriverSpacing.screenEdge,
            DriverSpacing.xxxl,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/driver/settings'),
                  icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                ),
                Expanded(
                  child: Text(
                    DriverStrings.molliePayments,
                    textAlign: TextAlign.center,
                    style: typography.headlineSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: DriverSpacing.xl),
            Container(
              padding: const EdgeInsets.all(DriverSpacing.xl),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  Text(
                    DriverStrings.mollieConnectTitle,
                    style: typography.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  Text(
                    DriverStrings.mollieConnectBody,
                    style: typography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.xl),
                  _ConnectionStatus(
                    colors: colors,
                    typography: typography,
                    loading: _loading,
                    ready: ready,
                    status: status,
                    hasError: _connection?.ok == false,
                  ),
                  const SizedBox(height: DriverSpacing.xl),
                  if (!rolloutEnabled && !connected)
                    Text(
                      DriverStrings.mollieRolloutUnavailable,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: _loading || _openingMollie || ready
                          ? null
                          : connected
                              ? _syncStatus
                              : _connect,
                      icon: _openingMollie || _loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimary,
                              ),
                            )
                          : Icon(
                              connected
                                  ? Icons.refresh_rounded
                                  : Icons.open_in_new_rounded,
                            ),
                      label: Text(
                        _openingMollie
                            ? DriverStrings.mollieOpening
                            : connected
                                ? DriverStrings.mollieRefreshAction
                                : DriverStrings.mollieConnectAction,
                      ),
                    ),
                    if (connected && !ready) ...[
                      const SizedBox(height: DriverSpacing.sm),
                      TextButton.icon(
                        onPressed: _openingMollie ? null : _connect,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(DriverStrings.mollieConnectAction),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({
    required this.colors,
    required this.typography,
    required this.loading,
    required this.ready,
    required this.status,
    required this.hasError,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final bool ready;
  final String status;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = ready
        ? colors.success
        : hasError || status == 'restricted' || status == 'disabled'
            ? colors.error
            : status == 'not_connected'
                ? colors.textMuted
                : colors.warning;
    final label = loading
        ? DriverStrings.mollieRefreshAction
        : ready
            ? DriverStrings.mollieStatusReady
            : hasError
                ? DriverStrings.mollieLoadFailed
                : switch (status) {
                    'not_connected' => DriverStrings.mollieStatusNotConnected,
                    'restricted' ||
                    'disabled' ||
                    'revoked' =>
                      DriverStrings.mollieStatusRestricted,
                    _ => DriverStrings.mollieStatusPending,
                  };
    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              ready ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: color,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: typography.bodyMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
