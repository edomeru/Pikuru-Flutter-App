import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pikuru/theme/material.dart';

/// Shown after the user enters a new email in ChangeEmailScreen.
/// Sends an OTP via the `sendOtp` Cloud Function and verifies it here.
/// On success calls `updateUserEmail` to persist the change.
class ChangeEmailVerificationScreen extends StatefulWidget {
  final String newEmail;
  final String firstName;

  const ChangeEmailVerificationScreen({
    super.key,
    required this.newEmail,
    required this.firstName,
  });

  @override
  State<ChangeEmailVerificationScreen> createState() =>
      _ChangeEmailVerificationScreenState();
}

class _ChangeEmailVerificationScreenState extends State<ChangeEmailVerificationScreen>
    with TickerProviderStateMixin {
  // ── OTP state ─────────────────────────────────────────────────────
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _generatedOtp = '';
  bool _isVerifying = false;
  bool _isSending = false;
  String? _errorMsg;

  // ── Countdown ─────────────────────────────────────────────────────
  int _secondsLeft = 60;
  Timer? _timer;

  // ── Animations ────────────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

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
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));

    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    _fadeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Generate & send OTP ───────────────────────────────────────────
  String _generateOtp() {
    final rand = DateTime.now().millisecondsSinceEpoch % 1000000;
    return rand.toString().padLeft(6, '0');
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _errorMsg = null;
    });

    _generatedOtp = _generateOtp();

    try {
      final fn = FirebaseFunctions.instance.httpsCallable('sendOtp');
      await fn.call({
        'email': widget.newEmail,
        'firstName': widget.firstName,
        'otp': _generatedOtp,
      });

      _startCountdown();
    } catch (e) {
      setState(() => _errorMsg = 'Failed to send code. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // ── OTP entry helpers ─────────────────────────────────────────────
  String get _enteredOtp =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste
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

  // ── Verify ────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_enteredOtp.length < 6) {
      setState(() => _errorMsg = 'Please enter all 6 digits.');
      _shakeController.forward(from: 0);
      return;
    }

    if (_enteredOtp != _generatedOtp) {
      setState(() => _errorMsg = 'Incorrect code. Please try again.');
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();
      // Clear fields
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMsg = null;
    });
    HapticFeedback.lightImpact();

    try {
      // Call updateUserEmail Cloud Function
      final fn =
      FirebaseFunctions.instance.httpsCallable('updateUserEmail');
      await fn.call({'newEmail': widget.newEmail});

      // Also update email in registration doc
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('registration')
            .doc(uid)
            .update({'email': widget.newEmail});
      }

      setState(() => _isVerifying = false);
      HapticFeedback.mediumImpact();

      if (mounted) _showSuccessDialog();
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMsg = e.message ?? 'Failed to update email.';
      });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMsg = 'Something went wrong. Please try again.';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Email Updated!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D0D0D))),
              const SizedBox(height: 10),
              Text(
                'Your email has been changed to\n${widget.newEmail}',
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
                    // Pop dialog + verification screen + email screen
                    Navigator.of(context)
                        .popUntil((r) => r.isFirst || r.settings.name == '/settings');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
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
            title: const Text('Verify Email',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
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
                          const Text('Check Your Inbox 📬',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text(
                            'Code sent to ${widget.newEmail}',
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

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ── Envelope icon ─────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
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
                          : const Icon(Icons.mark_email_unread_rounded,
                          color: AppColors.primary, size: 38),
                    ),

                    const SizedBox(height: 20),

                    const Text('Email Verification',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D0D0D),
                            letterSpacing: -0.3)),

                    const SizedBox(height: 8),

                    Text(
                      'Please enter the 6-digit code sent to your email address',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.45),
                          height: 1.5),
                    ),

                    const SizedBox(height: 36),

                    // ── OTP boxes ─────────────────────────────────
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
                            padding:
                            const EdgeInsets.symmetric(horizontal: 5),
                            child: _OtpBox(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              hasError: _errorMsg != null,
                              onChanged: (v) => _onDigitChanged(i, v),
                              onKeyDown: (e) => _onKeyDown(i, e),
                            ),
                          );
                        }),
                      ),
                    ),

                    // ── Error message ─────────────────────────────
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

                    // ── Verify button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_isVerifying || _isSending)
                            ? null
                            : _verify,
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
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                            : const Text('Verify',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Resend ────────────────────────────────────
                    Text(
                      "Don't receive code?",
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.45)),
                    ),
                    const SizedBox(height: 6),
                    _secondsLeft > 0
                        ? RichText(
                      text: TextSpan(
                        text: 'Resend in ',
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
                        child: const Text(
                          'Resend Code',
                          style: TextStyle(
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

// ── OTP Box ───────────────────────────────────────────────────────────────────
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
        width: 46,
        height: 56,
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6), // allows paste
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