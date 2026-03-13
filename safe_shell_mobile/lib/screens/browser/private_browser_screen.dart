import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';

class PrivateBrowserScreen extends StatefulWidget {
  const PrivateBrowserScreen({super.key});

  @override
  State<PrivateBrowserScreen> createState() => _PrivateBrowserScreenState();
}

class _PrivateBrowserScreenState extends State<PrivateBrowserScreen> {
  late final WebViewController _controller;
  final _urlController = TextEditingController();
  bool _isLoading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() => _progress = progress / 100);
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _urlController.text = url;
            });
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadRequest(Uri.parse('https://duckduckgo.com'));
    _urlController.text = 'https://duckduckgo.com';
  }

  void _loadUrl() {
    String url = _urlController.text.trim();
    if (!url.startsWith('http')) {
      url = 'https://duckduckgo.com/?q=$url';
    }
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search or type URL',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.lock, color: AppColors.primary, size: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.white70),
                onPressed: _loadUrl,
              ),
            ),
            onSubmitted: (_) => _loadUrl(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(value: _progress, color: AppColors.primary, backgroundColor: Colors.transparent),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return GlassCard(
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
            onPressed: () async {
              if (await _controller.canGoBack()) await _controller.goBack();
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white),
            onPressed: () async {
              if (await _controller.canGoForward()) await _controller.goForward();
            },
          ),
          FloatingActionButton(
            mini: true,
            backgroundColor: AppColors.primary,
            onPressed: () => _controller.loadRequest(Uri.parse('https://duckduckgo.com')),
            child: const Icon(Icons.home, size: 20),
          ),
          IconButton(
            icon: const Icon(Icons.tab, size: 20, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tabs coming soon')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white),
            onPressed: () {
              _controller.clearCache();
              _controller.clearLocalStorage();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History & Cache Cleared')));
            },
          ),
        ],
      ),
    );
  }
}
