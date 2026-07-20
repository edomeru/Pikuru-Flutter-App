import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pikuru/theme/material.dart';

/// Full-screen WebView that drives the Sign in with Apple OAuth flow on
/// Android.
///
/// Android has no native Sign in with Apple sheet, so the flow is a plain
/// OAuth web page (`appleid.apple.com/auth/authorize`). Previously this was
/// opened in an external Chrome Custom Tab via `url_launcher`, which meant
/// Apple's page language followed the *device's* system language, not
/// Pikuru's own in-app language toggle.
///
/// By loading the same URL inside a WebView we control, we can set the
/// `Accept-Language` header on the initial request ourselves, so the page
/// renders in whichever language the user has selected inside Pikuru.
///
/// When Apple finishes authenticating, our server
/// (pikuru-app.web.app/api/apple-callback) redirects to the app's custom
/// `pikuru://apple-callback?...` scheme. A plain WebView can't "navigate" to
/// a non-http(s) scheme, so we intercept that navigation attempt via
/// [NavigationDelegate.onNavigationRequest] before it fails, and pop this
/// screen with the resulting [Uri]. If the user closes the screen manually,
/// it pops with `null`.
class AppleSignInWebViewScreen extends StatefulWidget {
  final Uri authUrl;
  final String acceptLanguage;
  final String callbackScheme;
  final String callbackHost;

  const AppleSignInWebViewScreen({
    super.key,
    required this.authUrl,
    required this.acceptLanguage,
    this.callbackScheme = 'pikuru',
    this.callbackHost = 'apple-callback',
  });

  @override
  State<AppleSignInWebViewScreen> createState() =>
      _AppleSignInWebViewScreenState();
}

class _AppleSignInWebViewScreenState extends State<AppleSignInWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                uri.scheme == widget.callbackScheme &&
                uri.host == widget.callbackHost) {
              _finish(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _load();
  }

  Future<void> _load() async {
    // Apple sets a locale-preference cookie the first time its sign-in page
    // loads, and on later visits it prefers that cookie over the
    // Accept-Language header. Since the WebView's cookie/storage jar is
    // shared app-wide (not per-screen), a cookie set during an earlier
    // Japanese attempt would otherwise "stick" even after switching Pikuru
    // to English. Clearing it before every attempt forces Apple to
    // re-derive the language from the header we're about to send.
    try {
      await WebViewCookieManager().clearCookies();
    } catch (_) {}
    try {
      await _controller.clearCache();
    } catch (_) {}
    try {
      await _controller.clearLocalStorage();
    } catch (_) {}
    if (!mounted) return;
    await _controller.loadRequest(
      widget.authUrl,
      headers: {'Accept-Language': widget.acceptLanguage},
    );
  }

  void _finish(Uri? result) {
    if (_handled) return;
    _handled = true;
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        _handled = true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black87),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _finish(null),
          ),
          title: const Text(
            'Sign in with Apple',
            style: TextStyle(color: Colors.black87, fontSize: 16),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}
