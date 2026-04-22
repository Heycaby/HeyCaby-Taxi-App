import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen WebView for Driver Help articles URL.
class DriverHelpArticlesScreen extends StatefulWidget {
  const DriverHelpArticlesScreen({super.key, required this.url});

  final String url;

  @override
  State<DriverHelpArticlesScreen> createState() => _DriverHelpArticlesScreenState();
}

class _DriverHelpArticlesScreenState extends State<DriverHelpArticlesScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help artikelen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
