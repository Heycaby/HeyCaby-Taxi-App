import 'color_tokens.dart';
import 'typography.dart';

class HeyCabyThemeData {
  final String id;
  final String name;
  final String tagline;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;

  const HeyCabyThemeData({
    required this.id,
    required this.name,
    required this.tagline,
    required this.colors,
    required this.typography,
  });
}
