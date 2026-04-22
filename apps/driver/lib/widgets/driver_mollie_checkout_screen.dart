import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/driver_strings.dart';

/// Full-screen Mollie hosted checkout; pops with `true` when user hits return URL.
class DriverMollieCheckoutScreen extends StatefulWidget {
  const DriverMollieCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.colors,
    required this.typo,
  });

  final String checkoutUrl;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  State<DriverMollieCheckoutScreen> createState() =>
      _DriverMollieCheckoutScreenState();
}

class _DriverMollieCheckoutScreenState extends State<DriverMollieCheckoutScreen> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.checkoutUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final u = request.url;
            if (u.contains('driver/payment/return')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop(true);
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    if (uri != null) {
      _controller.loadRequest(uri);
    } else {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typo;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.card,
        foregroundColor: colors.text,
        title: Text(DriverStrings.platformFeeCheckoutTitle, style: typo.titleMedium),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          if (Uri.tryParse(widget.checkoutUrl) != null)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  DriverStrings.platformFeeInvalidUrl,
                  textAlign: TextAlign.center,
                  style: typo.bodyMedium.copyWith(color: colors.textMid),
                ),
              ),
            ),
          if (_loading)
            ColoredBox(
              color: colors.bg.withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
