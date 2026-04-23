import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/loginpage.dart';
import 'package:pikuru/otp_verification_page.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';

// ═══════════════════════════════════════════════════════════════════
// Translations  (mirrors web app T object)
// ═══════════════════════════════════════════════════════════════════
const _T = {
  'en': {
    'title':           'Create\nAccount',
    'nickname':        'Nickname / Username',
    'email':           'Email',
    'password':        'Password',
    'confirmPassword': 'Confirm Password',
    'agree':           'I agree to the Terms & Conditions and Privacy Policy',
    'signUp':          'Sign up',
    'alreadyHave':     'Already have an account?',
    'login':           'Login',
    'submitting':      'Sending code…',
    'errorMatch':      'Passwords do not match',
    'errorAgree':      'You must agree to the terms first',
    'errorRequired':   'Required',
    'errorMinPw':      'Min 6 characters',
    'errorEmail':      'Invalid email',
    'errorGeneric':    'Something went wrong. Please try again.',
    'codeSent':        'Verification code sent!',
    'errorSend':       'Failed to send code',
  },
  'ja': {
    'title':           'アカウント\n作成',
    'nickname':        'Nickname / Username',
    'email':           'メールアドレス',
    'password':        'パスワード',
    'confirmPassword': 'パスワード確認',
    'agree':           '利用規約とプライバシーポリシーに同意します',
    'signUp':          '登録する',
    'alreadyHave':     'すでにアカウントをお持ちですか？',
    'login':           'ログイン',
    'submitting':      'コードを送信中…',
    'errorMatch':      'パスワードが一致しません',
    'errorAgree':      '利用規約に同意してください',
    'errorRequired':   '必須項目です',
    'errorMinPw':      '6文字以上で入力してください',
    'errorEmail':      'メールアドレスが無効です',
    'errorGeneric':    'エラーが発生しました。もう一度お試しください。',
    'codeSent':        '確認コードを送信しました！',
    'errorSend':       'コードの送信に失敗しました',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T['en']![key]) ?? key;

// ═══════════════════════════════════════════════════════════════════
// RegisterPage — ConsumerStatefulWidget
// ═══════════════════════════════════════════════════════════════════
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nicknameController        = TextEditingController();
  final TextEditingController _emailController           = TextEditingController();
  final TextEditingController _passwordController        = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;
  late Animation<double>   _fadeAnimation;

  bool _agree               = false;
  bool _showPassword        = false;
  bool _showConfirmPassword = false;
  bool _showSpinner         = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(
        parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── OTP generator ─────────────────────────────────────────────────────────
  String _generateOtp() {
    final rand = Random.secure();
    return (100000 + rand.nextInt(900000)).toString();
  }

  // ── Send OTP via Cloud Function ───────────────────────────────────────────
  Future<void> _sendOtpViaCloudFunction({
    required String toEmail,
    required String nickname,
    required String otp,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('sendOtp');
    await callable.call({
      'email':     toEmail,
      'firstName': nickname,
      'otp':       otp,
    });
  }

  // ── Submit handler ────────────────────────────────────────────────────────
  Future<void> _onSignUp(String lang) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(lang, 'errorAgree'))),
      );
      return;
    }

    setState(() => _showSpinner = true);

    try {
      final email    = _emailController.text.trim();
      final nickname = _nicknameController.text.trim();
      final password = _passwordController.text;
      final otp      = _generateOtp();

      await _sendOtpViaCloudFunction(
          toEmail: email, nickname: nickname, otp: otp);

      setState(() => _showSpinner = false);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            email:        email,
            nickname:     nickname,
            password:     password,
            generatedOtp: otp,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() => _showSpinner = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_t(lang, 'errorSend')}: ${e.message}')),
      );
    } catch (e) {
      setState(() => _showSpinner = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t(lang, 'errorGeneric')}: $e')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: ModalProgressHUD(
        inAsyncCall: _showSpinner,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeader(lang),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // ── Nickname ───────────────────────────────────────
                        TextFormField(
                          controller: _nicknameController,
                          decoration: _inputDecoration(
                              _t(lang, 'nickname')),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? _t(lang, 'errorRequired')
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // ── Email ──────────────────────────────────────────
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(_t(lang, 'email')),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return _t(lang, 'errorRequired');
                            }
                            if (!v.contains('@')) {
                              return _t(lang, 'errorEmail');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Password ───────────────────────────────────────
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          decoration:
                          _inputDecoration(_t(lang, 'password')).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return _t(lang, 'errorRequired');
                            }
                            if (v.length < 6) {
                              return _t(lang, 'errorMinPw');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Confirm Password ───────────────────────────────
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_showConfirmPassword,
                          decoration: _inputDecoration(
                              _t(lang, 'confirmPassword'))
                              .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() =>
                              _showConfirmPassword =
                              !_showConfirmPassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return _t(lang, 'errorRequired');
                            }
                            if (v != _passwordController.text) {
                              return _t(lang, 'errorMatch');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Terms checkbox ─────────────────────────────────
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agree,
                                onChanged: (v) =>
                                    setState(() => _agree = v ?? false),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                side: const BorderSide(color: Colors.grey),
                                activeColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _t(lang, 'agree'),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Sign up row ────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(_t(lang, 'signUp'),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => _onSignUp(lang),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black87, width: 2)),
                                child: const Icon(Icons.arrow_forward,
                                    color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  _buildFooter(context, lang),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(String lang) {
    return ClipPath(
      clipper: _RegisterHeaderClipper(),
      child: Container(
        width: double.infinity,
        height: 280,
        color: AppColors.primary,
        child: Stack(
          children: [
            Positioned(
              right: 24,
              bottom: 40,
              child: SizedBox(
                height: 160,
                child: Image.asset('assets/pikuru_logo_dog.png',
                    fit: BoxFit.contain),
              ),
            ),
            Positioned(
              left: 28,
              bottom: 56,
              child: Text(
                _t(lang, 'title'),
                style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context, String lang) {
    return ClipPath(
      clipper: _BottomCurveClipper(),
      child: Container(
        width: double.infinity,
        color: AppColors.primary,
        padding: const EdgeInsets.only(top: 56, bottom: 40),
        child: Column(
          children: [
            Text(
              _t(lang, 'alreadyHave'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => LoginScreen())),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _t(lang, 'login'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.arrow_forward,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Input decoration helper (file-level, matches original)
// ═══════════════════════════════════════════════════════════════════
InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
        color: Colors.black, fontWeight: FontWeight.bold),
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
        const BorderSide(color: AppColors.primary, width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
        const BorderSide(color: AppColors.primary, width: 2)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2)),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Clippers
// ═══════════════════════════════════════════════════════════════════
class _RegisterHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 80);
    path.quadraticBezierTo(size.width * 0.9, size.height * 1.5,
        size.width + 300, size.height - 250);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.55, -size.height * 0.15,
        size.width, size.height * 0.1);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}