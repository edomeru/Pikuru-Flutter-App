import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/language_screen.dart';
import 'package:pikuru/screens/contact_us_screen.dart';
import 'package:pikuru/screens/change_email_screen.dart';
import 'package:pikuru/screens/change_password_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localization strings
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'title':            'Settings',
    'heroTitle':        'App Settings ⚙️',
    'heroSub':          'Manage your account and preferences',
    'sectionAccount':   'Account',
    'sectionPrefs':     'Preferences',
    'sectionHelp':      'Help & Support',
    'sectionLegal':     'Legal',
    'googleBanner':     'Signed in with Google. Email and password are managed by Google.',
    'changeEmail':      'Change Email',
    'changePassword':   'Change Password',
    'language':         'Language',
    'contactUs':        'Contact Us',
    'terms':            'Terms & Conditions',
    'privacy':          'Privacy Policy',
    'version':          'Version 1.0.0',
    'langLabel_en':     'English',
    'langLabel_ja':     '日本語',
    'googleDialogTitle':'Google Account',
    'googleDialogEmail':'You signed in with Google. To change your email, please visit your Google account settings at myaccount.google.com.',
    'googleDialogPass': 'You signed in with Google. To change your password, please visit your Google account settings at myaccount.google.com.',
    'googleDialogBtn':  'Got it',
  },
  kLangJa: {
    'title':            '設定',
    'heroTitle':        'アプリ設定 ⚙️',
    'heroSub':          'アカウントと設定を管理する',
    'sectionAccount':   'アカウント',
    'sectionPrefs':     '設定',
    'sectionHelp':      'ヘルプ・サポート',
    'sectionLegal':     '法的情報',
    'googleBanner':     'Googleでログインしています。メールとパスワードはGoogleアカウントで管理されます。',
    'changeEmail':      'メールアドレスを変更',
    'changePassword':   'パスワードを変更',
    'language':         '言語',
    'contactUs':        'お問い合わせ',
    'terms':            '利用規約',
    'privacy':          'プライバシーポリシー',
    'version':          'バージョン 1.0.0',
    'langLabel_en':     'English',
    'langLabel_ja':     '日本語',
    'googleDialogTitle':'Googleアカウント',
    'googleDialogEmail':'Googleでログインしています。メールアドレスを変更するには、myaccount.google.com のGoogleアカウント設定をご利用ください。',
    'googleDialogPass': 'Googleでログインしています。パスワードを変更するには、myaccount.google.com のGoogleアカウント設定をご利用ください。',
    'googleDialogBtn':  '了解',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset>   _slideAnim;

  bool get _isGoogleUser {
    final user = FirebaseAuth.instance.currentUser;
    return user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  }

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
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _showGoogleAccountDialog(String message, String lang) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.g_mobiledata_rounded,
                    color: Colors.blue, size: 40),
              ),
              const SizedBox(height: 18),
              Text(_t(lang, 'googleDialogTitle'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D0D0D))),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.5),
                    height: 1.55),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(_t(lang, 'googleDialogBtn'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _langLabel(String selectedCode) =>
      selectedCode == kLangJa ? '日本語' : 'English';

  @override
  Widget build(BuildContext context) {
    final lang      = ref.watch(appLangProvider);
    final isGoogle  = _isGoogleUser;

    // Shorthand for current-language strings
    final t = (String key) => _t(lang, key);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(t('title'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: 0.3)),
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
                            color: Colors.white.withOpacity(0.06)))),
                Positioned(
                    bottom: -20, left: -20,
                    child: Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05)))),
                Positioned(
                    bottom: 20, left: 24,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t('heroTitle'),
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text(t('heroSub'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.72))),
                        ],
                      ),
                    )),
              ]),
            ),
          ),

          // ── Body ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Account ─────────────────────────────────────
                      _SectionHeader(label: t('sectionAccount')),
                      const SizedBox(height: 12),

                      if (isGoogle) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.g_mobiledata_rounded,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t('googleBanner'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _SettingsCard(items: [
                        _SettingsItem(
                          icon: Icons.email_rounded,
                          label: t('changeEmail'),
                          isGoogle: isGoogle,
                          onTap: () {
                            if (isGoogle) {
                              _showGoogleAccountDialog(
                                  t('googleDialogEmail'), lang);
                              return;
                            }
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const ChangeEmailScreen()));
                          },
                        ),
                        _SettingsItem(
                          icon: Icons.lock_rounded,
                          label: t('changePassword'),
                          isLast: true,
                          isGoogle: isGoogle,
                          onTap: () {
                            if (isGoogle) {
                              _showGoogleAccountDialog(
                                  t('googleDialogPass'), lang);
                              return;
                            }
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const ChangePasswordScreen()));
                          },
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ── Preferences ──────────────────────────────────
                      _SectionHeader(label: t('sectionPrefs')),
                      const SizedBox(height: 12),

                      _SettingsCard(items: [
                        _SettingsItem(
                          icon: Icons.language_rounded,
                          label: t('language'),
                          trailing:
                          _TrailingTag(label: _langLabel(lang)),
                          isLast: true,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const LanguageScreen())),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ── Help & Support ────────────────────────────────
                      _SectionHeader(label: t('sectionHelp')),
                      const SizedBox(height: 12),
                      _SettingsCard(items: [
                        _SettingsItem(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: t('contactUs'),
                          isLast: true,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                  const ContactUsScreen())),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ── Legal ─────────────────────────────────────────
                      _SectionHeader(label: t('sectionLegal')),
                      const SizedBox(height: 12),
                      _SettingsCard(items: [
                        _SettingsItem(
                            icon: Icons.description_rounded,
                            label: t('terms'),
                            onTap: () {}),
                        _SettingsItem(
                            icon: Icons.privacy_tip_rounded,
                            label: t('privacy'),
                            isLast: true,
                            onTap: () {}),
                      ]),

                      const SizedBox(height: 24),

                      Center(
                        child: Column(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                                color:
                                AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(
                                Icons.sports_tennis_rounded,
                                color: AppColors.primary, size: 26),
                          ),
                          const SizedBox(height: 8),
                          const Text('Pikuru',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                          const SizedBox(height: 2),
                          Text(t('version'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400)),
                        ]),
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

// ── Section Header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.1)),
    ]);
  }
}

