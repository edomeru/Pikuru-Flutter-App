import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/main_navigation.dart';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String nickname;   // ← replaces firstName + lastName
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
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

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

  // ── Resend OTP ────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
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
        const SnackBar(content: Text('A new code has been sent to your email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend: ${e.toString()}')),
      );
    }
  }

  String _generateOtp() {
    final rand = Random.secure();
    return (100000 + rand.nextInt(900000)).toString();
  }

  // ── Send via EmailJS ──────────────────────────────────────────────
  // The template uses {{to_name}} for the greeting — we pass nickname there.
  // The Cloud Function also accepts 'firstName' as the greeting param;
  // we keep passing nickname so existing templates work without changes.
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

  // ── Verify OTP & create Firebase account ─────────────────────────
  Future<void> _onVerify() async {
    final enteredOtp = _controllers.map((c) => c.text.trim()).join();

    if (enteredOtp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 6-digit code')),
      );
      return;
    }

    if (enteredOtp != _currentOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect code. Please check your email and try again.'),
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

      // 3. Write registration doc — 'nickname' field matches web app schema.
      //    No firstName/lastName split; single field keeps things consistent
      //    with the web app's registration collection.
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

      setState(() => _isVerifying = false);
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isVerifying = false);
      String message = 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered. Please log in instead.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      setState(() => _isVerifying = false);
      debugPrint('Error creating account: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // ── OTP box input handlers ────────────────────────────────────────
  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Handle paste of full 6-digit code into the first box
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

  String get _timerText {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sign up Verification Screen',
          style: TextStyle(
              color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w400),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              const Text(
                'We just sent an Email',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              const Text(
                'Enter the security code we just sent to:',
                style: TextStyle(fontSize: 14, color: Colors.black54),
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
                                color: AppColors.primary, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2.5),
                          ),
                        ),
                        onChanged: (value) => _onOtpChanged(value, index),
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
                  onPressed: _isVerifying ? null : _onVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : const Text('Verify',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Resend ─────────────────────────────────────────
              Column(children: [
                const Text("Don't receive code?",
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _canResend ? _resendOtp : null,
                  child: Text(
                    _canResend ? 'Resend Code' : 'Resend in $_timerText',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _canResend ? AppColors.primary : Colors.black87,
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