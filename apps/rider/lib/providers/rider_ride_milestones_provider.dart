import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rider_community_growth_models.dart';

/// Fetches total completed rides from `fn_rider_ride_milestones` RPC.
final riderRideMilestonesProvider =
    FutureProvider.autoDispose<RiderRideMilestones>((ref) async {
  final identity = await ref.watch(riderIdentityProvider.future);
  if (!identity.hasSession) return RiderRideMilestones.empty;

  final token = identity.riderToken;
  if (token == null || token.isEmpty) return RiderRideMilestones.empty;

  try {
    final res = await HeyCabySupabase.client.rpc(
      'fn_rider_ride_milestones',
      params: {'p_rider_token': token},
    );
    if (res is Map) {
      return RiderRideMilestones.fromJson(res.cast<String, dynamic>());
    } else if (res is String && res.trim().isNotEmpty) {
      final decoded = jsonDecode(res);
      if (decoded is Map) {
        return RiderRideMilestones.fromJson(decoded.cast<String, dynamic>());
      }
    }
  } catch (_) {}
  return RiderRideMilestones.empty;
});

const _kStreakKey = 'heycaby_rider_streak';
const _kStreakWeekKey = 'heycaby_rider_streak_last_week';

/// Tracks consecutive weeks with at least 1 completed ride.
/// Purely client-side via SharedPreferences.
class RiderStreakNotifier extends Notifier<RiderStreak> {
  @override
  RiderStreak build() => RiderStreak.empty;

  Future<void> recordRideCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final thisWeek = _weekKey(now);

    final lastWeek = prefs.getString(_kStreakWeekKey) ?? '';
    final currentCount = prefs.getInt(_kStreakKey) ?? 0;

    if (lastWeek == thisWeek) return;

    final lastWeekDate = _weekStart(lastWeek);
    final thisWeekStart = _weekStart(thisWeek);
    final gap = thisWeekStart.difference(lastWeekDate);

    int newCount;
    if (lastWeek.isEmpty || gap.inDays > 7) {
      newCount = 1;
    } else {
      newCount = currentCount + 1;
    }

    await prefs.setInt(_kStreakKey, newCount);
    await prefs.setString(_kStreakWeekKey, thisWeek);
    state = RiderStreak(weekCount: newCount, lastRideWeek: thisWeek);
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kStreakKey) ?? 0;
    final lastWeek = prefs.getString(_kStreakWeekKey) ?? '';

    if (lastWeek.isEmpty) {
      state = RiderStreak.empty;
      return;
    }

    final thisWeek = _weekKey(DateTime.now());
    final lastWeekStart = _weekStart(lastWeek);
    final thisWeekStart = _weekStart(thisWeek);
    final gap = thisWeekStart.difference(lastWeekStart);

    if (gap.inDays > 7) {
      await prefs.setInt(_kStreakKey, 0);
      state = RiderStreak.empty;
    } else {
      state = RiderStreak(weekCount: count, lastRideWeek: lastWeek);
    }
  }

  String _weekKey(DateTime dt) {
    final monday = dt.subtract(Duration(days: dt.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  DateTime _weekStart(String key) {
    if (key.isEmpty) return DateTime(2000);
    return DateTime.tryParse(key) ?? DateTime(2000);
  }
}

final riderStreakProvider = NotifierProvider<RiderStreakNotifier, RiderStreak>(
  RiderStreakNotifier.new,
);