// ── Settings Item Data ─────────────────────────────────────────────────────────
class _SettingsItem {
  final IconData icon;
  final String label;
  final bool isLast;
  final bool isGoogle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast   = false,
    this.isGoogle  = false,
    this.trailing,
  });
}

// ── Settings Card ──────────────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child:
      Column(children: items.map((i) => _SettingsTile(item: i)).toList()),
    );
  }
}

// ── Settings Tile ──────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final _SettingsItem item;
  const _SettingsTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.vertical(
            bottom: item.isLast
                ? const Radius.circular(16)
                : Radius.zero),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: item.isGoogle
                    ? Colors.grey.withOpacity(0.08)
                    : AppColors.primary.withOpacity(0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon,
                  color: item.isGoogle
                      ? Colors.grey.shade400
                      : AppColors.primary,
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(item.label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: item.isGoogle
                          ? Colors.grey.shade400
                          : const Color(0xFF1A1A1A))),
            ),
            if (item.trailing != null) ...[
              item.trailing!,
              const SizedBox(width: 6)
            ],
            if (item.isGoogle)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.g_mobiledata_rounded,
                      size: 14, color: Colors.blue.shade400),
                  const SizedBox(width: 3),
                  Text('Google',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade400)),
                ]),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary.withOpacity(0.4), size: 20),
          ]),
        ),
      ),
      if (!item.isLast)
        Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            color: AppColors.primary.withOpacity(0.08)),
    ]);
  }
}

// ── Trailing Tag ───────────────────────────────────────────────────────────────
class _TrailingTag extends StatelessWidget {
  final String label;
  const _TrailingTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
    );
  }
}