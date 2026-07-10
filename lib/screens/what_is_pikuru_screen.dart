import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localised content — mirrors the web app's Firestore `resources/what-is-pikuru`
// document (pikuruDoc.en / pikuruDoc.ja in seed_pikuru_page.tsx)
// ─────────────────────────────────────────────────────────────────────────────
class _Content {
  final String appBarTitle;
  final String heroTitle;
  final String heroSub;
  // Origin section
  final String originTitle;
  final String originP1;
  final String originP2;
  final String originHighlight;
  final String originP3;
  // What We Offer section
  final String offerTitle;
  final List<_OfferItem> offerItems;
  // Join Us section
  final String joinTitle;
  final String joinP1;
  final String joinP2;
  // Follow Us section
  final String followTitle;
  final String followSub;

  const _Content({
    required this.appBarTitle,
    required this.heroTitle,
    required this.heroSub,
    required this.originTitle,
    required this.originP1,
    required this.originP2,
    required this.originHighlight,
    required this.originP3,
    required this.offerTitle,
    required this.offerItems,
    required this.joinTitle,
    required this.joinP1,
    required this.joinP2,
    required this.followTitle,
    required this.followSub,
  });
}

// ── EN content ────────────────────────────────────────────────────────────────
const _en = _Content(
  appBarTitle:      'What is Pikuru?',
  heroTitle:        "Let's Pikuru! 🏓",
  heroSub:          "Japan's pickleball community hub",
  originTitle:      'Origin of Pikuru',
  originP1:         '"Pikuru" was created as a shorter, more casual way to say "Do you wanna play pickleball?" in Japanese.',
  originP2:         'In Japanese slang, when asking a friend if they want to do something, people often add "-ru?" to the end of a verb to make it light and casual.',
  originHighlight:  'Normally, you would say "ピックルボール遊ぶ？" (Do you want to play pickleball?), but we shortened it to "Pikuru?" so it feels friendly, easy to say, and natural as a quick invitation.',
  originP3:         '"Pikuru" was born from the idea of creating a fun, approachable culture where people can casually invite each other to play.',
  offerTitle:       'What We Offer',
  offerItems: [
    _OfferItem(icon: Icons.location_on_rounded,      title: 'Local Court Finder',   subtitle: 'See where you can play across Japan'),
    _OfferItem(icon: Icons.event_rounded,            title: 'Event Listings',        subtitle: 'From casual meetups to tournaments'),
    _OfferItem(icon: Icons.sports_tennis_rounded,    title: 'Gear Guides',           subtitle: 'For every play style and budget'),
    _OfferItem(icon: Icons.newspaper_rounded,        title: 'News & Spotlights',     subtitle: 'Rising players and global updates'),
    _OfferItem(icon: Icons.phone_iphone_rounded,     title: 'Future Mobile App',     subtitle: 'Find your pickleball community easily'),
  ],
  joinTitle: 'Join Us',
  joinP1:    "Whether you're picking up your first paddle or you've been playing for years, Pikuru is here to help you connect, learn, and grow.",
  joinP2:    "Let's build Japan's pickleball future — one rally at a time.",
  followTitle: 'Follow us!',
  followSub:   'Stay in the loop with the Pikuru community',
);

// ── JA content — mirrors pikuruDoc.ja in seed_pikuru_page.tsx ─────────────────
const _ja = _Content(
  appBarTitle:      'Pikuruとは？',
  heroTitle:        "Let's Pikuru! 🏓",
  heroSub:          '日本のピックルボールコミュニティハブ',
  originTitle:      'Pikuruの由来',
  originP1:         '「Pikuru（ピクル）」は、「ピックルボールやらない？」という言葉を、より短くカジュアルにしたものです。',
  originP2:         '日本の若者言葉では、友達を誘うときに動詞の最後に「〜る？」をつけて気軽な誘い方にすることがよくあります。',
  originHighlight:  '普通なら「ピックルボール遊ぶ？」と言いますが、親しみやすく、言いやすく、自然な誘いとなるよう「ピクル？」と短縮しました。',
  originP3:         '「ピクル」は、人々が気軽に誘い合ってプレーできる楽しくて親しみやすい文化を作りたいという思いから生まれました。',
  offerTitle:       '提供するもの',
  offerItems: [
    _OfferItem(icon: Icons.location_on_rounded,      title: '地域のコート検索',     subtitle: '日本全国でプレーできる場所を見る'),
    _OfferItem(icon: Icons.event_rounded,            title: 'イベント一覧',          subtitle: 'カジュアルな集まりから大会まで'),
    _OfferItem(icon: Icons.sports_tennis_rounded,    title: 'ギアガイド',            subtitle: 'プレースタイルと予算に応じた選び方'),
    _OfferItem(icon: Icons.newspaper_rounded,        title: 'ニュース＆スポットライト', subtitle: '注目選手と世界的なアップデート'),
    _OfferItem(icon: Icons.phone_iphone_rounded,     title: '将来のモバイルアプリ',  subtitle: 'ピックルボールのコミュニティを簡単に見つける'),
  ],
  joinTitle: '参加する',
  joinP1:    '初めてパドルを握る方も、長年プレーしている方も、Pikuruはつながり、学び、成長するお手伝いをします。',
  joinP2:    '日本のピックルボールの未来を共に作りましょう — 1ラリーずつ。',
  followTitle: 'フォローしてね！',
  followSub:   'Pikuruコミュニティの最新情報をゲット',
);

