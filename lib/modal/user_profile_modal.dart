import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:pikuru/providers/app_language_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UTILITY — upgrades Google profile photo URLs to full resolution
// ─────────────────────────────────────────────────────────────────────────────
String hiRes(String url, {int size = 400}) {
  if (url.isEmpty) return url;
  return url
      .replaceAllMapped(RegExp(r'=s\d+-c'), (_) => '=s${size}-c')
      .replaceAllMapped(RegExp(r'=s\d+(?!-c)(?=[&?]|$)'), (_) => '=s$size');
}

// ════════════════════════════════════════════════════════════════════════════
// Shared Avatar widget — rebuilds when app language changes
// ════════════════════════════════════════════════════════════════════════════

class UserAvatar extends ConsumerWidget {
  final String url;
  final String name;
  final double radius;
  final double fontSize;

  const UserAvatar({
    super.key,
    required this.url,
    required this.name,
    required this.radius,
    required this.fontSize,
  });

  /// Returns the display initial for the avatar, respecting the active locale.
  /// - Japanese (ja): if the name contains any CJK character, return the first
  ///   CJK character; otherwise fall back to the first character uppercased.
  /// - All other locales: first character of the trimmed name, uppercased.
  static String _initial(String name, String langCode) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    if (langCode == kLangJa) {
      // Prefer the first CJK unified ideograph / kana character if present
      final cjkMatch = RegExp(
        r'[\u3000-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF]',
      ).firstMatch(trimmed);
      if (cjkMatch != null) return cjkMatch.group(0)!;
    }

    // Default: first Unicode scalar value (handles multi-byte chars safely)
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the provider means this widget rebuilds on every language toggle
    final langCode = ref.watch(appLangProvider);
    final initial  = _initial(name, langCode);

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      onBackgroundImageError: url.isNotEmpty ? (_, __) {} : null,
      child: url.isEmpty
          ? Text(
        initial,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      )
          : null,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// User Profile Modal  (StatefulWidget so the Future is only created once)
// ════════════════════════════════════════════════════════════════════════════

class UserProfileModal extends StatefulWidget {
  final String userId;
  final String userName;
  final String avatarUrl;
  final VoidCallback onChat;
  final void Function(Map<String, dynamic> group)? onGroupTap;

  const UserProfileModal({
    super.key,
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.onChat,
    this.onGroupTap,
  });

  static PageRoute<void> route({
    required String userId,
    required String userName,
    required String avatarUrl,
    required VoidCallback onChat,
    void Function(Map<String, dynamic> group)? onGroupTap,
  }) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => UserProfileModal(
        userId: userId,
        userName: userName,
        avatarUrl: avatarUrl,
        onChat: onChat,
        onGroupTap: onGroupTap,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  late final Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = Future.wait([_fetchRegistration(), _fetchGroups()]);
  }

  Future<Map<String, dynamic>> _fetchRegistration() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('registration')
          .doc(widget.userId)
          .get();
      if (doc.exists && doc.data() != null) {
        debugPrint('[UserProfileModal] registration found by doc ID');
        return doc.data()!;
      }

      final q = await FirebaseFirestore.instance
          .collection('registration')
          .where('uid', isEqualTo: widget.userId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        debugPrint('[UserProfileModal] registration found by uid field');
        return q.docs.first.data();
      }
    } catch (e) {
      debugPrint('[UserProfileModal] _fetchRegistration error: $e');
    }
    debugPrint('[UserProfileModal] registration NOT found for ${widget.userId}');
    return {};
  }

  Future<List<Map<String, dynamic>>> _fetchGroups() async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('user_groups')
          .where('user_id', isEqualTo: widget.userId)
          .get();
      if (q.docs.isEmpty) return [];

      final enriched = await Future.wait(q.docs.map((d) async {
        final ug = d.data();
        final groupId = (ug['group_id'] ?? '').toString();
        if (groupId.isEmpty) return ug;
        try {
          final orgQ = await FirebaseFirestore.instance
              .collection('organizations')
              .where('org_id', isEqualTo: groupId)
              .limit(1)
              .get();
          if (orgQ.docs.isNotEmpty) {
            final org = orgQ.docs.first.data();
            final locId = (org['org_loc_id'] ?? '').toString();
            String city = '', prefecture = '';
            if (locId.isNotEmpty) {
              try {
                final locQ = await FirebaseFirestore.instance
                    .collection('locations')
                    .where('loc_id', isEqualTo: locId)
                    .limit(1)
                    .get();
                if (locQ.docs.isNotEmpty) {
                  final loc = locQ.docs.first.data();
                  city       = (loc['loc_city']      ?? '').toString();
                  prefecture = (loc['loc_prefecture'] ?? '').toString();
                }
              } catch (_) {}
            }
            return <String, dynamic>{
              ...ug,
              ...org,
              'loc_city': city,
              'loc_prefecture': prefecture,
            };
          }
        } catch (_) {}
        return ug;
      }));
      return enriched;
    } catch (e) {
      debugPrint('[UserProfileModal] _fetchGroups error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final hiResAvatar = hiRes(widget.avatarUrl, size: 600);

    return FutureBuilder<List<dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.hasData
            ? snapshot.data![0] as Map<String, dynamic>
            : <String, dynamic>{};
        final groups = snapshot.hasData
            ? snapshot.data![1] as List<Map<String, dynamic>>
            : <Map<String, dynamic>>[];

        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName  = (data['lastName']  ?? '').toString().trim();
        final resolvedName =
        (firstName.isNotEmpty || lastName.isNotEmpty)
            ? '$firstName $lastName'.trim()
            : widget.userName;
        final firstNameOnly = firstName.isNotEmpty
            ? firstName
            : widget.userName.split(' ').first;

        final bio     = (data['description'] ?? '').toString().trim();
        final address = (data['address']     ?? '').toString().trim();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroHeader(
                  avatarUrl: hiResAvatar,
                  userName: resolvedName,
                  location: snapshot.hasData ? address : '',
                  onClose: () => Navigator.pop(context),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ChatButton(
                          label: 'Chat with $firstNameOnly',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _BellButton(),
                    ],
                  ),
                ),
              ),

              if (!snapshot.hasData)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                  ),
                ),

              if (snapshot.hasData && (bio.isNotEmpty || address.isNotEmpty))
                SliverToBoxAdapter(
                  child: _SectionCard(
                    margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(title: 'About $firstNameOnly'),

                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            bio,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: Color(0xFF3A3A3C),
                              height: 1.65,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],

                        if (bio.isNotEmpty && address.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Divider(
                                height: 1,
                                color: Colors.black.withOpacity(0.06)),
                          )
                        else
                          const SizedBox(height: 14),

                        if (address.isNotEmpty)
                          _InfoRow(
                            icon: Icons.location_on_rounded,
                            label: address,
                          ),
                      ],
                    ),
                  ),
                ),

              if (snapshot.hasData && groups.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                    child: Row(
                      children: [
                        _SectionTitle(title: 'Groups Joined'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${groups.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _GroupCard(
                      group: groups[index],
                      onTap: widget.onGroupTap != null
                          ? () => widget.onGroupTap!(groups[index])
                          : null,
                    ),
                    childCount: groups.length,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 56)),
            ],
          ),
        );
      },
    );
  }
}

