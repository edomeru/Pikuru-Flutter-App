import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localised strings — mirrors the web app's T map in contact/page.tsx
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'pageTitle':    'Contact Us',
    'heroTitle':    'Get in Touch 💬',
    'heroSub':      "We'd love to hear from you",
    'infoBanner':   'Our team typically responds within 24–48 hours.',
    'nameLabel':    'Your Name',
    'nameHint':     'Enter your full name',
    'emailLabel':   'Email Address',
    'emailHint':    'Enter your email',
    'messageLabel': 'Message',
    'messageHint':  'How can we help you?',
    'sendBtn':      'Send Message',
    'successTitle': 'Message Sent!',
    'successSub':   "Thanks for reaching out. We'll get back to you within 24–48 hours.",
    'goBackBtn':    'Go Back',
    'errName':      'Name is required',
    'errEmail':     'Enter a valid email',
    'errMessage':   'Message is too short (min 10 characters)',
    'errSubmit':    'Failed to send message. Please try again.',
  },
  kLangJa: {
    'pageTitle':    'お問い合わせ',
    'heroTitle':    'ご連絡ください 💬',
    'heroSub':      '皆様からのメッセージをお待ちしております',
    'infoBanner':   '通常24〜48時間以内に担当者より返信いたします。',
    'nameLabel':    'お名前',
    'nameHint':     'フルネームを入力',
    'emailLabel':   'メールアドレス',
    'emailHint':    'メールアドレスを入力',
    'messageLabel': 'メッセージ',
    'messageHint':  'ご用件をお聞かせください',
    'sendBtn':      '送信する',
    'successTitle': '送信完了！',
    'successSub':   'お問い合わせありがとうございます。24〜48時間以内に返信いたします。',
    'goBackBtn':    '戻る',
    'errName':      'お名前を入力してください',
    'errEmail':     '有効なメールアドレスを入力してください',
    'errMessage':   'メッセージが短すぎます（10文字以上）',
    'errSubmit':    '送信に失敗しました。もう一度お試しください。',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// ContactUsScreen — ConsumerStatefulWidget to watch appLangProvider
// ─────────────────────────────────────────────────────────────────────────────
class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({super.key});

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen>
    with TickerProviderStateMixin {
  final _formKey         = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  bool _submitted    = false;

  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset>   _slideAnim;
  late final AnimationController _successController;
  late final Animation<double>   _successAnim;

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
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));

    _successController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _successAnim = CurvedAnimation(
        parent: _successController, curve: Curves.easeOutBack);

    // Pre-fill from signed-in user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      if (user.displayName != null) {
        _nameController.text = user.displayName!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _submit(String lang) async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('contact_us').add({
        'name':         _nameController.text.trim(),
        'email':        _emailController.text.trim(),
        'message':      _messageController.text.trim(),
        'user_id':      user?.uid ?? '',
        'submitted_at': FieldValue.serverTimestamp(),
        'status':       'unread',
        // Store the language the user was using when they submitted
        'lang':         lang,
      });

      setState(() {
        _isSubmitting = false;
        _submitted    = true;
      });
      _successController.forward();
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        final errMsg = _t(ref.read(appLangProvider), 'errSubmit');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch global lang provider — rebuilds whenever lang changes anywhere
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ────────────────────────────────────────────────────
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
              _t(lang, 'pageTitle'),
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
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _t(lang, 'heroSub'),
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

          // ── Body ────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _submitted
                      ? _SuccessView(
                    animation: _successAnim,
                    lang: lang,
                  )
                      : _FormView(
                    formKey:            _formKey,
                    nameController:     _nameController,
                    emailController:    _emailController,
                    messageController:  _messageController,
                    isSubmitting:       _isSubmitting,
                    lang:               lang,
                    onSubmit:           () => _submit(lang),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Form View — fully localised
// ═══════════════════════════════════════════════════════════════════════════════
class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController messageController;
  final bool isSubmitting;
  final String lang;
  final VoidCallback onSubmit;

  const _FormView({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.messageController,
    required this.isSubmitting,
    required this.lang,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info banner ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border:
              Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t(lang, 'infoBanner'),
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Form card ────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border:
              Border.all(color: AppColors.primary.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                _FieldLabel(
                    label: _t(lang, 'nameLabel'),
                    icon:  Icons.person_outline_rounded),
                const SizedBox(height: 8),
                _InputField(
                  controller: nameController,
                  hint: _t(lang, 'nameHint'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? _t(lang, 'errName')
                      : null,
                ),

                const SizedBox(height: 20),

                // Email
                _FieldLabel(
                    label: _t(lang, 'emailLabel'),
                    icon:  Icons.email_outlined),
                const SizedBox(height: 8),
                _InputField(
                  controller: emailController,
                  hint: _t(lang, 'emailHint'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return _t(lang, 'errEmail');
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return _t(lang, 'errEmail');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Message
                _FieldLabel(
                    label: _t(lang, 'messageLabel'),
                    icon:  Icons.chat_bubble_outline_rounded),
                const SizedBox(height: 8),
                _InputField(
                  controller: messageController,
                  hint: _t(lang, 'messageHint'),
                  maxLines: 5,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return _t(lang, 'errMessage');
                    }
                    if (v.trim().length < 10) {
                      return _t(lang, 'errMessage');
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Submit button ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                AppColors.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: isSubmitting
                  ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _t(lang, 'sendBtn'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Success View — fully localised
// ═══════════════════════════════════════════════════════════════════════════════
class _SuccessView extends StatelessWidget {
  final Animation<double> animation;
  final String lang;
  const _SuccessView({required this.animation, required this.lang});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: animation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 40),
        padding:
        const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border:
          Border.all(color: AppColors.primary.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              _t(lang, 'successTitle'),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D0D0D),
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 10),
            Text(
              _t(lang, 'successSub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.45),
                  height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.primary.withOpacity(0.4),
                      width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _t(lang, 'goBackBtn'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Field Label
// ═══════════════════════════════════════════════════════════════════════════════
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

// ═══════════════════════════════════════════════════════════════════════════════
// Input Field
// ═══════════════════════════════════════════════════════════════════════════════
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF0D0D0D)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 14, color: Colors.black.withOpacity(0.3)),
        filled: true,
        fillColor: const Color(0xFFF7F9F7),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16, vertical: maxLines > 1 ? 14 : 0),
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
          BorderSide(color: AppColors.primary, width: 1.5),
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