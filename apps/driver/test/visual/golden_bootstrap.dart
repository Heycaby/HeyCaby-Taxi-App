import 'package:google_fonts/google_fonts.dart';
import 'package:heycaby_driver/theme/driver_motion_presets.dart';
import 'package:heycaby_ui/src/theme/typography.dart';

/// Import this library **first** in driver visual tests (before `heycaby_ui.dart`).
final bool kDriverGoldenTypographyBootstrapped = () {
  kHeyCabyUseRobotoTypographyForTests = true;
  GoogleFonts.config.allowRuntimeFetching = false;
  kDriverMotionEnabled = false;
  return true;
}();
