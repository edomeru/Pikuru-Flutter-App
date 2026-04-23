import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localised strings
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'appBarTitle':       'Verify Change',
    'heroTitle':         'Check Your Inbox 📬',
    'heroSub':           'Code sent to',
    'screenTitle':       'Password Verification',
    'screenSub':         'Enter the 6-digit code sent to your email to confirm the password change',
    'verifyBtn':         'Verify & Update Password',
    'dontReceive':       "Don't receive code?",
    'resendIn':          'Resend in ',
    'resendBtn':         'Resend Code',
    'successTitle':      'Password Updated!',
    'successSub':        'Your password has been changed successfully.',
    'doneBtn':           'Done',
    'errAllDigits':      'Please enter all 6 digits.',
    'errIncorrect':      'Incorrect code. Please try again.',
    'errSendFailed':     'Failed to send code. Please try again.',
    'errWeakPassword':   'Password is too weak. Please choose a stronger one.',
    'errSessionExpired': 'Session expired. Please sign out and sign back in, then try again.',
    'errUpdateFailed':   'Failed to update password. Please try again.',
    'errGeneric':        'Something went wrong. Please try again.',
  },
  kLangJa: {
    'appBarTitle':       '変更を確認',
    'heroTitle':         'メールをご確認ください 📬',
    'heroSub':           '認証コードを送信しました：',
    'screenTitle':       'パスワード確認',
    'screenSub':         'パスワード変更を確認するために、メールに送信された6桁のコードを入力してください',
    'verifyBtn':         '確認してパスワードを更新',
    'dontReceive':       'コードが届きませんか？',
    'resendIn':          '再送信まで ',
    'resendBtn':         'コードを再送信',
    'successTitle':      'パスワードを更新しました！',
    'successSub':        'パスワードが正常に変更されました。',
    'doneBtn':           '完了',
    'errAllDigits':      '6桁すべて入力してください。',
    'errIncorrect':      'コードが正しくありません。もう一度お試しください。',
    'errSendFailed':     'コードの送信に失敗しました。もう一度お試しください。',
    'errWeakPassword':   'パスワードが弱すぎます。より強力なパスワードを選んでください。',
    'errSessionExpired': 'セッションが期限切れです。サインアウトして再度サインインしてからお試しください。',
    'errUpdateFailed':   'パスワードの更新に失敗しました。もう一度お試しください。',
    'errGeneric':        'エラーが発生しました。もう一度お試しください。',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// ChangePasswordVerificationScreen — ConsumerStatefulWidget
// ─────────────────────────────────────────────────────────────────────────────
class ChangePasswordVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String firstName;
  final String newPassword;

  const ChangePasswordVerificationScreen({
    super.key,
    required this.email,
    required this.firstName,
    required this.newPassword,
  });

  @override
  ConsumerState<ChangePasswordVerificationScreen> createState() =>
      _ChangePasswordVerificationScreenState();
}

