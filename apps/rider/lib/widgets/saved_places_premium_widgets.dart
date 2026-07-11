import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/saved_addresses_provider.dart';

IconData savedPlaceIconForType(String type) {
  switch (type) {
    case 'work':
      return Icons.work_outline_rounded;
    case 'gym':
      return Icons.fitness_center_rounded;
    case 'home':
      return Icons.home_rounded;
    default:
      return Icons.star_outline_rounded;
  }
}

class SavedPlacesSheetHeader extends StatelessWidget {
  const SavedPlacesSheetHeader({
    super.key,
    required this.colors,
    required this.typo,
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.placeCount,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final int? placeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.accent.withValues(alpha: 0.18),
                  colors.accentL,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.accent.withValues(alpha: 0.22)),
            ),
            child: Icon(Icons.bookmark_rounded, color: colors.accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typo.headingMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: typo.bodySmall.copyWith(
                    color: colors.textSoft,
                    height: 1.35,
                  ),
                ),
                if (placeCount != null && placeCount! > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.accentL,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      AppLocalizations.of(context)
                          .savedPlacesSectionCount(placeCount!),
                      style: typo.labelSmall.copyWith(
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
            onPressed: onClose,
            style: IconButton.styleFrom(
              backgroundColor: colors.card,
              foregroundColor: colors.textMid,
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class SavedPlacesEmptyState extends StatelessWidget {
  const SavedPlacesEmptyState({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onAdd,
    required this.onShortcut,
    this.errorMessage,
    this.onRetry,
    this.showInlineAddButton = true,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onAdd;
  final ValueChanged<String> onShortcut;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showInlineAddButton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsetsDirectional.all(14),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: colors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: typo.bodySmall.copyWith(
                              color: colors.textMid,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: onRetry,
                        icon: Icon(Icons.refresh_rounded, color: colors.accent),
                        label: Text(
                          l10n.tryAgain,
                          style: typo.labelLarge.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
                _HeroIllustration(colors: colors),
                const SizedBox(height: 24),
                Text(
                  l10n.noSavedAddressesYet,
                  textAlign: TextAlign.center,
                  style: typo.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.noSavedAddressesEmptyBody,
                  textAlign: TextAlign.center,
                  style: typo.bodyMedium.copyWith(
                    color: colors.textSoft,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.savedPlacesEmptyStartWith,
                    style: typo.labelLarge.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ShortcutRow(
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                  onShortcut: onShortcut,
                ),
                const SizedBox(height: 20),
                _GhostPreviewRow(colors: colors, typo: typo, l10n: l10n),
                if (showInlineAddButton) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: onAdd,
                      icon: Icon(Icons.add_rounded, color: colors.onAccent),
                      label: Text(
                        l10n.addSavedAddress,
                        style: typo.labelLarge.copyWith(
                          color: colors.onAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.accent.withValues(alpha: 0.16),
                  colors.accent.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: colors.accent,
              size: 34,
            ),
          ),
          PositionedDirectional(
            end: 18,
            bottom: 18,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: Icon(Icons.add_rounded, color: colors.onAccent, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onShortcut,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<String> onShortcut;

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      ('home', l10n.savedAddressLabelHome, Icons.home_rounded),
      ('work', l10n.savedAddressLabelWork, Icons.work_outline_rounded),
      ('gym', l10n.savedAddressLabelGym, Icons.fitness_center_rounded),
    ];

    return Row(
      children: [
        for (var i = 0; i < shortcuts.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ShortcutChip(
              colors: colors,
              typo: typo,
              label: shortcuts[i].$2,
              icon: shortcuts[i].$3,
              onTap: () => onShortcut(shortcuts[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.colors,
    required this.typo,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.accent, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: typo.labelMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostPreviewRow extends StatelessWidget {
  const _GhostPreviewRow({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GhostCard(
          colors: colors,
          typo: typo,
          label: l10n.savedPlacesGhostHome,
          icon: Icons.home_rounded,
        ),
        const SizedBox(height: 8),
        _GhostCard(
          colors: colors,
          typo: typo,
          label: l10n.savedPlacesGhostMom,
          icon: Icons.home_rounded,
        ),
      ],
    );
  }
}

class _GhostCard extends StatelessWidget {
  const _GhostCard({
    required this.colors,
    required this.typo,
    required this.label,
    required this.icon,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Container(
        padding: const EdgeInsetsDirectional.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.border,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.accentL,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: typo.bodyMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(4),
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

class SavedPlacesAddressTile extends StatelessWidget {
  const SavedPlacesAddressTile({
    super.key,
    required this.address,
    required this.colors,
    required this.typo,
    required this.editLabel,
    required this.deleteLabel,
    required this.onBook,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedAddress address;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String editLabel;
  final String deleteLabel;
  final VoidCallback onBook;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBook,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.accent.withValues(alpha: 0.14),
                            colors.accentL,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        savedPlaceIconForType(address.type),
                        color: colors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address.label,
                            style: typo.bodyLarge.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            address.fullAddress,
                            style: typo.bodySmall.copyWith(
                              color: colors.textSoft,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSoft,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.textSoft),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(editLabel),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(deleteLabel),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class SavedPlacesDragHandle extends StatelessWidget {
  const SavedPlacesDragHandle({super.key, required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
