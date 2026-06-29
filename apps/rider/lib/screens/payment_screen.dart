import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/booking_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/booking/booking_flow_screen_header.dart';
import '../widgets/primary_cancel_row.dart';

class PaymentMethod {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color iconColor;

  const PaymentMethod({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.iconColor,
  });
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    this.returnToSummaryAfterSave = false,
  });

  /// When opened from trip summary (Edit), Next returns to summary without
  /// stacking another `/summary` route.
  final bool returnToSummaryAfterSave;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final List<String> _selectedMethods = [];
  final _nameController = TextEditingController();

  List<PaymentMethod> _buildMethods(AppLocalizations l10n, HeyCabyColorTokens colors) => [
    PaymentMethod(
      id: 'cash',
      label: l10n.cash,
      description: l10n.cashSubtitle,
      icon: Icons.payments_outlined,
      iconColor: colors.success,
    ),
    PaymentMethod(
      id: 'pin',
      label: l10n.pin,
      description: l10n.pinSubtitle,
      icon: Icons.credit_card_outlined,
      iconColor: colors.accent,
    ),
    PaymentMethod(
      id: 'tikkie',
      label: l10n.tikkie,
      description: l10n.tikkieSubtitle,
      icon: Icons.send_outlined,
      iconColor: colors.warning,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final booking = ref.read(bookingProvider);
    if (booking.pickupContactName != null &&
        booking.pickupContactName!.trim().isNotEmpty) {
      _nameController.text = booking.pickupContactName!;
    }
    _selectedMethods.addAll(booking.paymentMethods);
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedFromProfile());
  }

  Future<void> _seedFromProfile() async {
    if (!mounted) return;
    final booking = ref.read(bookingProvider);
    if (_nameController.text.trim().isEmpty) {
      if (booking.pickupContactName != null &&
          booking.pickupContactName!.trim().isNotEmpty) {
        setState(() => _nameController.text = booking.pickupContactName!);
      } else {
        final identity = await ref.read(riderIdentityProvider.future);
        var name = (identity.bookingName ?? '').trim();
        if (name.isEmpty) {
          final settings = await ref.read(settingsProvider.future);
          name = (settings.userName ?? '').trim();
        }
        if (name.isNotEmpty && mounted) {
          setState(() => _nameController.text = name);
          ref.read(bookingProvider.notifier).setPickupContactName(name);
        }
      }
    }
    if (_selectedMethods.isEmpty && mounted) {
      final identity = await ref.read(riderIdentityProvider.future);
      if (identity.preferredPaymentMethods.isNotEmpty) {
        setState(() {
          _selectedMethods
            ..clear()
            ..addAll(identity.preferredPaymentMethods);
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleMethod(String id) {
    setState(() {
      if (_selectedMethods.contains(id)) {
        _selectedMethods.remove(id);
      } else {
        _selectedMethods.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final mq = MediaQuery.of(context);
    final footerReserve = HeyCabySpacing.component +
        52 +
        math.max(HeyCabySpacing.screenEdge, mq.padding.bottom) +
        HeyCabySpacing.element;
    final methods = _buildMethods(l10n, colors);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.howWillYouPay,
              icon: Icons.payments_outlined,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  HeyCabySpacing.screenEdge,
                  4,
                  HeyCabySpacing.screenEdge,
                  HeyCabySpacing.sectionMedium + footerReserve,
                ),
                children: [
                    Text(
                      l10n.namePlaceholder,
                      style: typo.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: HeyCabySpacing.component),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.85),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.text.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameController,
                            maxLength: 200,
                            style: typo.bodyLarge.copyWith(
                              color: colors.text,
                              height: 1.35,
                            ),
                            cursorColor: colors.accent,
                            decoration: InputDecoration(
                              hintText: l10n.yourName,
                              hintStyle: typo.bodyLarge.copyWith(
                                color: colors.textSoft,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                                18,
                                16,
                                18,
                                12,
                              ),
                            ),
                            onChanged: (v) => ref
                                .read(bookingProvider.notifier)
                                .setPickupContactName(v),
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              18,
                              0,
                              18,
                              12,
                            ),
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _nameController,
                              builder: (context, value, _) {
                                return Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    '${value.text.length}/200',
                                    style: typo.labelSmall.copyWith(
                                      color: colors.textSoft,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: HeyCabySpacing.section),
                    Text(
                      l10n.selectAllThatApply,
                      style: typo.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: HeyCabySpacing.element),
                    Text(
                      l10n.morePaymentOptionsHint,
                      style: typo.bodyMedium.copyWith(
                        color: colors.textMid,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: HeyCabySpacing.component),
                    _GroupedPaymentMethods(
                      methods: methods,
                      selectedIds: _selectedMethods,
                      colors: colors,
                      typo: typo,
                      onToggle: _toggleMethod,
                    ),
                    SizedBox(height: HeyCabySpacing.section),
                    _CommunityPledge(colors: colors, typo: typo, l10n: l10n),
                  ],
                ),
              ),
              if (_selectedMethods.isNotEmpty)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    HeyCabySpacing.screenEdge,
                    0,
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.element,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.paymentMethodsSelected(
                                _selectedMethods.length,
                              ),
                              style: typo.labelLarge.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                padding: EdgeInsetsDirectional.fromSTEB(
                  HeyCabySpacing.screenEdge,
                  HeyCabySpacing.component,
                  HeyCabySpacing.screenEdge,
                  math.max(HeyCabySpacing.screenEdge, mq.padding.bottom),
                ),
                decoration: BoxDecoration(
                  color: colors.card,
                  border: Border(
                    top: BorderSide(
                      color: colors.border.withValues(alpha: 0.65),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.text.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: PrimaryCancelRow(
                primaryLabel: l10n.next,
                onPrimary: _selectedMethods.isNotEmpty
                    ? () async {
                        final name = _nameController.text.trim();
                        ref
                            .read(bookingProvider.notifier)
                            .setPickupContactName(name);
                        if (name.isNotEmpty) {
                          await ref
                              .read(settingsProvider.notifier)
                              .setUserName(name);
                          await ref
                              .read(riderIdentityProvider.notifier)
                              .saveBookingName(name);
                        }
                        ref
                            .read(bookingProvider.notifier)
                            .setPaymentMethods(_selectedMethods);
                        await ref
                            .read(riderIdentityProvider.notifier)
                            .savePreferredPaymentMethods(_selectedMethods);
                        if (!context.mounted) return;
                        if (widget.returnToSummaryAfterSave) {
                          context.go('/summary');
                        } else {
                          context.push('/summary');
                        }
                      }
                    : null,
                colors: colors,
                typography: typo,
                onCancel: () async {
                  final shouldCancel = await showCancelBookingDialog(
                    context,
                    colors: colors,
                    typography: typo,
                  );
                  if (!context.mounted || !shouldCancel) return;
                  context.go('/home');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS-style inset grouped list: one surface, dividers, row tap + adaptive switch.
class _GroupedPaymentMethods extends StatelessWidget {
  const _GroupedPaymentMethods({
    required this.methods,
    required this.selectedIds,
    required this.colors,
    required this.typo,
    required this.onToggle,
  });

  final List<PaymentMethod> methods;
  final List<String> selectedIds;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.035),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Column(
          children: [
            for (var i = 0; i < methods.length; i++) ...[
              _PaymentMethodRow(
                method: methods[i],
                isSelected: selectedIds.contains(methods[i].id),
                colors: colors,
                typo: typo,
                onToggle: () => onToggle(methods[i].id),
              ),
              if (i < methods.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 76,
                  endIndent: HeyCabySpacing.screenEdge,
                  color: colors.border.withValues(alpha: 0.65),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.method,
    required this.isSelected,
    required this.colors,
    required this.typo,
    required this.onToggle,
  });

  final PaymentMethod method;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? colors.accent.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        splashColor: colors.accent.withValues(alpha: 0.08),
        highlightColor: colors.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            16,
            14,
            12,
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? method.iconColor.withValues(alpha: 0.14)
                      : colors.bgAlt.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? method.iconColor.withValues(alpha: 0.35)
                        : colors.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  method.icon,
                  color: isSelected ? method.iconColor : colors.textMid,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method.description,
                      style: typo.bodySmall.copyWith(
                        color: colors.textMid,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isSelected,
                onChanged: (next) {
                  if (next != isSelected) onToggle();
                },
                activeTrackColor: colors.accent,
                activeThumbColor: colors.card,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityPledge extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _CommunityPledge({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.65),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: colors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.driverPayment,
                    style: typo.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.communityPledge,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
