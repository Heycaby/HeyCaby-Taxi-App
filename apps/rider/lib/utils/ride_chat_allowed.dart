/// Ride statuses where in-ride driver ↔ rider chat is permitted.
bool isRideChatAllowed(String? status) {
  const activeStatuses = {
    'assigned',
    'accepted',
    'driver_found',
    'driver_en_route',
    'driver_arrived',
    'arrived',
    'in_progress',
  };
  return status != null && activeStatuses.contains(status);
}
