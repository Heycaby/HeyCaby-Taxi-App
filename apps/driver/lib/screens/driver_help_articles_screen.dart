import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_knowledge_base_body.dart';

/// Full-screen WebView for Driver Help articles URL.
class DriverHelpArticlesScreen extends ConsumerStatefulWidget {
  const DriverHelpArticlesScreen({super.key, required this.url});

  final String url;

  @override
  ConsumerState<DriverHelpArticlesScreen> createState() =>
      _DriverHelpArticlesScreenState();
}

class _DriverHelpArticlesScreenState extends ConsumerState<DriverHelpArticlesScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverKnowledgeBaseBody(
      colors: colors,
      typography: typography,
      onBack: () => Navigator.of(context).pop(),
      content: WebViewWidget(controller: _controller),
    );
  }
}
