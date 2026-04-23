import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// Translations
// ═══════════════════════════════════════════════════════════════════
const _T = {
  'en': {
    // Reset form dialog
    'resetTitle':       'Reset Password',
    'resetSub':         "Enter your email and we'll send you a reset link.",
    'emailHint':        'Enter your email',
    'cancel':           'Cancel',
    'sendLink':         'Send Link',
    // Validation
    'errEnterEmail':    'Please enter your email',
    'errInvalidEmail':  'Enter a valid email address',
    // Firebase errors
    'errInvalidFmt':    "That doesn't look like a valid email address.",
    'errTooMany':       'Too many attempts. Please wait a few minutes and try again.',
    'errGeneric':       'Something went wrong. Please try again.',
    // Info dialogs — Google
    'googleTitle':      'Google Account',
    'googleMsg':        'This email uses Google Sign-In — there is no password to reset.\n\n'
        'To change your Google password, visit myaccount.google.com.\n\n'
        'Then tap "Sign in with Google" on the login screen.',
    // Info dialogs — Apple
    'appleTitle':       'Apple Account',
    'appleMsg':         'This email uses Apple Sign-In — there is no password to reset.\n\n'
        'To change your Apple ID password, visit appleid.apple.com.\n\n'
        'Then tap "Sign in with Apple" on the login screen.',
    // Info dialogs — success
    'successTitle':     'Check your inbox',
    'successMsg':       'A reset link has been sent to:\n{email}\n\n'
        "Check your spam folder if it doesn't arrive within a minute.",
    'successMsgAnon':   'If an account exists for {email}, a reset link has been sent.',
    'gotIt':            'Got it',
  },
  'ja': {
    // Reset form dialog
    'resetTitle':       'パスワードをリセット',
    'resetSub':         'メールアドレスを入力してください。リセットリンクをお送りします。',
    'emailHint':        'メールアドレスを入力',
    'cancel':           'キャンセル',
    'sendLink':         'リンクを送信',
    // Validation
    'errEnterEmail':    'メールアドレスを入力してください',
    'errInvalidEmail':  '有効なメールアドレスを入力してください',
    // Firebase errors
    'errInvalidFmt':    '有効なメールアドレスを入力してください。',
    'errTooMany':       '試行回数が多すぎます。しばらくしてから再度お試しください。',
    'errGeneric':       'エラーが発生しました。もう一度お試しください。',
    // Info dialogs — Google
    'googleTitle':      'Googleアカウント',
    'googleMsg':        'このメールアドレスはGoogleログインを使用しています。リセットするパスワードはありません。\n\n'
        'Googleパスワードを変更するには、myaccount.google.comをご覧ください。\n\n'
        'ログイン画面で「Googleでサインイン」をタップしてください。',
    // Info dialogs — Apple
    'appleTitle':       'Appleアカウント',
    'appleMsg':         'このメールアドレスはAppleログインを使用しています。リセットするパスワードはありません。\n\n'
        'Apple IDのパスワードを変更するには、appleid.apple.comをご覧ください。\n\n'
        'ログイン画面で「Appleでサインイン」をタップしてください。',
    // Info dialogs — success
    'successTitle':     'メールを確認してください',
    'successMsg':       'リセットリンクを送信しました：\n{email}\n\n'
        '数分以内に届かない場合は、迷惑メールフォルダをご確認ください。',
    'successMsgAnon':   '{email} のアカウントが存在する場合、リセットリンクが送信されました。',
    'gotIt':            'わかりました',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T['en']![key]) ?? key;

/// Replaces `{email}` placeholder in a message string.
String _fillEmail(String template, String email) =>
    template.replaceAll('{email}', email);

// ═══════════════════════════════════════════════════════════════════
// Public entry point
// ═══════════════════════════════════════════════════════════════════
/// Call this from anywhere to show the reset password flow.
/// Reads the current language from [appLangProvider] via a
/// [ProviderScope]-aware dialog.
Future<void> showResetPasswordDialog(
    BuildContext context, {
      String prefillEmail = '',
    }) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ResetPasswordDialog(prefillEmail: prefillEmail),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Reset Password Dialog — ConsumerStatefulWidget
// ═══════════════════════════════════════════════════════════════════
class _ResetPasswordDialog extends ConsumerStatefulWidget {
  final String prefillEmail;
  const _ResetPasswordDialog({this.prefillEmail = ''});

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState
    extends ConsumerState<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool    _loading      = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController =
        TextEditingController(text: widget.prefillEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ── Firestore provider lookup ─────────────────────────────────────
  Future<String?> _getProviderForEmail(String email) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('registration')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      final provider =
      (q.docs.first.data()['provider'] ?? '').toString().trim();
      return provider.isEmpty ? null : provider;
    } catch (_) {
      return null;
    }
  }

  // ── Replace current dialog with info result dialog ────────────────
  void _replaceWithInfo({
    required String lang,
    required String title,
    required String message,
    required Widget icon,
    bool isSuccess = false,
  }) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => _InfoDialog(
          title:     title,
          message:   message,
          icon:      icon,
          isSuccess: isSuccess,
          gotItLabel: _t(lang, 'gotIt'),
        ),
      ),
    );
  }

  // ── Send reset link ───────────────────────────────────────────────
  Future<void> _onSendLink(String lang) async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _loading      = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Check signed-in user's providers
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          currentUser.email?.toLowerCase() == email) {
        final ids = currentUser.providerData
            .map((p) => p.providerId)
            .toList();
        if (ids.contains('google.com') &&
            !ids.contains('password')) {
          _replaceWithInfo(
            lang:      lang,
            title:     _t(lang, 'googleTitle'),
            message:   _t(lang, 'googleMsg'),
            icon:      const _GoogleLogoIcon(),
          );
          return;
        }
        if (ids.contains('apple.com') &&
            !ids.contains('password')) {
          _replaceWithInfo(
            lang:    lang,
            title:   _t(lang, 'appleTitle'),
            message: _t(lang, 'appleMsg'),
            icon: const Icon(Icons.apple,
                color: Colors.black87, size: 32),
          );
          return;
        }
      }

      // Step 2: Check Firestore registration doc
      final provider = await _getProviderForEmail(email);

      if (provider == 'google.com') {
        _replaceWithInfo(
          lang:    lang,
          title:   _t(lang, 'googleTitle'),
          message: _t(lang, 'googleMsg'),
          icon:    const _GoogleLogoIcon(),
        );
        return;
      }

      if (provider == 'apple.com') {
        _replaceWithInfo(
          lang:    lang,
          title:   _t(lang, 'appleTitle'),
          message: _t(lang, 'appleMsg'),
          icon: const Icon(Icons.apple,
              color: Colors.black87, size: 32),
        );
        return;
      }

      // Step 3: Send Firebase password reset email
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);

      _replaceWithInfo(
        lang:      lang,
        title:     _t(lang, 'successTitle'),
        message:   _fillEmail(_t(lang, 'successMsg'), email),
        icon: const Icon(Icons.mark_email_read_outlined,
            color: AppColors.primary, size: 32),
        isSuccess: true,
      );
    } on FirebaseAuthException catch (e) {
      String? msg;
      switch (e.code) {
        case 'user-not-found':
        // Security: show success-style message either way
          _replaceWithInfo(
            lang:      lang,
            title:     _t(lang, 'successTitle'),
            message:   _fillEmail(_t(lang, 'successMsgAnon'), email),
            icon: const Icon(Icons.mark_email_read_outlined,
                color: AppColors.primary, size: 32),
            isSuccess: true,
          );
          return;
        case 'invalid-email':
          msg = _t(lang, 'errInvalidFmt');
          break;
        case 'too-many-requests':
          msg = _t(lang, 'errTooMany');
          break;
        default:
          msg = _t(lang, 'errGeneric');
      }
      if (mounted) setState(() => _errorMessage = msg);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = _t(lang, 'errGeneric'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon ───────────────────────────────────────────────
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),

              // ── Title ──────────────────────────────────────────────
              Text(
                _t(lang, 'resetTitle'),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),

              Text(
                _t(lang, 'resetSub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.45),
                    height: 1.5),
              ),
              const SizedBox(height: 20),

              // ── Email field ────────────────────────────────────────
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _onSendLink(lang),
                decoration: InputDecoration(
                  hintText: _t(lang, 'emailHint'),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: AppColors.primary, size: 20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.primary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: Colors.red.shade300),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.red.shade400, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return _t(lang, 'errEnterEmail');
                  }
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(val.trim())) {
                    return _t(lang, 'errInvalidEmail');
                  }
                  return null;
                },
              ),

              // ── Inline error banner ────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade400, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 22),

              // ── Cancel / Send Link buttons ─────────────────────────
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 13),
                    ),
                    child: Text(
                      _t(lang, 'cancel'),
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                    _loading ? null : () => _onSendLink(lang),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                      AppColors.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 13),
                    ),
                    child: _loading
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                        : Text(
                      _t(lang, 'sendLink'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Info / result dialog
// ═══════════════════════════════════════════════════════════════════
class _InfoDialog extends StatelessWidget {
  final String title;
  final String message;
  final Widget icon;
  final bool   isSuccess;
  final String gotItLabel;

  const _InfoDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.gotItLabel,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Center(child: icon),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.5),
                  height: 1.55),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding:
                  const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(
                  gotItLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Google coloured G logo
// ═══════════════════════════════════════════════════════════════════
class _GoogleLogoIcon extends StatelessWidget {
  const _GoogleLogoIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32, height: 32,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const sweeps = [
      [0.0,   90.0, Color(0xFF4285F4)],
      [90.0,  90.0, Color(0xFF34A853)],
      [180.0, 90.0, Color(0xFFFBBC05)],
      [270.0, 90.0, Color(0xFFEA4335)],
    ];

    final paint = Paint()
      ..style       = PaintingStyle.stroke
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
      Rect.fromLTWH(center.dx, center.dy - size.height * 0.15,
          size.width * 0.55, size.height * 0.30),
      whitePaint,
    );

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - size.height * 0.10,
          size.width * 0.50, size.height * 0.20),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}