import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/main_navigation.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/services/notification_service.dart'; // ✅ ADD THIS
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ═══════════════════════════════════════════════════════════════════
// Translations
// ═══════════════════════════════════════════════════════════════════
const _T = {
  'en': {
    'appBarTitle':      'Sign up Verification',
    'heading':          'We just sent an Email',
    'subHeading':       'Enter the security code we just sent to:',
    'verify':           'Verify',
    'noCode':           "Don't receive code?",
    'resend':           'Resend Code',
    'resendIn':         'Resend in',
    'errIncomplete':    'Please enter the complete 6-digit code',
    'errIncorrect':     'Incorrect code. Please check your email and try again.',
    'resendSuccess':    'A new code has been sent to your email',
    'resendFail':       'Failed to resend',
    'errEmailInUse':    'This email is already registered. Please log in instead.',
    'errWeakPassword':  'Password is too weak.',
    'errRegFailed':     'Registration failed.',
    'errGeneric':       'Error',
  },
  'ja': {
    'appBarTitle':      '登録認証',
    'heading':          'メールを送信しました',
    'subHeading':       '以下のアドレスに送信されたセキュリティコードを入力してください：',
    'verify':           '確認する',
    'noCode':           'コードが届きませんでしたか？',
    'resend':           'コードを再送する',
    'resendIn':         '再送まで',
    'errIncomplete':    '6桁のコードをすべて入力してください',
    'errIncorrect':     'コードが間違っています。メールを確認してもう一度お試しください。',
    'resendSuccess':    '新しいコードをメールに送信しました',
    'resendFail':       '再送に失敗しました',
    'errEmailInUse':    'このメールアドレスはすでに登録されています。ログインしてください。',
    'errWeakPassword':  'パスワードが弱すぎます。',
    'errRegFailed':     '登録に失敗しました。',
    'errGeneric':       'エラー',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T['en']![key]) ?? key;

// ═══════════════════════════════════════════════════════════════════
// OtpVerificationPage
// ═══════════════════════════════════════════════════════════════════
class OtpVerificationPage extends ConsumerStatefulWidget {
  final String email;
  final String nickname;
  final String password;
  final String generatedOtp;

  const OtpVerificationPage({
    super.key,
    required this.email,
    required this.nickname,
    required this.password,
    required this.generatedOtp,
  });

  @override
  ConsumerState<OtpVerificationPage> createState() =>
      _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
  List.generate(6, (_) => FocusNode());

  bool   _isVerifying      = false;
  bool   _canResend        = false;
  int    _secondsRemaining = 30;
  Timer? _timer;
  late String _currentOtp;

  // ── EmailJS credentials ───────────────────────────────────────────
  static const String _emailJsServiceId  = 'service_u0cfg9g';
  static const String _emailJsTemplateId = 'template_ndurfap';
  static const String _emailJsPublicKey  = 'wwRoip-Q64dQgUzeH';

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.generatedOtp;
    _startTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Countdown timer ───────────────────────────────────────────────
  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend        = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String get _timerText {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  // ── Send via EmailJS ──────────────────────────────────────────────
  Future<void> _sendOtpEmail({
    required String toEmail,
    required String nickname,
    required String otp,
  }) async {
    const url = 'https://api.emailjs.com/api/v1.0/email/send';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id':  _emailJsServiceId,
        'template_id': _emailJsTemplateId,
        'user_id':     _emailJsPublicKey,
        'template_params': {
          'to_email': toEmail,
          'to_name':  nickname,
          'otp_code': otp,
        },
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('EmailJS error: ${response.body}');
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────
  Future<void> _resendOtp(String lang) async {
    if (!_canResend) return;

    final newOtp = _generateOtp();
    _currentOtp  = newOtp;

    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();

    try {
      await _sendOtpEmail(
        toEmail:  widget.email,
        nickname: widget.nickname,
        otp:      newOtp,
      );
      _startTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(lang, 'resendSuccess'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_t(lang, 'resendFail')}: ${e.toString()}')),
      );
    }
  }

  String _generateOtp() {
    final rand = Random.secure();
    return (100000 + rand.nextInt(900000)).toString();
  }

  // ── Verify OTP & create Firebase account ─────────────────────────
  Future<void> _onVerify(String lang) async {
    final enteredOtp =
    _controllers.map((c) => c.text.trim()).join();

    if (enteredOtp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(lang, 'errIncomplete'))),
      );
      return;
    }

    if (enteredOtp != _currentOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(lang, 'errIncorrect')),
          backgroundColor: Colors.red,
        ),
      );
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // 1. Create Firebase Auth user
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    widget.email,
        password: widget.password,
      );
      final user = credential.user!;

      // 2. Set Auth display name
      await user.updateDisplayName(widget.nickname);

      // 3. Write registration doc — matches web app schema
      await FirebaseFirestore.instance
          .collection('registration')
          .doc(user.uid)
          .set({
        'nickname':    widget.nickname,
        'email':       widget.email,
        'uid':         user.uid,
        'address':     '',
        'description': '',
        'profile_img': '',
        'provider':    'password',
        'createdAt':   FieldValue.serverTimestamp(),
      });

      debugPrint('✅ registration/${user.uid} created successfully');

      // 4. ✅ Save FCM token now that the user has a valid uid.
      //    This writes fcm_token + fcm_tokens to registration/{uid}
      //    so the user can receive push notifications immediately.
      await NotificationService.instance.init();
      debugPrint('✅ FCM token saved for new user ${user.uid}');

      setState(() => _isVerifying = false);
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isVerifying = false);
      String message = _t(lang, 'errRegFailed');
      if (e.code == 'email-already-in-use') {
        message = _t(lang, 'errEmailInUse');
      } else if (e.code == 'weak-password') {
        message = _t(lang, 'errWeakPassword');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      setState(() => _isVerifying = false);
      debugPrint('Error creating account: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_t(lang, 'errGeneric')}: ${e.toString()}')),
      );
    }
  }

  // ── OTP box input handlers ────────────────────────────────────────
  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.length == 6 && index == 0) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = value[i];
      }
      _focusNodes[5].requestFocus();
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t(lang, 'appBarTitle'),
          style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w400),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Heading ────────────────────────────────────────
              Text(
                _t(lang, 'heading'),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                _t(lang, 'subHeading'),
                style: const TextStyle(
                    fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 1),

              // ── Six OTP boxes ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) => _onKeyEvent(event, index),
                    child: SizedBox(
                      width: 48,
                      height: 56,
                      child: TextFormField(
                        controller:   _controllers[index],
                        focusNode:    _focusNodes[index],
                        textAlign:    TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength:    index == 0 ? 6 : 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2.5),
                          ),
                        ),
                        onChanged: (value) =>
                            _onOtpChanged(value, index),
                      ),
                    ),
                  );
                }),
              ),

              const Spacer(flex: 1),

              // ── Verify button ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isVerifying
                      ? null
                      : () => _onVerify(lang),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5))
                      : Text(
                    _t(lang, 'verify'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Resend ─────────────────────────────────────────
              Column(children: [
                Text(
                  _t(lang, 'noCode'),
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _canResend
                      ? () => _resendOtp(lang)
                      : null,
                  child: Text(
                    _canResend
                        ? _t(lang, 'resend')
                        : '${_t(lang, 'resendIn')} $_timerText',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _canResend
                          ? AppColors.primary
                          : Colors.black87,
                    ),
                  ),
                ),
              ]),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}