import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/booking/booking_flow_screen_header.dart';

class RiderAnnouncementWebScreen extends ConsumerStatefulWidget {
  const RiderAnnouncementWebScreen({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  ConsumerState<RiderAnnouncementWebScreen> createState() =>
      _RiderAnnouncementWebScreenState();
}

class _RiderAnnouncementWebScreenState
    extends ConsumerState<RiderAnnouncementWebScreen> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: widget.title,
              icon: Icons.public_rounded,
              onBack: () => context.pop(),
            ),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
