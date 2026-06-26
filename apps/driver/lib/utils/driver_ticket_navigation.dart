import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens the driver’s ride history detail when the ticket is tied to a ride;
/// otherwise opens the support chat thread.
void openDriverSupportTicketOrRide(
  BuildContext context, {
  required String ticketId,
  String? rideRequestId,
}) {
  final r = rideRequestId?.trim();
  if (r != null && r.isNotEmpty) {
    context.push('/driver/my-rides/$r');
  } else {
    context.push('/driver/support/chat/$ticketId');
  }
}
