import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_state_provider.dart';
import '../services/driver_session_bootstrap.dart';

const _kMessagesNl = [
  'Jij bepaalt je prijs.\nJij houdt alles.',
  'Geen commissie.\nNooit.',
  'Chauffeurs verdienen €1.600+ meer per maand.',
  'Jouw auto. Jouw uren. Jouw inkomen.',
  'Jij rijdt — wij zorgen voor de rest.',
];

const _kMessagesEn = [
  'You set your price.\nYou keep everything.',
  'Zero commission.\nEver.',
  'Drivers earn €1,600+ more every month.',
  'Your car. Your hours. Your income.',
  'You drive — we handle the rest.',
];

const _kTotalMs = 5000;

/// 5-second HeyCaby driver splash — logo, localized message, fade to auth/home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _msgFade;
  late final Animation<double> _exitFade;
  late final int _messageIndex;
  late final bool _useDutch;

  @override
  void initState() {
    super.initState();
    final lang = ui.PlatformDispatcher.instance.locale.languageCode;
    _useDutch = lang == 'nl';
    _messageIndex = Random().nextInt(5);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTotalMs),
    );

    _logoFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );

    _msgFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.30, 0.50, curve: Curves.easeOut),
    );

    _exitFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.70, 1.00, curve: Curves.easeIn),
    );

    _ctrl.forward().then((_) => _navigate());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final session = HeyCabySupabase.client.auth.currentSession;
    if (session == null) {
      context.go('/login');
      return;
    }
    final driverId = await bootstrapDriverSessionAfterAuth(ref);
    ref.read(driverStateProvider.notifier).setUser(session.user.id, driverId);
    if (!mounted) return;
    context.go('/driver');
  }

  String get _messageText =>
      _useDutch ? _kMessagesNl[_messageIndex] : _kMessagesEn[_messageIndex];

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final exitOpacity = (1.0 - _exitFade.value).clamp(0.0, 1.0);
          final logoScale = 0.8 + 0.2 * _logoFade.value.clamp(0.0, 1.0);

          return Opacity(
            opacity: exitOpacity,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: logoScale,
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  'C',
                                  style: typo.displayMedium.copyWith(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                    color: colors.card,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'hey',
                                    style: typo.bodyLarge.copyWith(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w300,
                                      color: colors.text,
                                      letterSpacing: -0.5,
                                      height: 1.0,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'caby',
                                    style: typo.displayMedium.copyWith(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: colors.accent,
                                      letterSpacing: -0.5,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
                    Opacity(
                      opacity: _msgFade.value,
                      child: Text(
                        _messageText,
                        textAlign: TextAlign.center,
                        style: typo.displaySmall.copyWith(
                          color: colors.text,
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
