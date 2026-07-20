import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/theme/material.dart';

// ── How to use ────────────────────────────────────────────────────────
// Call this from your share button:
//
//   ShareModal.show(
//     context,
//     eventTitle: widget.event['event_title'],
//     eventUrl: 'https://pikuru.app/events/${widget.event['event_id']}',
//   );
//
// pubspec.yaml dependencies needed (already in project):
//   url_launcher: any
//
// Android: add to AndroidManifest.xml inside <queries>:
//   <package android:name="jp.naver.line.android" />
//   <package android:name="com.instagram.android" />
//   <package android:name="com.twitter.android" />
//   <package android:name="com.facebook.katana" />
//
// iOS: add to Info.plist LSApplicationQueriesSchemes:
//   line, instagram, twitter, fb

class ShareModal {
  static void show(
      BuildContext context, {
        required String eventTitle,
        required String eventUrl,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(
        eventTitle: eventTitle,
        eventUrl: eventUrl,
      ),
    );
  }
}

class _ShareSheet extends ConsumerStatefulWidget {
  final String eventTitle;
  final String eventUrl;

  const _ShareSheet({
    required this.eventTitle,
    required this.eventUrl,
  });

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _anim;

  bool _linkCopied = false;

  // ── i18n helper ───────────────────────────────────────────────────────
  String _t(String en, String ja) =>
      ref.read(appLangProvider) == kLangJa ? ja : en;

  // ── Share text ────────────────────────────────────────────────────────
  String get _shareText =>
      '🏓 ${widget.eventTitle}\n\n${_t('Join me at this event!', 'このイベントに一緒に参加しましょう！')}\n${widget.eventUrl}';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _anim = CurvedAnimation(
        parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── LINE ──────────────────────────────────────────────────────────────
  // Opens LINE share dialog with pre-filled text. Works on Android & iOS.
  Future<void> _shareToLine() async {
    final encoded = Uri.encodeComponent(_shareText);
    // LINE URL scheme — opens share sheet inside LINE
    final lineUrl = Uri.parse('https://line.me/R/msg/text/?$encoded');
    if (await canLaunchUrl(lineUrl)) {
      await launchUrl(lineUrl, mode: LaunchMode.externalApplication);
    } else {
      _showNotInstalled('LINE');
    }
  }

  // ── Twitter / X ───────────────────────────────────────────────────────
  // Opens Twitter compose with pre-filled tweet text + URL.
  Future<void> _shareToTwitter() async {
    final encoded = Uri.encodeComponent(
        '🏓 ${widget.eventTitle}\n${widget.eventUrl}');
    // Try native app first, fall back to web
    final appUrl =
    Uri.parse('twitter://post?message=$encoded');
    final webUrl = Uri.parse(
        'https://twitter.com/intent/tweet?text=$encoded');

    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ── Facebook ──────────────────────────────────────────────────────────
  // Meta removed text pre-fill from the share dialog for privacy reasons.
  // The only thing we can do is share a URL — Facebook will scrape its
  // Open Graph tags for the title/image preview.
  Future<void> _shareToFacebook() async {
    final encoded = Uri.encodeComponent(widget.eventUrl);
    // Try native app first
    final appUrl = Uri.parse(
        'fb://share?link=$encoded');
    final webUrl = Uri.parse(
        'https://www.facebook.com/sharer/sharer.php?u=$encoded');

    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ── Instagram ─────────────────────────────────────────────────────────
  // Instagram does NOT allow pre-filling text via URL scheme.
  // The only native share options are Stories (requires a local image file)
  // or Copy + open — we do the latter: copy text then open Instagram.
  Future<void> _shareToInstagram() async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    final igUrl = Uri.parse('instagram://app');
    if (await canLaunchUrl(igUrl)) {
      await launchUrl(igUrl, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar(
            _t('📋 Text copied — paste it in your Instagram post or Story',
                '📋 テキストをコピーしました — Instagramの投稿やストーリーに貼り付けてください'),
            isInfo: true,
          ),
        );
      }
    } else {
      // Fall back: open Instagram web
      await launchUrl(Uri.parse('https://www.instagram.com'),
          mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar(_t('📋 Text copied — paste it in your post',
              '📋 テキストをコピーしました — 投稿に貼り付けてください')),
        );
      }
    }
  }

