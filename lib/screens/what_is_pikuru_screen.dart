import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart'; // ✅ Uses your app theme

class WhatIsPikuruScreen extends StatefulWidget {
  const WhatIsPikuruScreen({super.key});

  @override
  State<WhatIsPikuruScreen> createState() => _WhatIsPikuruScreen();
}

class _WhatIsPikuruScreen extends State<WhatIsPikuruScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;

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
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text(
              'What is Pikuru?',
              style: TextStyle(
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
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 28,
                    left: 24,
                    right: 24,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Let's Pikuru! 🏓",
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Japan's pickleball community hub",
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

          // ── Body ─────────────────────────────────────────────────
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

                      // ── Origin ────────────────────────────────
                      const _SectionHeader(title: 'Origin of Pikuru'),
                      const SizedBox(height: 12),
                      _StoryCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _BodyText(
                              '"Pikuru" was created as a shorter, more casual way to say "Do you wanna play pickleball?" in Japanese.',
                            ),
                            SizedBox(height: 10),
                            _BodyText(
                              'In Japanese slang, when asking a friend if they want to do something, people often add "-ru?" to the end of a verb to make it light and casual.',
                            ),
                            SizedBox(height: 10),
                            _HighlightBox(
                              text:
                              'Normally, you would say "ピックルボール遊ぶ？" (Do you want to play pickleball?), but we shortened it to "Pikuru?" so it feels friendly, easy to say, and natural as a quick invitation.',
                            ),
                            SizedBox(height: 10),
                            _BodyText(
                              '"Pikuru" was born from the idea of creating a fun, approachable culture where people can casually invite each other to play.',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── What We Offer ─────────────────────────
                      const _SectionHeader(title: 'What We Offer'),
                      const SizedBox(height: 12),
                      const _OfferGrid(),

                      const SizedBox(height: 28),

                      // ── Join Us ───────────────────────────────
                      const _SectionHeader(title: 'Join Us'),
                      const SizedBox(height: 12),
                      _StoryCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _BodyText(
                              "Whether you're picking up your first paddle or you've been playing for years, Pikuru is here to help you connect, learn, and grow.",
                            ),
                            SizedBox(height: 10),
                            _BodyText(
                              "Let's build Japan's pickleball future — one rally at a time.",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Follow Us ─────────────────────────────
                      const _FollowSection(),

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

// ── Section Header ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
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

// ── Story Card ────────────────────────────────────────────────────────
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

// ── Highlight Box ─────────────────────────────────────────────────────
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
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
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

// ── Body Text ─────────────────────────────────────────────────────────
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

// ── Offer Grid ────────────────────────────────────────────────────────
class _OfferGrid extends StatelessWidget {
  const _OfferGrid();

  static const List<_OfferItem> _offers = [
    _OfferItem(
      icon: Icons.location_on_rounded,
      title: 'Local Court Finder',
      subtitle: 'See where you can play across Japan',
    ),
    _OfferItem(
      icon: Icons.event_rounded,
      title: 'Event Listings',
      subtitle: 'From casual meetups to tournaments',
    ),
    _OfferItem(
      icon: Icons.sports_tennis_rounded,
      title: 'Gear Guides',
      subtitle: 'For every play style and budget',
    ),
    _OfferItem(
      icon: Icons.newspaper_rounded,
      title: 'News & Spotlights',
      subtitle: 'Rising players and global updates',
    ),
    _OfferItem(
      icon: Icons.phone_iphone_rounded,
      title: 'Future Mobile App',
      subtitle: 'Find your pickleball community easily',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _offers.asMap().entries.map((entry) {
        return _OfferTile(
          item: entry.value,
          isLast: entry.key == _offers.length - 1,
        );
      }).toList(),
    );
  }
}

class _OfferItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OfferItem(
      {required this.icon, required this.title, required this.subtitle});
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
            width: 44,
            height: 44,
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

// ── Follow Section ────────────────────────────────────────────────────
class _FollowSection extends StatelessWidget {
  const _FollowSection();

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
          const Text(
            'Follow us!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stay in the loop with the Pikuru community',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SocialButton(icon: Icons.camera_alt_outlined, label: 'Instagram', onTap: () {}),
              const SizedBox(width: 12),
              _SocialButton(icon: Icons.facebook_rounded, label: 'Facebook', onTap: () {}),
              const SizedBox(width: 12),
              _SocialButton(icon: Icons.play_circle_outline_rounded, label: 'YouTube', onTap: () {}),
              const SizedBox(width: 12),
              _LineButton(onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _LineButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LineButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: const Center(
          child: Text(
            'Line',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}