import 'package:intl/intl.dart';

String formatRideLineRelativeTime(DateTime at) {
  final diff = DateTime.now().difference(at.toLocal());
  if (diff.inMinutes < 1) return '1 min';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  return DateFormat('d MMM').format(at.toLocal());
}