// ── Section title with green accent bar ───────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D0D0D),
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

// ── White card wrapper ────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const _SectionCard({required this.child, required this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Info row (icon pill + label) ──────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.black.withOpacity(0.65),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero Header ───────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final String avatarUrl;
  final String userName;
  final String location;
  final VoidCallback onClose;

  const _HeroHeader({
    required this.avatarUrl,
    required this.userName,
    required this.location,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final heroHeight = MediaQuery.of(context).size.height * 0.44;
    final initials   = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          avatarUrl.isNotEmpty
              ? Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _gradientBox(initials),
          )
              : _gradientBox(initials),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.72),
                  ],
                  stops: const [0.0, 0.38, 0.65, 1.0],
                ),
              ),
            ),
          ),

          Positioned(
            top: topPadding + 14,
            left: 16,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onClose();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    shadows: [
                      Shadow(
                          color: Colors.black45,
                          blurRadius: 14,
                          offset: Offset(0, 2))
                    ],
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBox(String initials) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, const Color(0xFF1A6B4A), 0.5)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Chat Button ───────────────────────────────────────────────────────────────
class _ChatButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChatButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.38),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bell Button ───────────────────────────────────────────────────────────────
class _BellButton extends StatefulWidget {
  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _active = !_active);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _active ? AppColors.primary.withOpacity(0.1) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _active
                ? AppColors.primary
                : Colors.black.withOpacity(0.10),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          _active
              ? Icons.notifications_rounded
              : Icons.notifications_outlined,
          color: _active ? AppColors.primary : Colors.black.withOpacity(0.38),
          size: 22,
        ),
      ),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback? onTap;
  const _GroupCard({required this.group, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name       = (group['org_name']    ?? group['group_name'] ?? group['name']  ?? '').toString();
    final imageUrl   = (group['org_image']   ?? group['group_image'] ?? group['image'] ?? '').toString();
    final hiResImage = hiRes(imageUrl, size: 300);

    final city       = (group['loc_city']      ?? '').toString();
    final prefecture = (group['loc_prefecture'] ?? '').toString();
    final location   = [city, prefecture].where((s) => s.isNotEmpty).join(', ');

    final level    = (group['org_skill_level'] ?? group['level']     ?? '').toString();
    final schedule = (group['org_schedule']    ?? group['schedule']  ?? '').toString();
    final ageGroup = (group['org_age_groups']  ?? group['age_group'] ?? '').toString();
    final booking  = (group['org_booking']     ?? '').toString();

    final details = <String>[
      if (level.isNotEmpty)    level,
      if (schedule.isNotEmpty) schedule,
      if (ageGroup.isNotEmpty) ageGroup,
    ];

    const double cardHeight = 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                child: SizedBox(
                  width: cardHeight,
                  height: cardHeight,
                  child: hiResImage.isNotEmpty
                      ? Image.network(
                    hiResImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                      : _placeholder(),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D0D0D),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black.withOpacity(0.55),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          details.join('  ·  '),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.black.withOpacity(0.42),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      if (booking.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _chip(booking, isGreen: true),
                      ],
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary.withOpacity(0.5),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {bool isGreen = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isGreen
            ? AppColors.primary.withOpacity(0.10)
            : const Color(0xFFEEEEF2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isGreen ? AppColors.primary : const Color(0xFF3A3A3C),
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.08),
      child: Center(
        child: Icon(Icons.group_rounded,
            color: AppColors.primary.withOpacity(0.35), size: 28),
      ),
    );
  }
}