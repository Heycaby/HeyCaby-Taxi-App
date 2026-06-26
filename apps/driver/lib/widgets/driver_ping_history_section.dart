import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_ping_timeline.dart';
import '../services/driver_ping_timeline_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Ping delivery history (Communication sheet, ride detail, support tickets).
class DriverPingHistorySection extends StatefulWidget {
  const DriverPingHistorySection({
    super.key,
    required this.rideRequestId,
    required this.colors,
    required this.typography,
    this.initiallyExpanded = false,
    this.collapsible = true,
    this.showTopSpacing = true,
  });

  final String rideRequestId;
  final DriverColors colors;
  final DriverTypography typography;

  /// When true, loads timeline on first build (ride detail / support).
  final bool initiallyExpanded;

  /// False = always-visible panel (no collapse chevron).
  final bool collapsible;

  final bool showTopSpacing;

  @override
  State<DriverPingHistorySection> createState() =>
      _DriverPingHistorySectionState();
}

class _DriverPingHistorySectionState extends State<DriverPingHistorySection> {
  late bool _expanded;
  bool _loading = false;
  List<DriverPingTimelineItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded || !widget.collapsible;
    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    final items =
        await const DriverPingTimelineService().fetch(widget.rideRequestId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    if (!widget.collapsible) return;
    final next = !_expanded;
    setState(() => _expanded = next);
    if (next && _items.isEmpty) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showContent = _expanded || !widget.collapsible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTopSpacing) const SizedBox(height: DriverSpacing.md),
        InkWell(
          onTap: widget.collapsible ? _toggle : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DriverSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DriverStrings.communicationPingHistory,
                    style: widget.typography.labelLarge.copyWith(
                      color: widget.colors.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (_loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.colors.textMuted,
                    ),
                  )
                else if (widget.collapsible)
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: widget.colors.textMuted,
                  ),
              ],
            ),
          ),
        ),
        if (showContent) ...[
          if (_items.isEmpty && !_loading)
            Text(
              DriverStrings.pingHistoryEmpty,
              style: widget.typography.bodySmall.copyWith(
                color: widget.colors.textMuted,
              ),
            )
          else
            ..._items.map((item) => _PingHistoryTile(
                  item: item,
                  colors: widget.colors,
                  typography: widget.typography,
                )),
        ],
      ],
    );
  }
}

class _PingHistoryTile extends StatelessWidget {
  const _PingHistoryTile({
    required this.item,
    required this.colors,
    required this.typography,
  });

  final DriverPingTimelineItem item;
  final DriverColors colors;
  final DriverTypography typography;

  String _labelForType(DriverPingType type) {
    switch (type) {
      case DriverPingType.onMyWay:
        return DriverStrings.pingOnMyWay;
      case DriverPingType.outside:
        return DriverStrings.pingOutside;
      case DriverPingType.arrived:
        return DriverStrings.pingArrived;
      case DriverPingType.runningLate:
        return DriverStrings.pingRunningLate;
      case DriverPingType.trafficDelay:
        return DriverStrings.pingTrafficDelay;
      case DriverPingType.cantFindRider:
        return DriverStrings.pingCantFindRider;
      case DriverPingType.thanks:
        return DriverStrings.pingThanks;
    }
  }

  String _deliveryLabel() {
    if (item.wasOpened) return DriverStrings.pingDeliveryOpened;
    if (item.isFullyDelivered) return DriverStrings.pingDeliveryDelivered;
    return DriverStrings.pingDeliverySent;
  }

  Color _deliveryColor() {
    if (item.wasOpened) return colors.success;
    if (item.isFullyDelivered) return colors.warning;
    return colors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(item.sentAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: _deliveryColor()),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _labelForType(item.type),
                        style: typography.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _deliveryLabel(),
                  style: typography.bodySmall.copyWith(
                    color: _deliveryColor(),
                  ),
                ),
                if (item.automatic)
                  Text(
                    DriverStrings.pingAutomaticBadge,
                    style: typography.bodySmall.copyWith(
                      color: colors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
