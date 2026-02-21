import 'package:flutter/material.dart';
import 'package:pikuru/register/RegisterPage.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/main_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:pikuru/Utils/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  bool showSpinner = false;
  String email = '';
  String password = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 36),

                    // ── Email ────────────────────────────────────────
                    TextFormField(
                      onChanged: (v) => email = v,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _inputDecoration('Email'),
                    ),

                    const SizedBox(height: 16),

                    // ── Password ─────────────────────────────────────
                    TextFormField(
                      obscureText: true,
                      onChanged: (v) => password = v,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _inputDecoration('Password'),
                    ),

                    const SizedBox(height: 6),

                    // ── Forgot Password ──────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Sign In Button ───────────────────────────────
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
                            String msg = 'Login failed. Please try again.';
                            if (e.code == 'user-not-found') {
                              msg = 'No account found with this email.';
                            } else if (e.code == 'wrong-password') {
                              msg = 'Incorrect password.';
                            } else if (e.code == 'invalid-email') {
                              msg = 'Please enter a valid email address.';
                            }
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          } catch (e) {
                            setState(() => showSpinner = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                              ),
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
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Divider ──────────────────────────────────────
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Or Sign In With',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Google + Apple buttons ───────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _pillButton(
                            onPressed: () async {
                              setState(() => showSpinner = true);
                              final result =
                              await AuthService.signInWithGoogle();
                              setState(() => showSpinner = false);
                              if (result != null) {
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
                                  const SnackBar(
                                    content: Text('Google sign-in failed'),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google G icon using colored letters
                                _googleIcon(),
                                const SizedBox(width: 8),
                                Text(
                                  'Google',
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
                            onPressed: () {
                              // TODO: Apple sign-in
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.apple,
                                  color: Colors.black87,
                                  size: 22,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Apple',
                                  style: TextStyle(
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

                    // ── Sign Up link ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account yet? ",
                          style: TextStyle(
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
                            'Sign Up',
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

  // ── Header: two green circles + Sign In + logo ───────────────────────
  Widget _buildHeader(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // White base
          Container(color: Colors.white),

          // Left circle (darker, larger)
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

          // Right circle (lighter, slightly smaller)
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

          // "Sign In" label
          const Positioned(
            top: 68,
            left: 28,
            child: Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Logo
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

// ── Input decoration ──────────────────────────────────────────────────

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: AppColors.primary.withOpacity(0.6),
        width: 1.4,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: AppColors.primary,
        width: 2.0,
      ),
    ),
  );
}

// ── Pill-shaped social button ─────────────────────────────────────────

Widget _pillButton({
  required VoidCallback onPressed,
  required Widget child,
}) {
  return SizedBox(
    height: 48,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        backgroundColor: Colors.white,
        padding: EdgeInsets.zero,
      ),
      child: child,
    ),
  );
}

// ── Google coloured G icon ────────────────────────────────────────────

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
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = rect.center;
    final radius = size.width / 2;

    // Draw colored arcs: blue, red, yellow, green
    const sweeps = [
      [0.0, 90.0, Color(0xFF4285F4)],   // blue  (right)
      [90.0, 90.0, Color(0xFF34A853)],  // green (bottom)
      [180.0, 90.0, Color(0xFFFBBC05)], // yellow (left)
      [270.0, 90.0, Color(0xFFEA4335)], // red (top)
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

    // White cutout for the "G" gap on the right
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - size.height * 0.15,
          size.width * 0.55, size.height * 0.30),
      whitePaint,
    );

    // Blue horizontal bar of the G
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