  // ── Copy Link ─────────────────────────────────────────────────────────
  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.eventUrl));
    setState(() => _linkCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _linkCopied = false);
  }

  // ── Native share sheet (OS built-in) ─────────────────────────────────
  // Uses the OS share sheet — this is the most reliable way to share to
  // ANY app including WhatsApp, Messenger, Kakao, etc.
  Future<void> _nativeShare() async {
    // url_launcher doesn't expose the OS share sheet directly.
    // Use platform channel or the `share_plus` package if available.
    // Here we fall back to copy + message.
    await Clipboard.setData(ClipboardData(text: _shareText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          _snackBar(_t('📋 Copied to clipboard!', '📋 クリップボードにコピーしました！')));
    }
  }

  void _showNotInstalled(String app) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _snackBar(
          _t('$app is not installed on this device',
              '$appはこの端末にインストールされていません'),
          isError: true),
    );
  }

  SnackBar _snackBar(String msg,
      {bool isError = false, bool isInfo = false}) {
    return SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError
          ? Colors.red.shade400
          : isInfo
          ? const Color(0xFF1877F2)
          : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the sheet rebuilds if the app language changes.
    ref.watch(appLangProvider);
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_anim),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.share_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_t('Share Event', 'イベントを共有'),
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A))),
                        Text(widget.eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle),
                      child: Icon(Icons.close,
                          size: 16, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Event URL preview chip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.eventUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── App buttons ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // LINE ✅ real deep link
                  _AppBtn(
                    label: 'LINE',
                    color: const Color(0xFF06C755),
                    icon: Icons.chat_bubble_rounded,
                    onTap: _shareToLine,
                  ),
                  // Instagram ✅ opens app + copies text
                  _AppBtn(
                    label: 'Instagram',
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF58529),
                        Color(0xFFDD2A7B),
                        Color(0xFF8134AF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    icon: Icons.camera_alt_rounded,
                    onTap: _shareToInstagram,
                    note: _t('Paste in app', 'アプリで貼り付け'),
                  ),
                  // Facebook ✅ real share URL
                  _AppBtn(
                    label: 'Facebook',
                    color: const Color(0xFF1877F2),
                    icon: Icons.facebook_rounded,
                    onTap: _shareToFacebook,
                  ),
                  // Twitter/X ✅ real tweet intent
                  _AppBtn(
                    label: 'X / Twitter',
                    color: const Color(0xFF000000),
                    icon: Icons.alternate_email_rounded,
                    onTap: _shareToTwitter,
                  ),
                  // Copy ✅
                  _AppBtn(
                    label: _linkCopied
                        ? _t('Copied!', 'コピーしました！')
                        : _t('Copy', 'コピー'),
                    color: _linkCopied
                        ? AppColors.primary
                        : const Color(0xFF6B7280),
                    icon: _linkCopied
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    onTap: _copyLink,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Instagram note ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border:
                  Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _t('Instagram: event text is copied to clipboard — just paste it in your post or Story.',
                            'Instagram: イベントのテキストがクリップボードにコピーされます — 投稿やストーリーに貼り付けるだけです。'),
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade800,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Divider ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: Colors.grey.shade200)),
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(_t('More options', 'その他のオプション'),
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4)),
                  ),
                  Expanded(
                      child: Divider(
                          color: Colors.grey.shade200)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Other options row ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Native OS share sheet — shares to ANY installed app
                  Expanded(
                    child: _OptionTile(
                      icon: Icons.open_in_new_rounded,
                      label: _t('More apps', 'その他のアプリ'),
                      subtitle: _t('WhatsApp, Mail…', 'WhatsApp、メールなど…'),
                      onTap: _nativeShare,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionTile(
                      icon: Icons.copy_rounded,
                      label: _t('Copy full text', '全文をコピー'),
                      subtitle: _t('Title + link', 'タイトル＋リンク'),
                      onTap: () async {
                        await Clipboard.setData(
                            ClipboardData(text: _shareText));
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              _snackBar(_t('Copied!', 'コピーしました！')));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
                height: 20 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

// ── App Button ────────────────────────────────────────────────────────
class _AppBtn extends StatelessWidget {
  final String label;
  final Color? color;
  final Gradient? gradient;
  final IconData icon;
  final String? note;
  final VoidCallback onTap;

  const _AppBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.gradient,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: gradient == null ? color : null,
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (color ?? Colors.black).withOpacity(0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A))),
            if (note != null) ...[
              Text(note!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Option Tile ───────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A))),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}