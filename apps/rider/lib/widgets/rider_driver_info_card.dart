import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class RiderDriverSheetInfo {
  final String? driverId;
  final String fullName;
  final String? profilePhotoUrl;
  final String? vehiclePlate;
  final String? vehicleCategory;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePhotoUrl;
  final double? rating;

  const RiderDriverSheetInfo({
    this.driverId,
    required this.fullName,
    this.profilePhotoUrl,
    this.vehiclePlate,
    this.vehicleCategory,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePhotoUrl,
    this.rating,
  });

  factory RiderDriverSheetInfo.fromJson(
    Map<String, dynamic> json, {
    required String fallbackDriverLabel,
  }) {
    final ratingRaw = json['avg_rating'];
    final rating = ratingRaw is num ? ratingRaw.toDouble() : null;
    String? firstPhoto;
    final rawPhotos = json['vehicle_photo_urls'];
    if (rawPhotos is List && rawPhotos.isNotEmpty) {
      final first = rawPhotos.first;
      if (first is String && first.trim().isNotEmpty) {
        firstPhoto = first.trim();
      }
    }
    return RiderDriverSheetInfo(
      driverId: json['driver_id'] as String?,
      fullName: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? (json['full_name'] as String).trim()
          : fallbackDriverLabel,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleCategory: json['vehicle_category'] as String?,
      vehicleMake: json['vehicle_make'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor:
          (json['vehicle_colour'] ?? json['vehicle_color']) as String?,
      vehiclePhotoUrl: firstPhoto,
      rating: rating,
    );
  }

  String get naturalVehicleLabel {
    final color = (vehicleColor ?? '').trim();
    final make = (vehicleMake ?? '').trim();
    final model = (vehicleModel ?? '').trim();
    final parts = [
      if (color.isNotEmpty) color,
      if (make.isNotEmpty) make,
      if (model.isNotEmpty) model,
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    return (vehicleCategory ?? '').trim();
  }
}

/// Platform driver card — name, photo, plate, vehicle (active ride + rating).
class RiderDriverInfoCard extends StatelessWidget {
  const RiderDriverInfoCard({
    super.key,
    required this.driverInfo,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final RiderDriverSheetInfo driverInfo;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final carLine = driverInfo.naturalVehicleLabel;
    final category = (driverInfo.vehicleCategory ?? '').trim();
    final categoryLabel = category.isNotEmpty
        ? category[0].toUpperCase() + category.substring(1)
        : l10n.vehicleStandard;
    final seatCount = category.toLowerCase().contains('taxibus') ? '8' : '4';
    final plate = (driverInfo.vehiclePlate ?? '').trim();
    final plateLabel =
        plate.isEmpty ? l10n.activeRideUnknownPlate : plate.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.card,
            colors.bgAlt,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.accentL,
                backgroundImage: (driverInfo.profilePhotoUrl != null &&
                        driverInfo.profilePhotoUrl!.isNotEmpty)
                    ? NetworkImage(driverInfo.profilePhotoUrl!)
                    : null,
                child: (driverInfo.profilePhotoUrl == null ||
                        driverInfo.profilePhotoUrl!.isEmpty)
                    ? Icon(Icons.person_rounded, color: colors.accent, size: 28)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverInfo.fullName,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.activeRideVerifiedTaxi,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                    if (driverInfo.rating != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            driverInfo.rating!.toStringAsFixed(1),
                            style: typo.labelMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 96,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border.withValues(alpha: 0.7)),
                ),
                clipBehavior: Clip.antiAlias,
                child: (driverInfo.vehiclePhotoUrl != null &&
                        driverInfo.vehiclePhotoUrl!.isNotEmpty)
                    ? Image.network(
                        driverInfo.vehiclePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.directions_car_filled_rounded,
                          color: colors.textSoft,
                          size: 30,
                        ),
                      )
                    : Icon(
                        Icons.directions_car_filled_rounded,
                        color: colors.textSoft,
                        size: 34,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.text.withValues(alpha: 0.12),
                width: 1.4,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.activeRidePlateNumber,
                  style: typo.labelSmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    plateLabel,
                    style: typo.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            carLine.isNotEmpty ? carLine : l10n.vehicleStandard,
            style: typo.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$categoryLabel · ${l10n.activeRideSeatsMax(seatCount)}',
            style: typo.bodySmall.copyWith(color: colors.textMid),
          ),
        ],
      ),
    );
  }
}
