/// Full-screen ride routes hide bottom navigation (Program 4 / L2 immersive).
bool isDriverImmersiveRoute(String location) {
  return location.startsWith('/driver/ride/');
}

/// Approximate height of [DriverResilienceBanner] when visible (below status bar).
const double kDriverResilienceBannerBodyHeight = 44;
