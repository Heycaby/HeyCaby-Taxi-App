import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:intl/intl.dart';

import '../providers/ride_history_provider.dart';
import '../providers/ride_request_provider.dart';

/// Pass via `GoRouter` `extra` from [router.dart].
class ReportRouteArgs {
  final String? ridesRowId;
  final bool fromActiveRide;

  const ReportRouteArgs({
    this.ridesRowId,
    this.fromActiveRide = false,
  });
}

/// [prefilledRidesRowId] is a row id from [rides] (e.g. from Rides tab / ride detail).
/// It is resolved to `ride_requests.id` for `ride_reports.ride_id` when possible.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    super.key,
    this.prefilledRidesRowId,
    this.fromActiveRide = false,
  });

  final String? prefilledRidesRowId;
  final bool fromActiveRide;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  String? _selectedReportRideId;
  RideHistoryItem? _selectedRidePreview;
  List<RideHistoryItem> _completedCandidates = [];
  bool _loadingRides = true;
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  List<_ReportReason> _getReportReasons(AppLocalizations l10n) => [
        _ReportReason(
            id: 'driver_behavior',
            label: l10n.reportDriverBehavior,
            icon: Icons.person_outline),
        _ReportReason(
            id: 'vehicle_condition',
            label: l10n.reportVehicleCondition,
            icon: Icons.directions_car_outlined),
        _ReportReason(
            id: 'route_issue',
            label: l10n.reportRouteIssue,
            icon: Icons.route_outlined),
        _ReportReason(
            id: 'safety_concern',
            label: l10n.reportSafetyConcern,
            icon: Icons.warning_outlined),
        _ReportReason(
            id: 'pricing_dispute',
            label: l10n.reportPricingDispute,
            icon: Icons.attach_money_outlined),
        _ReportReason(
            id: 'other', label: l10n.reportOther, icon: Icons.more_horiz),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (widget.prefilledRidesRowId != null) {
      final resolved =
          await _resolveRideRequestIdForRidesRow(widget.prefilledRidesRowId!);
      if (mounted) {
        setState(() => _selectedReportRideId = resolved);
      }
    } else if (widget.fromActiveRide) {
      final reqId = ref.read(rideRequestProvider).rideRequestId;
      if (reqId != null && mounted) {
        setState(() => _selectedReportRideId = reqId);
      }
    }

    await _loadCompletedRides();
  }

  Future<void> _loadCompletedRides() async {
    try {
      final userId = HeyCabySupabase.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loadingRides = false);
        return;
      }
      final since = DateTime.now().subtract(const Duration(days: 14));
      final res = await HeyCabySupabase.client
          .from('rides')
          .select('''
            id,
            status,
            pickup_address,
            destination_address,
            fare,
            created_at,
            completed_at,
            driver:driver_id ( name, photo_url )
            ''')
          .eq('rider_id', userId)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(40);

      var list = (res as List)
          .map((j) => RideHistoryItem.fromJson(j as Map<String, dynamic>))
          .toList();
      list = list.where((r) {
        final c = r.completedAt;
        if (c == null) return true;
        return c.isAfter(since);
      }).take(30).toList();

      if (mounted) {
        setState(() {
          _completedCandidates = list;
          _loadingRides = false;
          if (widget.prefilledRidesRowId != null) {
            try {
              _selectedRidePreview = list.firstWhere(
                (r) => r.id == widget.prefilledRidesRowId,
              );
            } catch (_) {}
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ReportScreen _loadCompletedRides: $e');
      if (mounted) setState(() => _loadingRides = false);
    }
  }

  /// `ride_reports.ride_id` stores the active booking id (`ride_requests.id`).
  Future<String> _resolveRideRequestIdForRidesRow(String ridesRowId) async {
    try {
      final row = await HeyCabySupabase.client
          .from('rides')
          .select('ride_request_id')
          .eq('id', ridesRowId)
          .maybeSingle();
      final rr = row?['ride_request_id'] as String?;
      if (rr != null && rr.isNotEmpty) return rr;
    } catch (e) {
      if (kDebugMode) debugPrint('resolve ride_request_id: $e');
    }
    return ridesRowId;
  }

  Future<void> _onPickRide(RideHistoryItem ride) async {
    final id = await _resolveRideRequestIdForRidesRow(ride.id);
    if (!mounted) return;
    setState(() {
      _selectedReportRideId = id;
      _selectedRidePreview = ride;
    });
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;
    final rideKey = _selectedReportRideId;
    if (rideKey == null || rideKey.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await HeyCabySupabase.client.from('ride_reports').insert({
        'ride_id': rideKey,
        'reason': _selectedReason,
        'details': _detailsController.text.trim(),
        'status': 'pending',
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reportSubmitted)),
        );
        context.pop();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Report submit error: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reportSubmitFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    final canSubmit = _selectedReason != null &&
        _selectedReportRideId != null &&
        !_isSubmitting;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.reportIssue,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 24),
                children: [
                  Text(
                    l10n.reportSelectRideTitle,
                    style: typo.headingMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.reportSelectRideHint,
                    style: typo.bodyMedium.copyWith(color: colors.textMid),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingRides)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: colors.accent),
                      ),
                    )
                  else ...[
                    if (widget.fromActiveRide &&
                        _selectedReportRideId != null &&
                        _selectedRidePreview == null)
                      _ActiveRideReportBanner(
                        colors: colors,
                        typo: typo,
                        l10n: l10n,
                      )
                    else if (_selectedRidePreview != null)
                      _SelectedRideSummary(
                        ride: _selectedRidePreview!,
                        colors: colors,
                        typo: typo,
                        l10n: l10n,
                        locale: locale,
                        onChange: widget.fromActiveRide
                            ? null
                            : () => setState(() {
                                  _selectedRidePreview = null;
                                  _selectedReportRideId = null;
                                }),
                      )
                    else if (_selectedReportRideId != null &&
                        !widget.fromActiveRide)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.reportSelectedRideFallback,
                          style: typo.bodyMedium.copyWith(color: colors.textMid),
                        ),
                      )
                    else if (!(widget.fromActiveRide &&
                        _selectedReportRideId != null)) ...[
                      if (_completedCandidates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l10n.reportNoRidesToReport,
                            style: typo.bodyMedium.copyWith(color: colors.textMid),
                          ),
                        )
                      else
                        ..._completedCandidates.map(
                          (r) => Padding(
                            padding:
                                const EdgeInsetsDirectional.only(bottom: 10),
                            child: _RidePickRow(
                              ride: r,
                              colors: colors,
                              typo: typo,
                              l10n: l10n,
                              locale: locale,
                              onTap: () => _onPickRide(r),
                            ),
                          ),
                        ),
                    ],
                  ],
                  if (_selectedReportRideId != null) ...[
                    const SizedBox(height: 28),
                    Text(
                      l10n.whatWentWrong,
                      style: typo.headingMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.helpUsUnderstand,
                      style: typo.bodyMedium.copyWith(color: colors.textMid),
                    ),
                    const SizedBox(height: 24),
                    ..._getReportReasons(l10n).map((reason) {
                      final isSelected = _selectedReason == reason.id;
                      return Padding(
                        padding:
                            const EdgeInsetsDirectional.only(bottom: 12),
                        child: _ReasonCard(
                          reason: reason,
                          isSelected: isSelected,
                          colors: colors,
                          typo: typo,
                          onTap: () =>
                              setState(() => _selectedReason = reason.id),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    Text(
                      l10n.additionalDetails,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _detailsController,
                      style: typo.bodyMedium.copyWith(color: colors.text),
                      maxLines: 5,
                      maxLength: 5000,
                      decoration: InputDecoration(
                        hintText: l10n.pleaseProvideMoreDetails,
                        hintStyle:
                            typo.bodyMedium.copyWith(color: colors.textSoft),
                        filled: true,
                        fillColor: colors.card,
                        contentPadding:
                            const EdgeInsetsDirectional.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: colors.accent, width: 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: colors.surface,
                boxShadow: [
                  BoxShadow(
                    color: colors.text.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: !canSubmit ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        !canSubmit ? colors.border : colors.error,
                    foregroundColor:
                        !canSubmit ? colors.textMid : colors.onError,
                    elevation: 0,
                    disabledBackgroundColor: colors.border,
                    disabledForegroundColor: colors.textMid,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: colors.onError,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          l10n.submitReport,
                          style: typo.labelLarge.copyWith(
                            color: !canSubmit
                                ? colors.textMid
                                : colors.onError,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRideReportBanner extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _ActiveRideReportBanner({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colors.accentL,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_taxi_rounded, color: colors.accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.reportActiveTripBanner,
              style: typo.bodyLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedRideSummary extends StatelessWidget {
  final RideHistoryItem ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String locale;
  final VoidCallback? onChange;

  const _SelectedRideSummary({
    required this.ride,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.locale,
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = ride.completedAt != null
        ? DateFormat.yMMMd(locale).add_Hm().format(ride.completedAt!.toLocal())
        : DateFormat.yMMMd(locale).format(ride.createdAt.toLocal());

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: colors.success, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.reportSelectedRideLabel,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onChange != null)
                TextButton(
                  onPressed: onChange,
                  child: Text(l10n.reportChangeRide),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(dateStr, style: typo.bodySmall.copyWith(color: colors.textMid)),
          const SizedBox(height: 8),
          Text(
            ride.pickupAddress,
            style: typo.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            ride.destinationAddress,
            style: typo.bodySmall.copyWith(color: colors.textMid),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RidePickRow extends StatelessWidget {
  final RideHistoryItem ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String locale;
  final VoidCallback onTap;

  const _RidePickRow({
    required this.ride,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = ride.completedAt != null
        ? DateFormat.yMMMd(locale).add_Hm().format(ride.completedAt!.toLocal())
        : DateFormat.yMMMd(locale).format(ride.createdAt.toLocal());

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: typo.labelSmall.copyWith(color: colors.textSoft),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ride.pickupAddress.split(',').first,
                      style: typo.bodyMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ride.destinationAddress.split(',').first,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.reportSelectThisRide,
                style: typo.labelLarge.copyWith(
                  color: colors.accent,
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

class _ReportReason {
  final String id;
  final String label;
  final IconData icon;
  const _ReportReason(
      {required this.id, required this.label, required this.icon});
}

class _ReasonCard extends StatelessWidget {
  final _ReportReason reason;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ReasonCard({
    required this.reason,
    required this.isSelected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.error.withValues(alpha: 0.1) : colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.error : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isSelected ? colors.error.withValues(alpha: 0.15) : colors.bgAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(reason.icon,
                  color: isSelected ? colors.error : colors.textMid, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason.label,
                style: typo.bodyLarge.copyWith(
                  color: colors.text,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colors.error, size: 24),
          ],
        ),
      ),
    );
  }
}
