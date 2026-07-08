import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'home_greeting_header.dart';

/// Map overlay: greeting (left), notifications (right), locate (bottom-right).
class HomeMapOverlay extends ConsumerWidget {
  const HomeMapOverlay({
    super.key,
    required this.colors,
    required this.typo,
    required this.onLocate,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          top: top + 8,
          left: 16,
          right: 72,
          child: const HomeGreetingHeader(),
        ),
        Positioned(
          top: top + 8,
          right: 16,
          child: _MapCircleButton(
            colors: colors,
            icon: Icons.notifications_outlined,
            onTap: () => _showRiderNotifications(context, ref),
          ),
        ),
        Positioned(
          right: 16,
          bottom: MediaQuery.sizeOf(context).height * 0.42,
          child: _MapCircleButton(
            colors: colors,
            icon: Icons.my_location_rounded,
            iconColor: colors.accent,
            onTap: onLocate,
          ),
        ),
      ],
    );
  }

  Future<void> _showRiderNotifications(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final identity = await ref.read(riderIdentityProvider.future);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _RiderNotificationsSheet(
        colors: colors,
        typo: typo,
        title: l10n.accountManageNotifications,
        emptyLabel: 'No notifications yet.',
        riderIdentityId: identity.identityId,
      ),
    );
  }
}

class _RiderNotificationsSheet extends ConsumerWidget {
  const _RiderNotificationsSheet({
    required this.colors,
    required this.typo,
    required this.title,
    required this.emptyLabel,
    required this.riderIdentityId,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String emptyLabel;
  final String? riderIdentityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: typo.headingSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: colors.textMid),
                ),
              ],
            ),
            if (riderIdentityId != null && riderIdentityId!.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 6,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await ref.read(riderApiProvider).clearReadNotifications(
                              riderIdentityId: riderIdentityId!,
                            );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(
                        'Clear read',
                        style: typo.labelMedium.copyWith(
                          color: colors.textMid,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(riderApiProvider)
                            .markAllNotificationsRead(
                              riderIdentityId: riderIdentityId!,
                            );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(
                        'Mark all read',
                        style: typo.labelMedium.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: riderIdentityId == null || riderIdentityId!.isEmpty
                  ? _NotificationsEmpty(
                      colors: colors,
                      typo: typo,
                      label: emptyLabel,
                    )
                  : FutureBuilder<List<RiderNotificationItem>>(
                      future: ref.read(riderApiProvider).getNotifications(
                            riderIdentityId: riderIdentityId!,
                            unreadOnly: false,
                            limit: 40,
                          ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: colors.accent,
                            ),
                          );
                        }
                        final items = snapshot.data ?? const [];
                        if (items.isEmpty) {
                          return _NotificationsEmpty(
                            colors: colors,
                            typo: typo,
                            label: emptyLabel,
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: colors.border.withValues(alpha: 0.55),
                          ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _NotificationTile(
                              colors: colors,
                              typo: typo,
                              item: item,
                              onTap: () async {
                                if (item.isUnread) {
                                  await ref
                                      .read(riderApiProvider)
                                      .markNotificationRead(
                                        riderIdentityId: riderIdentityId!,
                                        notificationId: item.id,
                                      );
                                }
                                if (!context.mounted) return;
                                await showHeyCabyAcknowledgeSheet(
                                  context,
                                  colors: colors,
                                  typography: typo,
                                  title: item.title,
                                  message: item.body,
                                  actionLabel: 'OK',
                                  icon: Icons.notifications_rounded,
                                  barrierDismissible: true,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty({
    required this.colors,
    required this.typo,
    required this.label,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              color: colors.textSoft, size: 34),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.colors,
    required this.typo,
    required this.item,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final RiderNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: item.isUnread
              ? colors.accent.withValues(alpha: 0.14)
              : colors.bgAlt,
          shape: BoxShape.circle,
        ),
        child: Icon(
          item.isUnread
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          color: item.isUnread ? colors.accent : colors.textSoft,
          size: 20,
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: typo.bodyLarge.copyWith(
          color: colors.text,
          fontWeight: item.isUnread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        item.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: typo.bodySmall.copyWith(
          color: colors.textMid,
          height: 1.35,
        ),
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.colors,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final HeyCabyColorTokens colors;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: colors.text.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: iconColor ?? colors.text, size: 22),
        ),
      ),
    );
  }
}
