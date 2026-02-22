import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/what_is_pikuru_screen.dart';
import 'package:pikuru/screens/about_pikuru_screen.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen>
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
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text(
              'Resources',
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
                          AppColors.primary.withOpacity(0.85),
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: -20,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Your Learning Hub 📚',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Learn, discover, and explore pickleball in Japan',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.72),
                              fontWeight: FontWeight.w400,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Info Banner ───────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Your information hub inside Pikuru',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Learn Pickleball ──────────────────────
                      const _SectionHeader(
                        label: 'Learn Pickleball',
                        icon: Icons.school_rounded,
                      ),
                      const SizedBox(height: 12),
                      _ModernCard(
                        items: [
                          _ResourceItem(
                            title: 'What is Pickleball?',
                            subtitle: 'A quick introduction for new players',
                            icon: Icons.help_outline_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WhatIsPikuruScreen()),
                            ),
                          ),
                          _ResourceItem(
                            title: 'Beginner Guide',
                            subtitle: 'How to play, rules, scoring',
                            icon: Icons.menu_book_rounded,
                            onTap: () {},
                          ),
                          _ResourceItem(
                            title: 'Equipment Guide',
                            subtitle: 'Paddles, balls, and gear explained',
                            icon: Icons.sports_tennis_rounded,
                            onTap: () {},
                          ),
                          _ResourceItem(
                            title: 'Court Etiquette',
                            subtitle: 'Respectful play and good habits',
                            icon: Icons.handshake_rounded,
                            onTap: () {},
                          ),
                          _ResourceItem(
                            title: 'Rules & Scoring',
                            subtitle: 'Simple rule breakdown for practice time.',
                            icon: Icons.gavel_rounded,
                            onTap: () {},
                          ),
                          _ResourceItem(
                            title: 'Strategy Tips',
                            subtitle: 'Improve your game with simple tactics.',
                            icon: Icons.lightbulb_outline_rounded,
                            onTap: () {},
                          ),
                          _ResourceItem(
                            title: 'About Pikuru',
                            subtitle:
                            'Our mission to grow the pickleball community.',
                            icon: Icons.info_rounded,
                            isLast: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AboutPikuruScreen()),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Helpful Tools ─────────────────────────
                      const _SectionHeader(
                        label: 'Helpful Tools',
                        icon: Icons.build_rounded,
                      ),
                      const SizedBox(height: 12),
                      _ModernCard(
                        items: [
                          _ResourceItem(
                            title: 'Tennis Bear',
                            subtitle: 'Find local pickleball meetups in Japan',
                            icon: Icons.place_rounded,
                            onTap: () {},
                          ),
                          _ResourceItem(
                            title: 'Meetup',
                            subtitle:
                            'Discover pickleball groups and social play',
                            icon: Icons.group_rounded,
                            onTap: () {},
                          ),
                          _ResourceItem(
                            title: 'Local Gyms & Community Centers',
                            subtitle: 'Find courts even if not listed online',
                            icon: Icons.fitness_center_rounded,
                            onTap: () {},
                          ),
                          _ResourceItem(
                            title: 'List of Pickleball-Designated Courts',
                            subtitle: 'Coming soon on Pikuru',
                            icon: Icons.stadium_rounded,
                            isLast: true,
                            isComing: true,
                            onTap: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Support ───────────────────────────────
                      const _SectionHeader(
                        label: 'Support',
                        icon: Icons.support_agent_rounded,
                      ),
                      const SizedBox(height: 12),
                      _ModernCard(
                        items: [
                          _ResourceItem(
                            title: 'FAQs',
                            subtitle: 'Answers to common questions',
                            icon: Icons.quiz_rounded,
                            isLast: true,
                            onTap: () {},
                          ),
                        ],
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

// ── Section Header ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ── Resource Item Data ────────────────────────────────────────────────
class _ResourceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLast;
  final bool isComing;
  final VoidCallback onTap;

  const _ResourceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isLast = false,
    this.isComing = false,
  });
}

// ── Modern Card ───────────────────────────────────────────────────────
class _ModernCard extends StatelessWidget {
  final List<_ResourceItem> items;
  const _ModernCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items.map((item) => _ModernTile(item: item)).toList(),
      ),
    );
  }
}

// ── Modern Tile ───────────────────────────────────────────────────────
class _ModernTile extends StatelessWidget {
  final _ResourceItem item;
  const _ModernTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.vertical(
            bottom: item.isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: AppColors.primary, size: 19),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          if (item.isComing)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Soon',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary.withOpacity(0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (!item.isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            color: AppColors.primary.withOpacity(0.08),
          ),
      ],
    );
  }
}