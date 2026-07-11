import 'package:heycaby_api/heycaby_api.dart';

/// One row in the ping delivery lifecycle for support / driver transparency.
class DriverPingTimelineItem {
  const DriverPingTimelineItem({
    required this.type,
    required this.sentAt,
    this.deliveredAt,
    this.openedAt,
    this.automatic = false,
  });

  final DriverPingType type;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final bool automatic;

  bool get isFullyDelivered => deliveredAt != null;
  bool get wasOpened => openedAt != null;
}

/// Groups flat audit rows into timeline items (newest first).
List<DriverPingTimelineItem> groupPingTimelineRows(
  List<Map<String, dynamic>> rows,
) {
  final byKind = <String, _PingAccumulator>{};

  for (final row in rows) {
    final event = (row['event'] as String? ?? '').trim();
    if (!event.startsWith('driver.ping_')) continue;

    final occurredRaw = row['occurred_at'] as String?;
    final occurredAt =
        occurredRaw == null ? null : DateTime.tryParse(occurredRaw)?.toUtc();
    if (occurredAt == null) continue;

    final metadata = row['metadata'];
    final meta = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : const <String, dynamic>{};

    String baseKind;
    String suffix;
    if (event.endsWith('.delivered')) {
      baseKind = event.replaceFirst('.delivered', '');
      suffix = 'delivered';
    } else if (event.endsWith('.opened')) {
      baseKind = event.replaceFirst('.opened', '');
      suffix = 'opened';
    } else {
      baseKind = event;
      suffix = 'sent';
    }

    final apiKind = baseKind.replaceFirst('driver.ping_', '');
    final type = DriverPingType.tryParse(apiKind);
    if (type == null) continue;

    final acc = byKind.putIfAbsent(type.apiKind, () => _PingAccumulator(type));
    switch (suffix) {
      case 'sent':
        acc.sentAt ??= occurredAt;
        acc.automatic = acc.automatic || (meta['automatic'] as bool? ?? false);
      case 'delivered':
        acc.deliveredAt ??= occurredAt;
      case 'opened':
        acc.openedAt ??= occurredAt;
    }
  }

  final items = byKind.values
      .where((a) => a.sentAt != null)
      .map(
        (a) => DriverPingTimelineItem(
          type: a.type,
          sentAt: a.sentAt!,
          deliveredAt: a.deliveredAt,
          openedAt: a.openedAt,
          automatic: a.automatic,
        ),
      )
      .toList()
    ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  return items;
}

class _PingAccumulator {
  _PingAccumulator(this.type);

  final DriverPingType type;
  DateTime? sentAt;
  DateTime? deliveredAt;
  DateTime? openedAt;
  bool automatic = false;
}