class _ChangePasswordVerificationScreenState
    extends ConsumerState<ChangePasswordVerificationScreen>
    with TickerProviderStateMixin {
  // ── OTP state ─────────────────────────────────────────────────────────────
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
  List.generate(6, (_) => FocusNode());

  String _generatedOtp = '';
  bool   _isVerifying  = false;
  bool   _isSending    = false;
  String? _errorMsg;

  // ── Countdown ─────────────────────────────────────────────────────────────
  int    _secondsLeft = 60;
  Timer? _timer;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _shakeController;
  late final Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _shakeController, curve: Curves.elasticIn));

    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes)  f.dispose();
    _timer?.cancel();
    _fadeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Generate & send OTP ───────────────────────────────────────────────────
  String _generateOtp() {
    final rand = DateTime.now().millisecondsSinceEpoch % 1000000;
    return rand.toString().padLeft(6, '0');
  }

  Future<void> _sendOtp() async {
    // Read lang at call time — safe because we only need it for error strings
    final lang = ref.read(appLangProvider);
    setState(() {
      _isSending = true;
      _errorMsg  = null;
    });

    _generatedOtp = _generateOtp();

    try {
      final fn = FirebaseFunctions.instance.httpsCallable('sendOtp');
      await fn.call({
        'email':     widget.email,
        'firstName': widget.firstName,
        'otp':       _generatedOtp,
      });
      _startCountdown();
    } catch (e) {
      setState(() => _errorMsg = _t(lang, 'errSendFailed'));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── OTP entry helpers ─────────────────────────────────────────────────────
  String get _enteredOtp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      _focusNodes[5].requestFocus();
      setState(() {});
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  // ── Verify OTP then update password ──────────────────────────────────────
  Future<void> _verify(String lang) async {
    if (_enteredOtp.length < 6) {
      setState(() => _errorMsg = _t(lang, 'errAllDigits'));
      _shakeController.forward(from: 0);
      return;
    }

    if (_enteredOtp != _generatedOtp) {
      setState(() => _errorMsg = _t(lang, 'errIncorrect'));
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMsg    = null;
    });
    HapticFeedback.lightImpact();

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await user.updatePassword(widget.newPassword);
      setState(() => _isVerifying = false);
      HapticFeedback.mediumImpact();
      if (mounted) _showSuccessDialog(lang);
    } on FirebaseAuthException catch (e) {
      setState(() => _isVerifying = false);
      String msg;
      if (e.code == 'requires-recent-login') {
        msg = _t(lang, 'errSessionExpired');
      } else if (e.code == 'weak-password') {
        msg = _t(lang, 'errWeakPassword');
      } else {
        msg = _t(lang, 'errUpdateFailed');
      }
      setState(() => _errorMsg = msg);
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMsg    = _t(lang, 'errGeneric');
      });
    }
  }

  void _showSuccessDialog(String lang) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_open_rounded,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                _t(lang, 'successTitle'),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D0D0D)),
              ),
              const SizedBox(height: 10),
              Text(
                _t(lang, 'successSub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.45),
                    height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil(
                            (r) => r.isFirst ||
                            r.settings.name == '/settings');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    _t(lang, 'doneBtn'),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _countdownLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch global lang provider — rebuilds whenever lang changes anywhere
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            title: Text(
              _t(lang, 'appBarTitle'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.85),
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -40, right: -30,
                    child: Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06)),
                    ),
                  ),
                  Positioned(
                    bottom: -20, left: -20,
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: 24,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _t(lang, 'heroTitle'),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_t(lang, 'heroSub')} ${widget.email}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.72)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Icon
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? Padding(
                        padding: const EdgeInsets.all(22),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary),
                      )
                          : const Icon(Icons.lock_reset_rounded,
                          color: AppColors.primary, size: 38),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      _t(lang, 'screenTitle'),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D0D0D),
                          letterSpacing: -0.3),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _t(lang, 'screenSub'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.45),
                          height: 1.5),
                    ),

                    const SizedBox(height: 36),

                    // OTP boxes
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (context, child) {
                        final offset =
                        (_shakeAnim.value * 10 * (1 - _shakeAnim.value))
                            .clamp(-8.0, 8.0);
                        return Transform.translate(
                            offset: Offset(offset * 2, 0),
                            child: child);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5),
                            child: _OtpBox(
                              controller: _controllers[i],
                              focusNode:  _focusNodes[i],
                              hasError:   _errorMsg != null,
                              onChanged:  (v) => _onDigitChanged(i, v),
                              onKeyDown:  (e) => _onKeyDown(i, e),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Error message
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 14, color: Colors.red.shade400),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _errorMsg!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade400,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_isVerifying || _isSending)
                            ? null
                            : () => _verify(lang),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5))
                            : Text(
                          _t(lang, 'verifyBtn'),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Resend section
                    Text(
                      _t(lang, 'dontReceive'),
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.45)),
                    ),
                    const SizedBox(height: 6),
                    _secondsLeft > 0
                        ? RichText(
                      text: TextSpan(
                        text: _t(lang, 'resendIn'),
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.45)),
                        children: [
                          TextSpan(
                            text: _countdownLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    )
                        : GestureDetector(
                      onTap: _isSending ? null : _sendOtp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _t(lang, 'resendBtn'),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP Box (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<RawKeyEvent> onKeyDown;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onKeyDown,
  });

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: onKeyDown,
      child: SizedBox(
        width: 46, height: 56,
        child: TextFormField(
          controller: controller,
          focusNode:  focusNode,
          textAlign:  TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary),
          decoration: InputDecoration(
            filled: true,
            fillColor: controller.text.isNotEmpty
                ? AppColors.primary.withOpacity(0.07)
                : const Color(0xFFF7F9F7),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError
                      ? Colors.red.shade400
                      : AppColors.primary.withOpacity(0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError
                      ? Colors.red.shade300
                      : AppColors.primary.withOpacity(0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError ? Colors.red.shade400 : AppColors.primary,
                  width: 2),
            ),
          ),
        ),
      ),
    );
  }
}