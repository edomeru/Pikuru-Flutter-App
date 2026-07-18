import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/register/RegisterPage.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/main_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:pikuru/Utils/auth_service.dart';
import 'package:pikuru/screens/reset_password_dialog.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:pikuru/services/notification_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localised strings — mirrors the web app's T map in login/page.tsx
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'headerTitle': 'Sign In',
    'emailHint': 'Email',
    'passwordHint': 'Password',
    'forgotPassword': 'Forgot Password?',
    'signInBtn': 'Sign In',
    'orWith': 'Or Sign In With',
    'google': 'Google',
    'apple': 'Apple',
    'noAccount': "Don't have an account yet? ",
    'signUp': 'Sign Up',
    // Error messages — mirrors web app's friendly() function
    'errInvalidCred': 'Incorrect email or password. Please try again.',
    'errInvalidEmail': 'Please enter a valid email address.',
    'errDisabled': 'This account has been disabled.',
    'errTooMany': 'Too many attempts. Please try again later.',
    'errDefault': 'Login failed. Please try again.',
    'errGoogle': 'Google sign-in failed',
  },
  kLangJa: {
    'headerTitle': 'ログイン',
    'emailHint': 'メールアドレス',
    'passwordHint': 'パスワード',
    'forgotPassword': 'パスワードをお忘れですか？',
    'signInBtn': 'ログイン',
    'orWith': 'または以下でログイン',
    'google': 'Google',
    'apple': 'Apple',
    'noAccount': 'アカウントをお持ちでないですか？ ',
    'signUp': '登録する',
    // Error messages — mirrors web app's friendlyJa() function
    'errInvalidCred': 'メールアドレスまたはパスワードが正しくありません。',
    'errInvalidEmail': '有効なメールアドレスを入力してください。',
    'errDisabled': 'このアカウントは無効化されています。',
    'errTooMany': 'ログイン試行回数が多すぎます。後でもう一度お試しください。',
    'errDefault': 'エラーが発生しました。もう一度お試しください。',
    'errGoogle': 'Googleログインに失敗しました',
  },
};

String _t(String lang, String key) => _L[lang]?[key] ?? _L[kLangEn]![key]!;

