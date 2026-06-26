import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/driver_shift_command_body.dart';

/// **Shift Command** — control active shift without leaving the map mental model.
class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key});

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  WorkSubTab _subTab = WorkSubTab.earnings;
  RideFilter _rideFilter = RideFilter.now;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  @override
  Widget build(BuildContext context) {
    return DriverShiftCommandBody(
      subTab: _subTab,
      rideFilter: _rideFilter,
      onSubTabChange: (tab) => setState(() => _subTab = tab),
      onFilterChange: (filter) => setState(() => _rideFilter = filter),
      onBack: _handleBack,
    );
  }
}
