/// Payload for the start-shift confirmation screen (plate claim V2).
class DriverStartShiftArgs {
  const DriverStartShiftArgs({
    required this.vehiclePlate,
    required this.vehiclePlateEntered,
    required this.rdwSnapshot,
    required this.vehicleVerificationStatus,
    required this.resumeGoOnline,
  });

  final String vehiclePlate;
  final String vehiclePlateEntered;
  final Map<String, dynamic> rdwSnapshot;
  final String vehicleVerificationStatus;
  final bool resumeGoOnline;

  String? get vehicleMake => rdwSnapshot['merk']?.toString();
  String? get vehicleModel => rdwSnapshot['handelsbenaming']?.toString();

  static DriverStartShiftArgs? fromShiftStartPrompt({
    required Map<String, dynamic>? response,
    required String vehiclePlate,
    required String vehiclePlateEntered,
    required Map<String, dynamic> rdwSnapshot,
    required String vehicleVerificationStatus,
    required bool resumeGoOnline,
  }) {
    if (response?['shared_prompt'] != true &&
        response?['shift_start_prompt'] != true) {
      return null;
    }
    return DriverStartShiftArgs(
      vehiclePlate: vehiclePlate,
      vehiclePlateEntered: vehiclePlateEntered,
      rdwSnapshot: rdwSnapshot,
      vehicleVerificationStatus: vehicleVerificationStatus,
      resumeGoOnline: resumeGoOnline,
    );
  }
}