/// Mirrors the web app's friendly() / friendlyJa() functions
String _authError(String lang, String code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return _t(lang, 'errInvalidCred');
    case 'invalid-email':
      return _t(lang, 'errInvalidEmail');
    case 'user-disabled':
      return _t(lang, 'errDisabled');
    case 'too-many-requests':
      return _t(lang, 'errTooMany');
    default:
      return _t(lang, 'errDefault');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen — ConsumerStatefulWidget to watch appLangProvider
// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  bool showSpinner = false;
  String email = '';
  String password = '';

  Future<void> _clearGoogleSession() async {
    try {
      final google = GoogleSignIn();
      await google.disconnect();
    } catch (_) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
  }

  // ── Ensure SSO users have a registration doc using 'nickname' ──────────────
  Future<void> _ensureRegistrationDoc(User user) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('registration')
          .doc(user.uid);
      final docSnap = await docRef.get();
      final data = docSnap.data() ?? {};

      if (!docSnap.exists ||
          ((data['nickname'] ?? '').toString().isEmpty &&
              (data['firstName'] ?? '').toString().isEmpty)) {
        final nickname = (user.displayName ?? '').trim();
        final provider = user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'password';

        await docRef.set({
          'nickname': nickname,
          'email': user.email ?? '',
          'uid': user.uid,
          'address': data['address'] ?? '',
          'description': data['description'] ?? '',
          'provider': data['provider']?.toString().isNotEmpty == true
              ? data['provider']
              : provider,
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if ((data['provider'] ?? '').toString().isEmpty) {
        final provider = user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'password';
        await docRef.set({'provider': provider}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error ensuring registration doc: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, lang),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 36),

                    // ── Email ────────────────────────────────────────────────
                    TextFormField(
                      onChanged: (v) => email = v,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _inputDecoration(_t(lang, 'emailHint')),
                    ),

                    const SizedBox(height: 16),

                    // ── Password ─────────────────────────────────────────────
                    TextFormField(
                      obscureText: true,
                      onChanged: (v) => password = v,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _inputDecoration(_t(lang, 'passwordHint')),
                    ),

                    const SizedBox(height: 6),

                    // ── Forgot Password ──────────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => showResetPasswordDialog(
                          context,
                          prefillEmail: email.trim(),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _t(lang, 'forgotPassword'),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Sign In Button ───────────────────────────────────────
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() => showSpinner = true);
                          try {
                            await _auth.signInWithEmailAndPassword(
                              email: email.trim(),
                              password: password,
                            );
                            await NotificationService.instance
                                .init(); // re-saves token with new uid
                            setState(() => showSpinner = false);
                            if (!mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MainNavigation(),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            setState(() => showSpinner = false);
                            final msg = _authError(lang, e.code);
                            if (!mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(msg)));
                          } catch (e) {
                            setState(() => showSpinner = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _t(lang, 'signInBtn'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Divider ──────────────────────────────────────────────
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            _t(lang, 'orWith'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Google + Apple ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _pillButton(
                            onPressed: () async {
                              setState(() => showSpinner = true);
                              await _clearGoogleSession();
                              final result =
                              await AuthService.signInWithGoogle();
                              setState(() => showSpinner = false);
                              if (result != null) {
                                await result.user!.getIdToken(true);
                                await _ensureRegistrationDoc(result.user!);
                                await NotificationService.instance
                                    .init(); // re-saves token with new uid
                                if (!mounted) return;
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MainNavigation(),
                                  ),
                                );
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_t(lang, 'errGoogle')),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _googleIcon(),
                                const SizedBox(width: 8),
                                Text(
                                  _t(lang, 'google'),
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _pillButton(
                            onPressed: () => _signInWithApple(lang),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.apple,
                                  color: Colors.black87,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _t(lang, 'apple'),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Sign Up link ─────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _t(lang, 'noAccount'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          ),
                          child: Text(
                            _t(lang, 'signUp'),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
          (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithApple(String lang) async {
    setState(() => showSpinner = true);
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      if (Platform.isIOS) {
        // ── iOS: use the native Apple ID sheet ──────────────────────────────
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        );
        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
        );
        final result = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
        final user = result.user!;
        if (appleCredential.givenName != null) {
          final fullName =
              '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                  .trim();
          await user.updateDisplayName(fullName);
          await user.reload();
        }
        await _ensureRegistrationDoc(user);
        await NotificationService.instance.init();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } else {
        // ── Android: manual OAuth flow via app_links + url_launcher ─────────
        // The sign_in_with_apple plugin's signinwithapple:// callback is
        // not reliably registered on Android. Instead we:
        //  1. Build the Apple OAuth URL ourselves
        //  2. Open it in the external browser via url_launcher
        //  3. Listen for pikuru://apple-callback?id_token=... via app_links
        //  4. Complete Firebase sign-in with the returned id_token + rawNonce

        final appleAuthUrl = Uri.https('appleid.apple.com', '/auth/authorize', {
          'client_id': 'com.pikuru.pickleball.pikuru',
          'redirect_uri': 'https://pikuru-app.web.app/api/apple-callback',
          'response_type': 'code id_token',
          'scope': 'name email',
          'response_mode': 'form_post',
          'nonce': hashedNonce,
        });

        final completer = Completer<Uri>();
        final appLinks = AppLinks();
        late StreamSubscription<Uri> sub;
        sub = appLinks.uriLinkStream.listen((uri) {
          if (uri.scheme == 'pikuru' && uri.host == 'apple-callback') {
            sub.cancel();
            if (!completer.isCompleted) completer.complete(uri);
          }
        });

        final launched = await launchUrl(
          appleAuthUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          sub.cancel();
          throw Exception('Could not open Apple sign-in page');
        }

        // Wait up to 5 minutes for the user to complete Apple sign-in
        final callbackUri = await completer.future.timeout(
          const Duration(minutes: 5),
          onTimeout: () {
            sub.cancel();
            throw Exception('Apple sign-in timed out');
          },
        );

        final idToken = callbackUri.queryParameters['id_token'];
        if (idToken == null || idToken.isEmpty) {
          throw Exception('Apple did not return an id_token');
        }

        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: idToken,
          rawNonce: rawNonce,
        );
        final result = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
        final user = result.user!;

        // Apple only sends name on first sign-in
        final userJson = callbackUri.queryParameters['user'];
        if (userJson != null && userJson.isNotEmpty) {
          try {
            final userMap = jsonDecode(userJson) as Map<String, dynamic>;
            final nameMap = userMap['name'] as Map<String, dynamic>?;
            if (nameMap != null) {
              final fullName =
                  '${nameMap['firstName'] ?? ''} ${nameMap['lastName'] ?? ''}'
                      .trim();
              if (fullName.isNotEmpty) {
                await user.updateDisplayName(fullName);
                await user.reload();
              }
            }
          } catch (_) {}
        }

        await _ensureRegistrationDoc(user);
        await NotificationService.instance.init();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple sign-in failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => showSpinner = false);
    }
  }

  Widget _buildHeader(BuildContext context, String lang) {
    final w = MediaQuery.of(context).size.width;
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Container(color: Colors.white),
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: w * 0.75,
              height: w * 0.75,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: w * 0.70,
              height: w * 0.70,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.50),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 68,
            left: 28,
            child: Text(
              _t(lang, 'headerTitle'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: 20,
            child: SafeArea(
              child: _LangToggle(
                lang: lang,
                onToggle: (selected) =>
                    ref.read(appLangProvider.notifier).setLang(selected),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/pikuru_full_logo.png',
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _LangToggle extends StatelessWidget {
  final String lang;
  final ValueChanged<String> onToggle;
  const _LangToggle({required this.lang, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('EN', lang == kLangEn, () => onToggle(kLangEn)),
          _tab('日本語', lang == kLangJa, () => onToggle(kLangJa)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.95) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active
                ? const Color(0xFF2d6a3f)
                : Colors.white.withOpacity(0.75),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widget helpers
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: AppColors.primary.withOpacity(0.6),
        width: 1.4,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
    ),
  );
}

Widget _pillButton({required VoidCallback onPressed, required Widget child}) {
  return SizedBox(
    height: 48,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.white,
        padding: EdgeInsets.zero,
      ),
      child: child,
    ),
  );
}

Widget _googleIcon() {
  return SizedBox(
    width: 20,
    height: 20,
    child: CustomPaint(painter: _GoogleGPainter()),
  );
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Rect.fromLTWH(0, 0, size.width, size.height).center;
    final radius = size.width / 2;
    const sweeps = [
      [0.0, 90.0, Color(0xFF4285F4)],
      [90.0, 90.0, Color(0xFF34A853)],
      [180.0, 90.0, Color(0xFFFBBC05)],
      [270.0, 90.0, Color(0xFFEA4335)],
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.28;
    for (final s in sweeps) {
      paint.color = s[2] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.72),
        (s[0] as double) * 3.14159 / 180,
        (s[1] as double) * 3.14159 / 180,
        false,
        paint,
      );
    }
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - size.height * 0.15,
        size.width * 0.55,
        size.height * 0.30,
      ),
      whitePaint,
    );
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - size.height * 0.10,
        size.width * 0.50,
        size.height * 0.20,
      ),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