_Content _c(String lang) => lang == kLangJa ? _ja : _en;

// ─────────────────────────────────────────────────────────────────────────────
// WhatIsPikuruScreen — ConsumerStatefulWidget
// ─────────────────────────────────────────────────────────────────────────────
class WhatIsPikuruScreen extends ConsumerStatefulWidget {
  const WhatIsPikuruScreen({super.key});

  @override
  ConsumerState<WhatIsPikuruScreen> createState() => _WhatIsPikuruScreenState();
}

class _WhatIsPikuruScreenState extends ConsumerState<WhatIsPikuruScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch global lang provider — rebuilds when lang changes anywhere
    final lang = ref.watch(appLangProvider);
    final c    = _c(lang);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              c.appBarTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
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
                          AppColors.primary.withOpacity(0.9),
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -40, right: -40,
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06)),
                    ),
                  ),
                  Positioned(
                    bottom: -20, left: -30,
                    child: Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                  Positioned(
                    bottom: 28, left: 24, right: 24,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.heroTitle,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.heroSub,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.75),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
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
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),

                      // Origin
                      _SectionHeader(title: c.originTitle),
                      const SizedBox(height: 12),
                      _StoryCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BodyText(c.originP1),
                            const SizedBox(height: 10),
                            _BodyText(c.originP2),
                            const SizedBox(height: 10),
                            _HighlightBox(text: c.originHighlight),
                            const SizedBox(height: 10),
                            _BodyText(c.originP3),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // What We Offer
                      _SectionHeader(title: c.offerTitle),
                      const SizedBox(height: 12),
                      _OfferGrid(items: c.offerItems),

                      const SizedBox(height: 28),

                      // Join Us
                      _SectionHeader(title: c.joinTitle),
                      const SizedBox(height: 12),
                      _StoryCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BodyText(c.joinP1),
                            const SizedBox(height: 10),
                            _BodyText(c.joinP2),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Follow Us
                      _FollowSection(
                          title: c.followTitle, sub: c.followSub),

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

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets (all accept localised strings as parameters)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  final Widget child;
  const _StoryCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HighlightBox extends StatelessWidget {
  final String text;
  const _HighlightBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
            left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          color: Color(0xFF2A2A2A),
          height: 1.65,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF3A3A3A),
        height: 1.7,
        letterSpacing: 0.1,
      ),
    );
  }
}

// ── Offer item model ──────────────────────────────────────────────────────────
class _OfferItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OfferItem(
      {required this.icon, required this.title, required this.subtitle});
}

// ── Offer grid ────────────────────────────────────────────────────────────────
class _OfferGrid extends StatelessWidget {
  final List<_OfferItem> items;
  const _OfferGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        return _OfferTile(
          item: entry.value,
          isLast: entry.key == items.length - 1,
        );
      }).toList(),
    );
  }
}

class _OfferTile extends StatelessWidget {
  final _OfferItem item;
  final bool isLast;
  const _OfferTile({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Follow section — accepts localised strings ────────────────────────────────
class _FollowSection extends StatelessWidget {
  final String title;
  final String sub;
  const _FollowSection({required this.title, required this.sub});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.95),
            AppColors.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SocialButton(
                icon: const Icon(Icons.facebook_rounded, color: Colors.white, size: 26),
                label: 'Facebook',
                onTap: () => _launchUrl('https://www.facebook.com/letspikuru'),
              ),
              const SizedBox(width: 12),
              _SocialButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
                label: 'Instagram',
                onTap: () => _launchUrl('https://www.instagram.com/letspikuru'),
              ),
              const SizedBox(width: 12),
              _SocialButton(
                icon: SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(
                    painter: _TiktokIconPainter(),
                  ),
                ),
                label: 'TikTok',
                onTap: () => _launchUrl('https://www.tiktok.com/@letspikuru'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const _SocialButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class _TiktokIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Stem: vertical line
    canvas.drawLine(
      Offset(w * 0.55, h * 0.25),
      Offset(w * 0.55, h * 0.7),
      paint,
    );

    // Bottom note head (arc or circle)
    final headRect = Rect.fromCircle(
      center: Offset(w * 0.4, h * 0.7),
      radius: w * 0.15,
    );
    canvas.drawArc(
      headRect,
      0, // Start angle: 0 (right)
      3.14159 * 1.5, // 270 degrees
      false,
      paint,
    );

    // Top flag (arc)
    final flagRect = Rect.fromCircle(
      center: Offset(w * 0.75, h * 0.25),
      radius: w * 0.2,
    );
    canvas.drawArc(
      flagRect,
      3.14159, // Start angle: 180 degrees (left)
      -3.14159 * 0.5, // -90 degrees (upwards)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}