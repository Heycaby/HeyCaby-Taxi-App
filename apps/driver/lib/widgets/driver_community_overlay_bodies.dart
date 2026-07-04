import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_bottom_sheet.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_empty_state.dart';

/// Preview row for community notification goldens.
class DriverCommunityNotificationPreviewItem {
  const DriverCommunityNotificationPreviewItem({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.unread,
  });

  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
}

/// Preview row for community search goldens.
class DriverCommunitySearchPreviewItem {
  const DriverCommunitySearchPreviewItem({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class DriverCommunitySearchCategory {
  const DriverCommunitySearchCategory({required this.key, required this.label});

  final String key;
  final String label;
}

const kDriverCommunitySearchCategories = <DriverCommunitySearchCategory>[
  DriverCommunitySearchCategory(
    key: 'all',
    label: DriverStrings.communityCategoryAll,
  ),
  DriverCommunitySearchCategory(
    key: 'traffic',
    label: DriverStrings.communityCategoryTraffic,
  ),
  DriverCommunitySearchCategory(
    key: 'tip',
    label: DriverStrings.communityCategoryTips,
  ),
  DriverCommunitySearchCategory(
    key: 'safety',
    label: DriverStrings.communityCategorySafety,
  ),
  DriverCommunitySearchCategory(
    key: 'help',
    label: DriverStrings.communityCategoryHelp,
  ),
  DriverCommunitySearchCategory(
    key: 'general',
    label: DriverStrings.communityCategoryGeneral,
  ),
];

/// Notifications bottom sheet (presentation).
class DriverCommunityNotificationsSheetBody extends StatelessWidget {
  const DriverCommunityNotificationsSheetBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.error,
    required this.items,
    required this.onMarkAllRead,
    required this.onClearRead,
    required this.onNotificationTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? error;
  final List<DriverCommunityNotificationPreviewItem> items;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearRead;
  final ValueChanged<int> onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return DriverBottomSheet(
      colors: colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DriverSpacing.screenEdge,
              DriverSpacing.lg,
              DriverSpacing.screenEdge,
              DriverSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DriverStrings.communityNotificationsTitle,
                    style: typography.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Wrap(
                  spacing: DriverSpacing.xs,
                  children: [
                    TextButton(
                      onPressed: onClearRead,
                      child: Text(
                        DriverStrings.communityClearRead,
                        style: typography.labelMedium
                            .copyWith(color: colors.textMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: onMarkAllRead,
                      child: Text(
                        DriverStrings.communityMarkAllRead,
                        style: typography.labelMedium
                            .copyWith(color: colors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(DriverSpacing.xl),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : error != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DriverSpacing.screenEdge,
                          0,
                          DriverSpacing.screenEdge,
                          DriverSpacing.lg,
                        ),
                        child: DriverEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: error!,
                          colors: colors,
                          typography: typography,
                        ),
                      )
                    : items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(
                              DriverSpacing.screenEdge,
                              0,
                              DriverSpacing.screenEdge,
                              DriverSpacing.lg,
                            ),
                            child: DriverEmptyState(
                              icon: Icons.notifications_off_outlined,
                              title: DriverStrings.communityNotificationsEmpty,
                              colors: colors,
                              typography: typography,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              DriverSpacing.screenEdge,
                              0,
                              DriverSpacing.screenEdge,
                              DriverSpacing.lg,
                            ),
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: DriverSpacing.sm),
                            itemBuilder: (_, index) {
                              final item = items[index];
                              return DriverCommunityNotificationTile(
                                item: item,
                                colors: colors,
                                typography: typography,
                                onTap: () => onNotificationTap(index),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class DriverCommunityNotificationTile extends StatelessWidget {
  const DriverCommunityNotificationTile({
    super.key,
    required this.item,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final DriverCommunityNotificationPreviewItem item;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: DriverRadius.mdAll,
      child: DriverCard(
        colors: colors,
        padding: const EdgeInsets.all(DriverSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.unread
                    ? colors.primary.withValues(alpha: 0.15)
                    : colors.backgroundAlt,
                borderRadius: DriverRadius.smAll,
              ),
              child: Icon(
                Icons.notifications_rounded,
                color: item.unread ? colors.primary : colors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: DriverSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: typography.bodyMedium.copyWith(
                      color: colors.text,
                      fontWeight:
                          item.unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        typography.bodySmall.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DriverSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.timeLabel,
                  style:
                      typography.labelSmall.copyWith(color: colors.textMuted),
                ),
                if (item.unread)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Notification detail dialog content.
class DriverCommunityNotificationDetailBody extends StatelessWidget {
  const DriverCommunityNotificationDetailBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.title,
    required this.timeLabel,
    required this.body,
    required this.onClose,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String title;
  final String timeLabel;
  final String body;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DriverSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.titleLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            timeLabel,
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: DriverSpacing.md),
          Text(
            body,
            style: typography.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: DriverSpacing.xl),
          DriverButton(
            label: DriverStrings.communityClose,
            colors: colors,
            typography: typography,
            onPressed: onClose,
            size: DriverButtonSize.lg,
          ),
        ],
      ),
    );
  }
}

/// Community search sheet (presentation + optional live search).
class DriverCommunitySearchSheetBody extends StatefulWidget {
  const DriverCommunitySearchSheetBody({
    super.key,
    required this.colors,
    required this.typography,
    this.dataService,
    this.previewResults,
    this.previewLoading = false,
    this.previewEmptyMessage,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverDataService? dataService;
  final List<DriverCommunitySearchPreviewItem>? previewResults;
  final bool previewLoading;
  final String? previewEmptyMessage;

  @override
  State<DriverCommunitySearchSheetBody> createState() =>
      _DriverCommunitySearchSheetBodyState();
}

class _DriverCommunitySearchSheetBodyState
    extends State<DriverCommunitySearchSheetBody> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<CommunityPost> _results = const [];
  bool _loading = false;
  bool _isExpanded = false;
  String _selectedCategory = 'all';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    if (widget.previewResults != null) return;
    final q = value.trim();
    if (!_isExpanded && q.isNotEmpty) {
      setState(() => _isExpanded = true);
    }
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      setState(() => _loading = true);
      final rows = await widget.dataService!.searchCommunityPosts(q, limit: 25);
      if (!mounted) return;
      setState(() {
        _results = rows;
        _loading = false;
      });
    });
  }

  List<CommunityPost> _filteredResults() {
    if (_selectedCategory == 'all') return _results;
    return _results.where((post) {
      final raw = (post.body ?? '').trim();
      final match = RegExp(r'^\[(\w+)\]\s*').firstMatch(raw);
      final extracted = (match?.group(1) ?? 'general').toLowerCase();
      return extracted == _selectedCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = widget.typography;
    final isPreview = widget.previewResults != null;
    final loading = isPreview ? widget.previewLoading : _loading;
    final previewItems = widget.previewResults ?? const [];
    final liveItems = _filteredResults();

    return DriverBottomSheet(
      colors: colors,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.lg,
          DriverSpacing.screenEdge,
          isPreview || _isExpanded ? DriverSpacing.lg : DriverSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              onTap: () => setState(() => _isExpanded = true),
              onChanged: _onQueryChanged,
              style: typography.bodyMedium.copyWith(color: colors.text),
              decoration: InputDecoration(
                hintText: DriverStrings.communitySearchHint,
                hintStyle:
                    typography.bodyMedium.copyWith(color: colors.textMuted),
                prefixIcon:
                    Icon(Icons.search_rounded, color: colors.textSecondary),
                filled: true,
                fillColor: colors.backgroundAlt,
                border: OutlineInputBorder(
                  borderRadius: DriverRadius.smAll,
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: DriverRadius.smAll,
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: DriverRadius.smAll,
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DriverSpacing.md,
                  vertical: DriverSpacing.md,
                ),
              ),
            ),
            if (isPreview || _isExpanded) ...[
              const SizedBox(height: DriverSpacing.lg),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final cat in kDriverCommunitySearchCategories)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: DriverCommunitySearchCategoryChip(
                          label: cat.label,
                          selected: _selectedCategory == cat.key,
                          colors: colors,
                          typography: typography,
                          onTap: () =>
                              setState(() => _selectedCategory = cat.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DriverSpacing.md),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: DriverSpacing.xl),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (isPreview ? previewItems.isEmpty : liveItems.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: DriverSpacing.xl),
                  child: Text(
                    widget.previewEmptyMessage ??
                        (_results.isEmpty
                            ? DriverStrings.communitySearchNoLiveResults
                            : DriverStrings.communitySearchNoCategoryResults),
                    style:
                        typography.bodySmall.copyWith(color: colors.textMuted),
                  ),
                )
              else if (isPreview)
                ...previewItems.map(
                  (item) => DriverCommunitySearchResultRow(
                    title: item.title,
                    subtitle: item.subtitle,
                    colors: colors,
                    typography: typography,
                    onTap: () {},
                  ),
                )
              else
                ...liveItems.map(
                  (post) => DriverCommunitySearchResultRow(
                    title: (post.body ?? '').trim().split('\n').first,
                    subtitle:
                        '${DriverStrings.communityChannelLabel((post.channel ?? 'general').toLowerCase())} • ${post.createdAt?.toLocal()}',
                    colors: colors,
                    typography: typography,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            DriverStrings.communitySearchFoundSnack(
                              (post.channel ?? 'general').toLowerCase(),
                              (post.body ?? '').trim().split('\n').first,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class DriverCommunitySearchCategoryChip extends StatelessWidget {
  const DriverCommunitySearchCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: typography.labelMedium.copyWith(
            color: selected ? colors.onPrimary : colors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class DriverCommunitySearchResultRow extends StatelessWidget {
  const DriverCommunitySearchResultRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: DriverRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DriverSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.forum_rounded, color: colors.primary, size: 20),
            const SizedBox(width: DriverSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.bodyMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style:
                        typography.bodySmall.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Community welcome disclaimer dialog content.
class DriverCommunityDisclaimerBody extends StatelessWidget {
  const DriverCommunityDisclaimerBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.checked,
    required this.onCheckedChanged,
    required this.onContactSupport,
    required this.onJoin,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool checked;
  final ValueChanged<bool> onCheckedChanged;
  final VoidCallback onContactSupport;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DriverSpacing.xl,
            DriverSpacing.xl,
            DriverSpacing.xl,
            0,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: DriverRadius.mdAll,
                ),
                child:
                    Icon(Icons.groups_rounded, color: colors.primary, size: 28),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.communityWelcomeDisclaimerTitle,
                      style: typography.titleLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      DriverStrings.communityWelcomeDisclaimerSubtitle,
                      style: typography.bodySmall
                          .copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DriverSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: DriverSpacing.xl),
            child: DriverCard(
              colors: colors,
              padding: const EdgeInsets.all(DriverSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DriverCommunityDisclaimerRuleSection(
                    icon: Icons.campaign_rounded,
                    title: DriverStrings.communityDisclaimerChannelsTitle,
                    items: const [
                      DriverStrings.communityDisclaimerChannelsItem1,
                      DriverStrings.communityDisclaimerChannelsItem2,
                    ],
                    colors: colors,
                    typography: typography,
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  DriverCommunityDisclaimerRuleSection(
                    icon: Icons.visibility_rounded,
                    title: DriverStrings.communityDisclaimerVisibilityTitle,
                    items: const [
                      DriverStrings.communityDisclaimerVisibilityItem1,
                      DriverStrings.communityDisclaimerVisibilityItem2,
                      DriverStrings.communityDisclaimerVisibilityItem3,
                    ],
                    colors: colors,
                    typography: typography,
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  DriverCommunityDisclaimerRuleSection(
                    icon: Icons.lock_rounded,
                    title: DriverStrings.communityDisclaimerDataTitle,
                    items: const [
                      DriverStrings.communityDisclaimerDataItem1,
                      DriverStrings.communityDisclaimerDataItem2,
                      DriverStrings.communityDisclaimerDataItem3,
                    ],
                    colors: colors,
                    typography: typography,
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  DriverCommunityDisclaimerRuleSection(
                    icon: Icons.shield_rounded,
                    title: DriverStrings.communityDisclaimerConductTitle,
                    items: const [
                      DriverStrings.communityDisclaimerConductItem1,
                      DriverStrings.communityDisclaimerConductItem2,
                      DriverStrings.communityDisclaimerConductItem3,
                    ],
                    colors: colors,
                    typography: typography,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(DriverSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: checked,
                    onChanged: (v) => onCheckedChanged(v ?? false),
                    activeColor: colors.primary,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onCheckedChanged(!checked),
                      child: Text(
                        DriverStrings.communityDisclaimerAgreeCheckbox,
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DriverSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DriverButton(
                      label: DriverStrings.communityContactSupport,
                      colors: colors,
                      typography: typography,
                      variant: DriverButtonVariant.outline,
                      onPressed: onContactSupport,
                    ),
                  ),
                  const SizedBox(width: DriverSpacing.sm),
                  Expanded(
                    child: DriverButton(
                      label: DriverStrings.communityJoin,
                      colors: colors,
                      typography: typography,
                      onPressed: onJoin,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DriverCommunityDisclaimerRuleSection extends StatelessWidget {
  const DriverCommunityDisclaimerRuleSection({
    super.key,
    required this.icon,
    required this.title,
    required this.items,
    required this.colors,
    required this.typography,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colors.primary, size: 20),
            const SizedBox(width: DriverSpacing.sm),
            Text(
              title,
              style: typography.labelMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: DriverSpacing.sm),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ',
                    style: typography.bodySmall
                        .copyWith(color: colors.textSecondary)),
                Expanded(
                  child: Text(
                    item,
                    style: typography.bodySmall
                        .copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String driverCommunityRelativeTime(DateTime? at) {
  if (at == null) return DriverStrings.timeJustNow;
  final d = DateTime.now().difference(at.toLocal());
  if (d.inMinutes < 1) return DriverStrings.timeJustNow;
  if (d.inHours < 1) return DriverStrings.timeMinutesAgo(d.inMinutes);
  if (d.inDays < 1) return DriverStrings.timeHoursAgo(d.inHours);
  return DriverStrings.timeDaysAgo(d.inDays);
}

String driverCommunityTileRelativeTime(DateTime? at) {
  if (at == null) return 'Now';
  final d = DateTime.now().difference(at.toLocal());
  if (d.inMinutes < 1) return 'Now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

Future<void> showDriverCommunityNotificationsSheet(
  BuildContext context,
  WidgetRef ref, {
  required void Function(DriverNotificationItem notification) onNotificationTap,
}) async {
  final themeColors = ref.read(colorsProvider);
  final themeTypo = ref.read(typographyProvider);
  final colors = DriverColors.fromTheme(themeColors);
  final typography = DriverTypography.fromTheme(themeTypo);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final notificationsAsync = ref.watch(communityNotificationsProvider);
        return notificationsAsync.when(
          data: (items) => DriverCommunityNotificationsSheetBody(
            colors: colors,
            typography: typography,
            loading: false,
            error: null,
            items: items
                .map(
                  (n) => DriverCommunityNotificationPreviewItem(
                    title: n.title,
                    body: n.body,
                    timeLabel: driverCommunityTileRelativeTime(n.createdAt),
                    unread: n.isUnread,
                  ),
                )
                .toList(),
            onMarkAllRead: () async {
              await ref.read(driverApiProvider).markAllNotificationsRead();
              ref.invalidate(communityNotificationsProvider);
              ref.invalidate(communityUnreadNotificationsCountProvider);
            },
            onClearRead: () async {
              await ref.read(driverApiProvider).clearReadNotifications();
              ref.invalidate(communityNotificationsProvider);
              ref.invalidate(communityUnreadNotificationsCountProvider);
            },
            onNotificationTap: (index) {
              final notification = items[index];
              if (notification.isUnread) {
                ref
                    .read(driverApiProvider)
                    .markNotificationRead(notification.id);
              }
              ref.invalidate(communityNotificationsProvider);
              ref.invalidate(communityUnreadNotificationsCountProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              onNotificationTap(notification);
            },
          ),
          loading: () => DriverCommunityNotificationsSheetBody(
            colors: colors,
            typography: typography,
            loading: true,
            error: null,
            items: const [],
            onMarkAllRead: () {},
            onClearRead: () {},
            onNotificationTap: (_) {},
          ),
          error: (_, __) => DriverCommunityNotificationsSheetBody(
            colors: colors,
            typography: typography,
            loading: false,
            error: DriverStrings.communityNotificationsLoadFailed,
            items: const [],
            onMarkAllRead: () {},
            onClearRead: () {},
            onNotificationTap: (_) {},
          ),
        );
      },
    ),
  );
}

Future<void> showDriverCommunityNotificationDetailDialog(
  BuildContext context, {
  required DriverNotificationItem notification,
  required DriverColors colors,
  required DriverTypography typography,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: DriverRadius.lgAll),
      child: DriverCommunityNotificationDetailBody(
        colors: colors,
        typography: typography,
        title: notification.title,
        timeLabel: driverCommunityRelativeTime(notification.createdAt),
        body: notification.body,
        onClose: () => Navigator.pop(ctx),
      ),
    ),
  );
}

Future<void> showDriverCommunitySearchSheet(
  BuildContext context,
  WidgetRef ref,
) {
  final colors = DriverColors.fromTheme(ref.read(colorsProvider));
  final typography = DriverTypography.fromTheme(ref.read(typographyProvider));
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DriverCommunitySearchSheetBody(
      colors: colors,
      typography: typography,
      dataService: ref.read(driverDataServiceProvider),
    ),
  );
}

Future<void> showDriverCommunityDisclaimerDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final themeColors = ref.read(colorsProvider);
  final themeTypo = ref.read(typographyProvider);
  final colors = DriverColors.fromTheme(themeColors);
  final typography = DriverTypography.fromTheme(themeTypo);
  var checked = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final maxDialogHeight = MediaQuery.sizeOf(ctx).height * 0.88;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: DriverRadius.lgAll),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: 500, maxHeight: maxDialogHeight),
          child: StatefulBuilder(
            builder: (ctx, setLocal) => DriverCommunityDisclaimerBody(
              colors: colors,
              typography: typography,
              checked: checked,
              onCheckedChanged: (v) => setLocal(() => checked = v),
              onContactSupport: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(DriverStrings.communityOpeningEmailClient),
                  ),
                );
              },
              onJoin: checked
                  ? () async {
                      await ref
                          .read(driverDataServiceProvider)
                          .setCommunityDisclaimerAccepted();
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
            ),
          ),
        ),
      );
    },
  );
}
