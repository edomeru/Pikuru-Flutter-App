import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/change_password_verification_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isVerifying = false; // re-auth in progress

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ── Step 1: re-authenticate, then navigate to OTP screen ─────────
  Future<void> _submit() async {
    // Manually trigger validation and show errors
    final valid = _formKey.currentState!.validate();
    if (!valid) return;

    HapticFeedback.lightImpact();
    setState(() => _isVerifying = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isVerifying = false);
      _showError('You are not logged in. Please sign in again.');
      return;
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      setState(() => _isVerifying = false);
      _showError('No email found on your account.');
      return;
    }

    try {
      // Re-authenticate to verify current password is correct
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPwController.text,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() => _isVerifying = false);
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'user-not-found') {
        _showError('Current password is incorrect.');
      } else if (e.code == 'requires-recent-login') {
        _showError(
            'Please sign out and sign back in before changing your password.');
      } else {
        _showError('Verification failed: ${e.message ?? e.code}');
      }
      return;
    } catch (e) {
      setState(() => _isVerifying = false);
      _showError('Unexpected error: $e');
      return;
    }

    setState(() => _isVerifying = false);

    if (!mounted) return;

    final displayName = (user.displayName ?? '').trim();
    final firstName =
    displayName.isNotEmpty ? displayName.split(' ').first : 'User';

    // Navigate to OTP verification screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangePasswordVerificationScreen(
          email: email,
          firstName: firstName,
          newPassword: _newPwController.text,
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Password strength helpers ──────────────────────────────────────
  double _strength(String pw) {
    if (pw.isEmpty) return 0;
    double s = 0;
    if (pw.length >= 8) s += 0.25;
    if (pw.length >= 12) s += 0.25;
    if (pw.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (pw.contains(RegExp(r'[0-9!@#\$%^&*]'))) s += 0.25;
    return s;
  }

  Color _strengthColor(double s) {
    if (s <= 0.25) return Colors.red.shade400;
    if (s <= 0.5) return Colors.orange.shade400;
    if (s <= 0.75) return Colors.amber.shade400;
    return Colors.green.shade500;
  }

  String _strengthLabel(double s) {
    if (s <= 0.25) return 'Weak';
    if (s <= 0.5) return 'Fair';
    if (s <= 0.75) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    final newPw = _newPwController.text;
    final s = _strength(newPw);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ────────────────────────────────────────
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
            title: const Text('Change Password',
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
                          const Text('Secure Your Account 🔒',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text(
                            'We\'ll send a verification code to confirm',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.72)),
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
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Info banner ────────────────────────
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_user_rounded,
                                  size: 18,
                                  color: Colors.blue.shade400),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'After setting your new password, we\'ll send a verification code to your email to confirm the change.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Form card ─────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                AppColors.primary.withOpacity(0.10)),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                  AppColors.primary.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Current password
                              _FieldLabel(
                                  label: 'Current Password',
                                  icon: Icons.lock_outline_rounded),
                              const SizedBox(height: 8),
                              _PasswordField(
                                controller: _currentPwController,
                                hint: 'Enter current password',
                                visible: _showCurrent,
                                onToggle: () => setState(
                                        () => _showCurrent = !_showCurrent),
                                validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                              ),

                              const SizedBox(height: 20),

                              // New password
                              _FieldLabel(
                                  label: 'New Password',
                                  icon: Icons.lock_reset_rounded),
                              const SizedBox(height: 8),
                              _PasswordField(
                                controller: _newPwController,
                                hint: 'Enter new password',
                                visible: _showNew,
                                onToggle: () =>
                                    setState(() => _showNew = !_showNew),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Required';
                                  }
                                  if (v.length < 6) {
                                    return 'At least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              // Strength indicator
                              if (newPw.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: s,
                                          minHeight: 5,
                                          backgroundColor:
                                          Colors.grey.shade200,
                                          valueColor:
                                          AlwaysStoppedAnimation<
                                              Color>(
                                            _strengthColor(s),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _strengthLabel(s),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _strengthColor(s)),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Confirm password
                              _FieldLabel(
                                  label: 'Confirm New Password',
                                  icon:
                                  Icons.check_circle_outline_rounded),
                              const SizedBox(height: 8),
                              _PasswordField(
                                controller: _confirmPwController,
                                hint: 'Re-enter new password',
                                visible: _showConfirm,
                                onToggle: () => setState(
                                        () => _showConfirm = !_showConfirm),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Required';
                                  }
                                  if (v != _newPwController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Tips row
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                AppColors.primary.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.tips_and_updates_rounded,
                                  size: 16,
                                  color: AppColors.primary
                                      .withOpacity(0.7)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Use 8+ characters with uppercase letters and numbers for a stronger password.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary
                                          .withOpacity(0.8),
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5))
                                : const Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Text('Send Verification Code',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ],
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

// ── Field Label ───────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF444444),
                letterSpacing: 0.1)),
      ],
    );
  }
}

// ── Password Field ────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool visible;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.visible,
    required this.onToggle,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF0D0D0D)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 14, color: Colors.black.withOpacity(0.3)),
        filled: true,
        fillColor: const Color(0xFFF7F9F7),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
            visible
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: AppColors.primary.withOpacity(0.5),
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: AppColors.primary.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: AppColors.primary.withOpacity(0.15)),
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
        errorStyle:
        TextStyle(fontSize: 12, color: Colors.red.shade400),
      ),
    );
  }
}