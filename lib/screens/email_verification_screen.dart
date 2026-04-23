import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'dart:async';
import 'dart:math';

// ═══════════════════════════════════════════════════════════════════
// Translations
// ═══════════════════════════════════════════════════════════════════
const _T = {
  'en': {
    'appBarTitle':       'Verify Email',
    'headerTitle':       'Check your inbox 📬',
    'headerSub':         'Code sent to',
    'pageTitle':         'Email Verification',
    'pageSub':           'Please enter the code sent to your new email address',
    'verify':            'Verify',
    'noCode':            "Don't receive code?",
    'resend':            'Resend Code',
    'resendIn':          'Resend in',
    'errIncomplete':     'Please enter the complete 6-digit code.',
    'errIncorrect':      'Incorrect code. Please check your email and try again.',
    'errNotLoggedIn':    'Not logged in',
    'resendSuccess':     'A new code has been sent to',
    'resendFail':        'Failed to resend code.',
    'updateSuccess':     'Email updated successfully!',
    'updateNewLogin':    'Email updated! Please log in with your new email.',
    'errWrongPassword':  'Incorrect password. Please try again.',
    'errEmailInUse':     'This email is already used by another account.',
    'errInvalidEmail':   'The email address is not valid.',
    'errRecentLogin':    'Session expired. Please log out and try again.',
    'errGeneric':        'Something went wrong',
    // Password dialog
    'dialogTitle':       'Confirm Password',
    'dialogSub':         'Enter your current password to continue.',
    'dialogHint':        'Current password',
    'dialogCancel':      'Cancel',
    'dialogConfirm':     'Confirm',
    'dialogRequired':    'Password is required',
  },
  'ja': {
    'appBarTitle':       'メール認証',
    'headerTitle':       'メールを確認してください 📬',
    'headerSub':         'コードを送信しました：',
    'pageTitle':         'メール認証',
    'pageSub':           '新しいメールアドレスに送信されたコードを入力してください',
    'verify':            '確認する',
    'noCode':            'コードが届きませんでしたか？',
    'resend':            'コードを再送する',
    'resendIn':          '再送まで',
    'errIncomplete':     '6桁のコードをすべて入力してください。',
    'errIncorrect':      'コードが間違っています。メールを確認してもう一度お試しください。',
    'errNotLoggedIn':    'ログインしていません',
    'resendSuccess':     '新しいコードを送信しました：',
    'resendFail':        'コードの再送に失敗しました。',
    'updateSuccess':     'メールアドレスを更新しました！',
    'updateNewLogin':    'メールアドレスを更新しました！新しいメールアドレスでログインしてください。',
    'errWrongPassword':  'パスワードが間違っています。もう一度お試しください。',
    'errEmailInUse':     'このメールアドレスは既に別のアカウントで使用されています。',
    'errInvalidEmail':   'メールアドレスが無効です。',
    'errRecentLogin':    'セッションが切れました。ログアウトして再度お試しください。',
    'errGeneric':        'エラーが発生しました',
    // Password dialog
    'dialogTitle':       'パスワードの確認',
    'dialogSub':         '続けるには現在のパスワードを入力してください。',
    'dialogHint':        '現在のパスワード',
    'dialogCancel':      'キャンセル',
    'dialogConfirm':     '確認',
    'dialogRequired':    'パスワードを入力してください',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T['en']![key]) ?? key;

// ═══════════════════════════════════════════════════════════════════
// EmailVerificationScreen
// ═══════════════════════════════════════════════════════════════════
class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String newEmail;
  final String generatedOtp;

  const EmailVerificationScreen({
    super.key,
    required this.newEmail,
    required this.generatedOtp,
  });

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset>   _slideAnim;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode>             _focusNodes;

  bool   _isVerifying      = false;
  bool   _canResend        = false;
  int    _secondsRemaining = 30;
  Timer? _timer;
  late String _currentOtp;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.generatedOtp;

    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes  = List.generate(6, (_) => FocusNode());

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));

    _startTimer();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    if (_isDisposed) return;
    setState(() {
      _secondsRemaining = 30;
      _canResend        = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isDisposed || !mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _timerText {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<void> _resendOtp(String lang) async {
    if (!_canResend || _isDisposed) return;
    final newOtp = _generateOtp();
    _currentOtp = newOtp;
    for (final c in _controllers) c.clear();
    if (_focusNodes.isNotEmpty && _focusNodes[0].canRequestFocus) {
      _focusNodes[0].requestFocus();
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      String firstName = (user?.displayName ?? '').split(' ').first;
      if (firstName.isEmpty) firstName = 'User';
      await FirebaseFunctions.instance.httpsCallable('sendOtp').call({
        'email':     widget.newEmail,
        'firstName': firstName,
        'otp':       newOtp,
      });
      _startTimer();
      if (!mounted) return;
      _showSnackBar(
          '${_t(lang, 'resendSuccess')} ${widget.newEmail}', false);
    } catch (e) {
      debugPrint('Resend error: $e');
      if (!mounted) return;
      _showSnackBar(_t(lang, 'resendFail'), true);
    }
  }

  String _generateOtp() =>
      (100000 + Random.secure().nextInt(900000)).toString();

  // ── Verify ────────────────────────────────────────────────────────────────
  Future<void> _onVerify(String lang) async {
    if (_isDisposed) return;

    final entered = _controllers.map((c) => c.text.trim()).join();

    if (entered.length < 6) {
      _showSnackBar(_t(lang, 'errIncomplete'), true);
      return;
    }

    if (entered != _currentOtp) {
      _showSnackBar(_t(lang, 'errIncorrect'), true);
      for (final c in _controllers) c.clear();
      if (_focusNodes.isNotEmpty && _focusNodes[0].canRequestFocus) {
        _focusNodes[0].requestFocus();
      }
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception(_t(lang, 'errNotLoggedIn'));
      final userEmail = user.email!;
      final userId    = user.uid;

      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PasswordDialog(lang: lang),
      );

      if (password == null) {
        if (!mounted || _isDisposed) return;
        setState(() => _isVerifying = false);
        return;
      }

      if (!mounted || _isDisposed) return;

      final credential = EmailAuthProvider.credential(
        email:    userEmail,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      await FirebaseFunctions.instance
          .httpsCallable('updateUserEmail')
          .call({'newEmail': widget.newEmail});

      await FirebaseFirestore.instance
          .collection('registration')
          .doc(userId)
          .set({'email': widget.newEmail}, SetOptions(merge: true));

      await FirebaseAuth.instance.currentUser?.reload();

      if (!mounted || _isDisposed) return;
      setState(() => _isVerifying = false);
      _showSnackBar(_t(lang, 'updateSuccess'), false);

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _isDisposed) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (!mounted || _isDisposed) return;

      if (e.code == 'user-token-expired' ||
          e.code == 'invalid-user-token') {
        await FirebaseAuth.instance.signOut();
        if (!mounted || _isDisposed) return;
        _showSnackBar(_t(lang, 'updateNewLogin'), false);
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || _isDisposed) return;
        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }

      setState(() => _isVerifying = false);
      final String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = _t(lang, 'errWrongPassword');
          break;
        case 'email-already-in-use':
          msg = _t(lang, 'errEmailInUse');
          break;
        case 'invalid-email':
          msg = _t(lang, 'errInvalidEmail');
          break;
        case 'requires-recent-login':
          msg = _t(lang, 'errRecentLogin');
          break;
        default:
          msg = '${_t(lang, 'errGeneric')} (${e.code}).';
      }
      _showSnackBar(msg, true);
    } catch (e) {
      debugPrint('Unexpected error: $e');
      if (!mounted || _isDisposed) return;
      setState(() => _isVerifying = false);
      _showSnackBar('${_t(lang, 'errGeneric')}: $e', true);
    }
  }

  void _showSnackBar(String message, bool isError) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor:
        isError ? Colors.red.shade400 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              _t(lang, 'appBarTitle'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
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
                            color: Colors.white.withOpacity(0.06))),
                  ),
                  Positioned(
                    bottom: -20, left: -20,
                    child: Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05))),
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
                            _t(lang, 'headerTitle'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_t(lang, 'headerSub')} ${widget.newEmail}',
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

          // ── Body ───────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      Text(
                        _t(lang, 'pageTitle'),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _t(lang, 'pageSub'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.newEmail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                      const SizedBox(height: 36),

                      // ── OTP boxes ─────────────────────────────────────────
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                              (i) => _OtpBox(
                            controller: _controllers[i],
                            focusNode:  _focusNodes[i],
                            onChanged: (val) {
                              if (val.isNotEmpty && i < 5) {
                                _focusNodes[i + 1].requestFocus();
                              } else if (val.isNotEmpty && i == 5) {
                                _focusNodes[i].unfocus();
                              } else if (val.isEmpty && i > 0) {
                                _focusNodes[i - 1].requestFocus();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Verify button ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isVerifying
                              ? null
                              : () => _onVerify(lang),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14)),
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                              : Text(
                            _t(lang, 'verify'),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Resend ────────────────────────────────────────────
                      Text(
                        _t(lang, 'noCode'),
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 6),
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
                            fontWeight: FontWeight.w700,
                            color: _canResend
                                ? AppColors.primary
                                : Colors.black87,
                            decoration: _canResend
                                ? TextDecoration.underline
                                : null,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// OTP Box
// ═══════════════════════════════════════════════════════════════════
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final ValueChanged<String>  onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode:  focusNode,
        textAlign:  TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.35),
                width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: AppColors.primary, width: 2.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Password Dialog  — receives lang so it can show translated strings
// ═══════════════════════════════════════════════════════════════════
class _PasswordDialog extends StatefulWidget {
  final String lang;
  const _PasswordDialog({required this.lang});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  bool    _obscure = true;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;

    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      contentPadding:
      const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _t(lang, 'dialogTitle'),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            _t(lang, 'dialogSub'),
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: _t(lang, 'dialogHint'),
              hintStyle:
              TextStyle(color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.lock_rounded,
                  color: AppColors.primary, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscure = !_obscure),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.primary.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 2),
              ),
              errorText: _error,
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
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            _t(lang, 'dialogCancel'),
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final pw = _ctrl.text;
            if (pw.isEmpty) {
              setState(
                      () => _error = _t(lang, 'dialogRequired'));
              return;
            }
            Navigator.pop(context, pw);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            _t(lang, 'dialogConfirm'),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}