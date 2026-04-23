import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/email_verification_screen.dart';
import 'dart:math';

// ═══════════════════════════════════════════════════════════════════
// Localization strings
// ═══════════════════════════════════════════════════════════════════
const _T = {
  kLangEn: {
    // ChangeEmailScreen
    'changeAppBar':       'Change Email',
    'changeHeaderTitle':  'Update Email ✉️',
    'changeHeaderSub':    'A verification code will be sent to your new email',
    'sectionLabel':       'Email Address',
    'currentEmail':       'Current Email',
    'newEmail':           'New Email',
    'infoBanner':         'A 6-digit verification code will be sent to your new email address.',
    'sendCode':           'Send Verification Code',
    'errCurrentRequired': 'Required',
    'errCurrentInvalid':  'Invalid email',
    'errNewRequired':     'New email is required',
    'errNewInvalid':      'Enter a valid email address',
    'errEmailMismatch':   'Current email does not match your account.',
    'errSameEmail':       'New email must be different from current email.',
    'errSendFail':        'Failed to send verification code. Please try again.',
    // ChangeEmailVerificationScreen
    'verifyAppBar':       'Verify Email',
    'verifyHeaderTitle':  'Check Your Inbox 📬',
    'verifyHeaderSub':    'Code sent to',
    'verifyPageTitle':    'Email Verification',
    'verifyPageSub':      'Please enter the 6-digit code sent to your email address',
    'verify':             'Verify',
    'noCode':             "Don't receive code?",
    'resendIn':           'Resend in',
    'resend':             'Resend Code',
    'errAllDigits':       'Please enter all 6 digits.',
    'errIncorrect':       'Incorrect code. Please try again.',
    'errSendOtp':         'Failed to send code. Please try again.',
    'errVerifyFail':      'Something went wrong. Please try again.',
    // Success dialog
    'successTitle':       'Email Updated!',
    'successBody':        'Your email has been changed to\n{email}',
    'done':               'Done',
  },
  kLangJa: {
    // ChangeEmailScreen
    'changeAppBar':       'メールアドレス変更',
    'changeHeaderTitle':  'メールアドレスを更新 ✉️',
    'changeHeaderSub':    '新しいメールアドレスに確認コードが送信されます',
    'sectionLabel':       'メールアドレス',
    'currentEmail':       '現在のメールアドレス',
    'newEmail':           '新しいメールアドレス',
    'infoBanner':         '新しいメールアドレスに6桁の確認コードが送信されます。',
    'sendCode':           '確認コードを送信',
    'errCurrentRequired': '必須項目です',
    'errCurrentInvalid':  '無効なメールアドレスです',
    'errNewRequired':     '新しいメールアドレスを入力してください',
    'errNewInvalid':      '有効なメールアドレスを入力してください',
    'errEmailMismatch':   '現在のメールアドレスがアカウントと一致しません。',
    'errSameEmail':       '新しいメールアドレスは現在と異なるものを入力してください。',
    'errSendFail':        '確認コードの送信に失敗しました。もう一度お試しください。',
    // ChangeEmailVerificationScreen
    'verifyAppBar':       'メール認証',
    'verifyHeaderTitle':  'メールを確認してください 📬',
    'verifyHeaderSub':    'コードを送信しました：',
    'verifyPageTitle':    'メール認証',
    'verifyPageSub':      'メールアドレスに送信された6桁のコードを入力してください',
    'verify':             '確認する',
    'noCode':             'コードが届きませんでしたか？',
    'resendIn':           '再送まで',
    'resend':             'コードを再送する',
    'errAllDigits':       '6桁のコードをすべて入力してください。',
    'errIncorrect':       'コードが間違っています。もう一度お試しください。',
    'errSendOtp':         'コードの送信に失敗しました。もう一度お試しください。',
    'errVerifyFail':      'エラーが発生しました。もう一度お試しください。',
    // Success dialog
    'successTitle':       'メールアドレスを更新しました！',
    'successBody':        'メールアドレスを以下に変更しました：\n{email}',
    'done':               '完了',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T[kLangEn]![key]) ?? key;

String _fillEmail(String template, String email) =>
    template.replaceAll('{email}', email);

// ═══════════════════════════════════════════════════════════════════
// ChangeEmailScreen
// ═══════════════════════════════════════════════════════════════════
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() =>
      _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset>   _slideAnim;

  final _formKey                = GlobalKey<FormState>();
  final _currentEmailController = TextEditingController();
  final _newEmailController     = TextEditingController();
  final _currentEmailFocus      = FocusNode();
  final _newEmailFocus          = FocusNode();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

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

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      _currentEmailController.text = user!.email!;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _currentEmailController.dispose();
    _newEmailController.dispose();
    _currentEmailFocus.dispose();
    _newEmailFocus.dispose();
    super.dispose();
  }

  String _generateOtp() {
    final rand = Random.secure();
    return (100000 + rand.nextInt(900000)).toString();
  }

  Future<void> _confirm(String lang) async {
    if (!_formKey.currentState!.validate()) return;

    final user         = FirebaseAuth.instance.currentUser;
    final currentEmail = _currentEmailController.text.trim();
    final newEmail     = _newEmailController.text.trim();

    if (user?.email?.toLowerCase() != currentEmail.toLowerCase()) {
      _showSnackBar(message: _t(lang, 'errEmailMismatch'), isError: true);
      return;
    }

    if (currentEmail.toLowerCase() == newEmail.toLowerCase()) {
      _showSnackBar(message: _t(lang, 'errSameEmail'), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final otp = _generateOtp();

      String firstName = '';
      final displayName = user?.displayName ?? '';
      if (displayName.trim().isNotEmpty) {
        firstName = displayName.trim().split(' ').first;
      }

      if (firstName.isEmpty && user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('registration')
              .doc(user.uid)
              .get();
          if (doc.exists) {
            firstName =
                (doc.data()?['firstName'] ?? '').toString().trim();
          }
        } catch (e) {
          debugPrint('Firestore fallback failed: $e');
        }
      }

      if (firstName.isEmpty) firstName = 'User';

      await FirebaseFunctions.instance.httpsCallable('sendOtp').call({
        'email':     newEmail,
        'firstName': firstName,
        'otp':       otp,
      });

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            newEmail:     newEmail,
            generatedOtp: otp,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(message: _t(lang, 'errSendFail'), isError: true);
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_rounded : Icons.check_circle_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor:
        isError ? Colors.red.shade400 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watches the global provider — rebuilds whenever language changes
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────
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
              _t(lang, 'changeAppBar'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  letterSpacing: 0.3),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
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
                          _t(lang, 'changeHeaderTitle'),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t(lang, 'changeHeaderSub'),
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.72)),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: _t(lang, 'sectionLabel')),
                        const SizedBox(height: 12),

                        // ── Fields Card ──────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.12)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(children: [
                            _EmailField(
                              controller: _currentEmailController,
                              focusNode:  _currentEmailFocus,
                              label:    _t(lang, 'currentEmail'),
                              icon:     Icons.email_outlined,
                              readOnly: true,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return _t(lang, 'errCurrentRequired');
                                }
                                if (!v.contains('@')) {
                                  return _t(lang, 'errCurrentInvalid');
                                }
                                return null;
                              },
                            ),
                            Divider(
                              height: 1, thickness: 1, indent: 56,
                              color: AppColors.primary.withOpacity(0.08),
                            ),
                            _EmailField(
                              controller: _newEmailController,
                              focusNode:  _newEmailFocus,
                              label:   _t(lang, 'newEmail'),
                              icon:    Icons.mark_email_unread_outlined,
                              isLast:  true,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return _t(lang, 'errNewRequired');
                                }
                                if (!v.contains('@') || !v.contains('.')) {
                                  return _t(lang, 'errNewInvalid');
                                }
                                return null;
                              },
                            ),
                          ]),
                        ),

                        const SizedBox(height: 16),

                        // ── Info Banner ──────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.15)),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _t(lang, 'infoBanner'),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4),
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 28),

                        // ── Send Button ──────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                            _isLoading ? null : () => _confirm(lang),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5))
                                : Text(
                              _t(lang, 'sendCode'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3),
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
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ChangeEmailVerificationScreen
// ═══════════════════════════════════════════════════════════════════
class ChangeEmailVerificationScreen extends ConsumerStatefulWidget {
  final String newEmail;
  final String firstName;

  const ChangeEmailVerificationScreen({
    super.key,
    required this.newEmail,
    required this.firstName,
  });

  @override
  ConsumerState<ChangeEmailVerificationScreen> createState() =>
      _ChangeEmailVerificationScreenState();
}

class _ChangeEmailVerificationScreenState
    extends ConsumerState<ChangeEmailVerificationScreen>
    with TickerProviderStateMixin {
  // ── OTP state ─────────────────────────────────────────────────────
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
  List.generate(6, (_) => FocusNode());

  String  _generatedOtp = '';
  bool    _isVerifying  = false;
  bool    _isSending    = false;
  String? _errorMsg;

  // ── Countdown ──────────────────────────────────────────────────
  int    _secondsLeft = 60;
  Timer? _timer;

  // ── Animations ────────────────────────────────────────────────
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

    // Read lang once at init time — safe because initState is sync
    // and the provider is already initialised before this widget mounts.
    final lang = ref.read(appLangProvider);
    _sendOtp(lang);
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    _fadeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── OTP helpers ───────────────────────────────────────────────
  String _generateOtp() {
    final rand = DateTime.now().millisecondsSinceEpoch % 1000000;
    return rand.toString().padLeft(6, '0');
  }

  /// Single canonical send method — used from initState and Resend button.
  Future<void> _sendOtp(String lang) async {
    if (!mounted) return;
    setState(() {
      _isSending = true;
      _errorMsg  = null;
    });
    _generatedOtp = _generateOtp();

    try {
      await FirebaseFunctions.instance.httpsCallable('sendOtp').call({
        'email':     widget.newEmail,
        'firstName': widget.firstName,
        'otp':       _generatedOtp,
      });
      if (mounted) _startCountdown();
    } catch (e) {
      if (mounted) setState(() => _errorMsg = _t(lang, 'errSendOtp'));
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

  // ── OTP entry helpers ─────────────────────────────────────────
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

  // ── Verify ────────────────────────────────────────────────────
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

    setState(() { _isVerifying = true; _errorMsg = null; });
    HapticFeedback.lightImpact();

    try {
      await FirebaseFunctions.instance
          .httpsCallable('updateUserEmail')
          .call({'newEmail': widget.newEmail});

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('registration')
            .doc(uid)
            .update({'email': widget.newEmail});
      }

      setState(() => _isVerifying = false);
      HapticFeedback.mediumImpact();

      if (mounted) _showSuccessDialog(lang);
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMsg = e.message ?? _t(lang, 'errVerifyFail');
      });
    } catch (_) {
      setState(() {
        _isVerifying = false;
        _errorMsg    = _t(lang, 'errVerifyFail');
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
                child: const Icon(Icons.mark_email_read_rounded,
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
                _fillEmail(_t(lang, 'successBody'), widget.newEmail),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.45),
                    height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((r) =>
                  r.isFirst || r.settings.name == '/settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    _t(lang, 'done'),
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
    // ✅ Watches the global provider — rebuilds on any language change
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────
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
              _t(lang, 'verifyAppBar'),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
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
                          _t(lang, 'verifyHeaderTitle'),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_t(lang, 'verifyHeaderSub')} ${widget.newEmail}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.72)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const SizedBox(height: 16),

                  // ── Envelope icon ───────────────────────────────
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary))
                        : const Icon(
                        Icons.mark_email_unread_rounded,
                        color: AppColors.primary, size: 38),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    _t(lang, 'verifyPageTitle'),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D0D0D),
                        letterSpacing: -0.3),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _t(lang, 'verifyPageSub'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.45),
                        height: 1.5),
                  ),

                  const SizedBox(height: 36),

                  // ── OTP boxes ───────────────────────────────────
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (context, child) {
                      final offset = (_shakeAnim.value *
                          10 *
                          (1 - _shakeAnim.value))
                          .clamp(-8.0, 8.0);
                      return Transform.translate(
                          offset: Offset(offset * 2, 0), child: child);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        return Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 5),
                          child: _OtpBox(
                            controller: _controllers[i],
                            focusNode:  _focusNodes[i],
                            hasError: _errorMsg != null,
                            onChanged: (v) => _onDigitChanged(i, v),
                            onKeyDown: (e) => _onKeyDown(i, e),
                          ),
                        );
                      }),
                    ),
                  ),

                  // ── Error message ───────────────────────────────
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 14, color: Colors.red.shade400),
                        const SizedBox(width: 4),
                        Text(
                          _errorMsg!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Verify button ───────────────────────────────
                  SizedBox(
                    width: double.infinity, height: 56,
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
                              color: Colors.white, strokeWidth: 2.5))
                          : Text(
                        _t(lang, 'verify'),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Resend section ──────────────────────────────
                  Text(
                    _t(lang, 'noCode'),
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.45)),
                  ),
                  const SizedBox(height: 6),
                  _secondsLeft > 0
                      ? RichText(
                    text: TextSpan(
                      text: '${_t(lang, 'resendIn')} ',
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
                    onTap: _isSending
                        ? null
                        : () => _sendOtp(lang),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _t(lang, 'resend'),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared helper widgets
// ═══════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.1),
      ),
    ]);
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController      controller;
  final FocusNode                  focusNode;
  final String                     label;
  final IconData                   icon;
  final bool                       isLast;
  final bool                       readOnly;
  final TextInputType?             keyboardType;
  final String? Function(String?)? validator;

  const _EmailField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    this.isLast       = false,
    this.readOnly     = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      focusNode:    focusNode,
      readOnly:     readOnly,
      validator:    validator,
      keyboardType: keyboardType,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: readOnly
              ? Colors.grey.shade500
              : const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
            fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(
            color: readOnly ? Colors.grey : AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(icon,
              color: readOnly
                  ? Colors.grey.shade400
                  : AppColors.primary,
              size: 20),
        ),
        prefixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: readOnly
            ? Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Icon(Icons.lock_outline_rounded,
              color: Colors.grey.shade400, size: 16),
        )
            : null,
        border:        InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isLast ? 16 : 0),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isLast ? 16 : 0),
          borderSide:
          BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            vertical: 18, horizontal: 0),
        filled:    readOnly,
        fillColor: readOnly ? Colors.grey.shade50 : null,
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController     controller;
  final FocusNode                 focusNode;
  final bool                      hasError;
  final ValueChanged<String>      onChanged;
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
      onKey:     onKeyDown,
      child: SizedBox(
        width: 46, height: 56,
        child: TextFormField(
          controller:   controller,
          focusNode:    focusNode,
          textAlign:    TextAlign.center,
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
                  color: hasError
                      ? Colors.red.shade400
                      : AppColors.primary,
                  width: 2),
            ),
          ),
        ),
      ),
    );
  }
}