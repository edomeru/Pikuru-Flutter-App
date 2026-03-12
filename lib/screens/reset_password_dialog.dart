import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';

/// Call this from anywhere to show the reset password flow.
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

class _ResetPasswordDialog extends StatefulWidget {
  final String prefillEmail;
  const _ResetPasswordDialog({this.prefillEmail = ''});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefillEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<String?> _getProviderForEmail(String email) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('registration')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      final provider = (q.docs.first.data()['provider'] ?? '').toString().trim();
      return provider.isEmpty ? null : provider;
    } catch (_) {
      return null;
    }
  }

  // ── Replace the current dialog with the info dialog ───────────────────
  // Using pushReplacement fixes the "Got it" not closing bug — the old
  // approach (pop + showDialog) left a stale context.
  void _replaceWithInfo({
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
          title: title,
          message: message,
          icon: icon,
          isSuccess: isSuccess,
        ),
      ),
    );
  }

  Future<void> _onSendLink() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // ── Step 1: Check currently signed-in user ────────────────────
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email?.toLowerCase() == email) {
        final ids = currentUser.providerData.map((p) => p.providerId).toList();
        if (ids.contains('google.com') && !ids.contains('password')) {
          _replaceWithInfo(
            title: 'Google Account',
            message: 'This email uses Google Sign-In — there is no password to reset.\n\n'
                'To change your Google password, visit myaccount.google.com.\n\n'
                'Then tap "Sign in with Google" on the login screen.',
            icon: const _GoogleLogoIcon(),
          );
          return;
        }
        if (ids.contains('apple.com') && !ids.contains('password')) {
          _replaceWithInfo(
            title: 'Apple Account',
            message: 'This email uses Apple Sign-In — there is no password to reset.\n\n'
                'To change your Apple ID password, visit appleid.apple.com.\n\n'
                'Then tap "Sign in with Apple" on the login screen.',
            icon: const Icon(Icons.apple, color: Colors.black87, size: 32),
          );
          return;
        }
      }

      // ── Step 2: Check Firestore registration doc ──────────────────
      final provider = await _getProviderForEmail(email);

      if (provider == 'google.com') {
        _replaceWithInfo(
          title: 'Google Account',
          message: 'This email uses Google Sign-In — there is no password to reset.\n\n'
              'To change your Google password, visit myaccount.google.com.\n\n'
              'Then tap "Sign in with Google" on the login screen.',
          icon: const _GoogleLogoIcon(),
        );
        return;
      }

      if (provider == 'apple.com') {
        _replaceWithInfo(
          title: 'Apple Account',
          message: 'This email uses Apple Sign-In — there is no password to reset.\n\n'
              'To change your Apple ID password, visit appleid.apple.com.\n\n'
              'Then tap "Sign in with Apple" on the login screen.',
          icon: const Icon(Icons.apple, color: Colors.black87, size: 32),
        );
        return;
      }

      // ── Step 3: Email/password — send reset ───────────────────────
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _replaceWithInfo(
        title: 'Check your inbox',
        message: 'A reset link has been sent to:\n$email\n\n'
            'Check your spam folder if it doesn\'t arrive within a minute.',
        icon: const Icon(Icons.mark_email_read_outlined,
            color: AppColors.primary, size: 32),
        isSuccess: true,
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          _replaceWithInfo(
            title: 'Check your inbox',
            message: 'If an account exists for $email, a reset link has been sent.',
            icon: const Icon(Icons.mark_email_read_outlined,
                color: AppColors.primary, size: 32),
            isSuccess: true,
          );
          return;
        case 'invalid-email':
          msg = 'That doesn\'t look like a valid email address.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please wait a few minutes and try again.';
          break;
        default:
          msg = 'Something went wrong (${e.code}). Please try again.';
      }
      if (mounted) setState(() => _errorMessage = msg);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Reset Password',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              Text(
                "Enter your email and we'll send you a reset link.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.45),
                    height: 1.5),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _onSendLink(),
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: AppColors.primary, size: 20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.red.shade300),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: Colors.red.shade400, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(val.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade400, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.red.shade600)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _onSendLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: _loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : const Text('Send Link',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info / result dialog ──────────────────────────────────────────────────────
class _InfoDialog extends StatelessWidget {
  final String title;
  final String message;
  final Widget icon;
  final bool isSuccess;

  const _InfoDialog({
    required this.title,
    required this.message,
    required this.icon,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Center(child: icon),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.5),
                    height: 1.55)),
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
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Got it',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Google coloured G logo ────────────────────────────────────────────────────
class _GoogleLogoIcon extends StatelessWidget {
  const _GoogleLogoIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
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