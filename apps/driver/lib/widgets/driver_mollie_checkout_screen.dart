import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';

/// Full-screen Mollie hosted checkout or customer portal; pops with `true` when user hits return URL.
class DriverMollieCheckoutScreen extends StatefulWidget {
  const DriverMollieCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.colors,
    required this.typo,
    this.appBarTitle,

    /// When non-null and [autoPopOnSuccessUrlMatch] is true, navigation to a URL containing this substring pops `true`.
    this.successUrlContains = 'driver/payment/return',

    /// If false, only the close button dismisses (e.g. mandate portal where return URL is unpredictable).
    this.autoPopOnSuccessUrlMatch = true,
  });

  final String checkoutUrl;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String? appBarTitle;
  final String? successUrlContains;
  final bool autoPopOnSuccessUrlMatch;

  @override
  State<DriverMollieCheckoutScreen> createState() =>
      _DriverMollieCheckoutScreenState();
}

class _DriverMollieCheckoutScreenState
    extends State<DriverMollieCheckoutScreen> {
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
            final needle = widget.successUrlContains;
            if (widget.autoPopOnSuccessUrlMatch &&
                needle != null &&
                needle.isNotEmpty &&
                u.contains(needle)) {
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
    final driverColors = DriverColors.fromTheme(colors);
    final driverTypography = DriverTypography.fromTheme(typo);
    return Scaffold(
      backgroundColor: driverColors.background,
      appBar: DriverAppBar(
        title: widget.appBarTitle ?? DriverStrings.platformFeeCheckoutTitle,
        colors: driverColors,
        typography: driverTypography,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: driverColors.text),
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
              child: Center(
                child: CircularProgressIndicator(color: driverColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}
