import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/loginpage.dart';
import 'package:pikuru/screens/resources_screen.dart';
import 'package:pikuru/screens/edit_profile_screen.dart';
import 'package:pikuru/screens/settings_screen.dart';

class AccountScreen extends StatefulWidget {
  /// Switch a root MainNavigation tab (0=Home … 4=Account).
  final void Function(int tabIndex)? onNavigateToTab;

  /// Opens EventHistoryScreen as a hidden tab while keeping the bottom bar.
  /// [initialTab]: 0 = My Events, 1 = Interested Events.
  final void Function({int initialTab})? onOpenEventHistory;

  const AccountScreen({
    super.key,
    this.onNavigateToTab,
    this.onOpenEventHistory,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _avatarController;
  late final Animation<double> _avatarAnim;

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
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _slideController, curve: Curves.easeOutCubic));
    _avatarController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _avatarAnim = CurvedAnimation(
        parent: _avatarController, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  void _goToGroups() => widget.onNavigateToTab?.call(3);

  void _goToEventHistory({int tabIndex = 0}) =>
      widget.onOpenEventHistory?.call(initialTab: tabIndex);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final displayName = user?.displayName ?? 'User';

        return Scaffold(
          backgroundColor: const Color(0xFFF4F9F5),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 230,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.primary,
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
                          top: -50, right: -30,
                          child: Container(width: 200, height: 200,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.06)))),
                      Positioned(
                          bottom: -30, left: -20,
                          child: Container(width: 140, height: 140,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05)))),
                      Positioned(
                        bottom: 24, left: 0, right: 0,
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: Column(
                            children: [
                              ScaleTransition(
                                scale: _avatarAnim,
                                child: Container(
                                  width: 88, height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4))],
                                  ),
                                  child: ClipOval(
                                    child: user?.photoURL != null
                                        ? Image.network(user!.photoURL!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _avatarPlaceholder())
                                        : _avatarPlaceholder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(displayName,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3)),
                              const SizedBox(height: 3),
                              Text(user?.email ?? '',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.7))),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Stats Row 1: Groups ──────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _StatBanner(
                                  uid: user?.uid ?? '',
                                  collection: 'user_groups',
                                  userField: 'user_id',
                                  statusFilter: 'active',
                                  icon: Icons.groups_rounded,
                                  label: 'Groups Joined',
                                  emptyLabel: 'No groups',
                                  buttonLabel: 'Join',
                                  buttonIcon: Icons.add_rounded,
                                  onTap: _goToGroups,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatBanner(
                                  uid: user?.uid ?? '',
                                  collection: 'user_groups',
                                  userField: 'user_id',
                                  statusFilter: 'interested',
                                  icon: Icons.favorite_rounded,
                                  label: 'Interested Groups',
                                  emptyLabel: 'None yet',
                                  buttonLabel: 'Browse',
                                  buttonIcon: Icons.explore_rounded,
                                  onTap: _goToGroups,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Stats Row 2: Events ──────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _StatBanner(
                                  uid: user?.uid ?? '',
                                  collection: 'user_events',
                                  userField: 'user_id',
                                  statusFilter: 'my_events',
                                  icon: Icons.event_available_rounded,
                                  label: 'Events Joined',
                                  emptyLabel: 'No events',
                                  buttonLabel: 'Find',
                                  buttonIcon: Icons.search_rounded,
                                  onTap: () => _goToEventHistory(tabIndex: 0),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatBanner(
                                  uid: user?.uid ?? '',
                                  collection: 'user_events',
                                  userField: 'user_id',
                                  statusFilter: 'interested',
                                  icon: Icons.bookmark_rounded,
                                  label: 'Saved Events',
                                  emptyLabel: 'None saved',
                                  buttonLabel: 'Explore',
                                  buttonIcon: Icons.explore_rounded,
                                  onTap: () => _goToEventHistory(tabIndex: 1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          const _SectionHeader(label: 'Account'),
                          const SizedBox(height: 12),
                          _MenuCard(items: [
                            _MenuItem(
                              icon: Icons.person_outline_rounded,
                              label: 'Edit Profile',
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const EditProfileScreen())),
                            ),
                            _MenuItem(
                              icon: Icons.history_rounded,
                              label: 'Events History',
                              onTap: () => _goToEventHistory(),
                            ),
                            _MenuItem(
                              icon: Icons.library_books_rounded,
                              label: 'Resources',
                              isLast: true,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const ResourcesScreen())),
                            ),
                          ]),

                          const SizedBox(height: 20),
                          const _SectionHeader(label: 'Preferences'),
                          const SizedBox(height: 12),
                          _MenuCard(items: [
                            _MenuItem(
                              icon: Icons.settings_rounded,
                              label: 'Settings',
                              isLast: true,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const SettingsScreen())),
                            ),
                          ]),

                          const SizedBox(height: 20),
                          const _SectionHeader(label: 'Session'),
                          const SizedBox(height: 12),
                          _MenuCard(items: [
                            _MenuItem(
                              icon: Icons.logout_rounded,
                              label: 'Sign Out',
                              isDestructive: true,
                              isLast: true,
                              onTap: () => _handleSignOut(context),
                            ),
                          ]),

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
      },
    );
  }

  Widget _avatarPlaceholder() => Container(
    color: AppColors.primary.withOpacity(0.2),
    child: Center(child: Icon(Icons.person_rounded,
        size: 44, color: Colors.white.withOpacity(0.9))),
  );

  Future<void> _handleSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Sign Out?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: const Text(
            'Are you sure you want to sign out of your account?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.black54, height: 1.5)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade300)),
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0),
            child: const Text('Sign Out',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false);
      }
    }
  }
}

// ── Stat Banner ───────────────────────────────────────────────────────────────
class _StatBanner extends StatelessWidget {
  final String uid;
  final String collection;
  final String userField;
  final String statusFilter;
  final IconData icon;
  final String label;
  final String emptyLabel;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback onTap;

  const _StatBanner({
    required this.uid,
    required this.collection,
    required this.userField,
    required this.statusFilter,
    required this.icon,
    required this.label,
    required this.emptyLabel,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _card(context, 0);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(userField, isEqualTo: uid)
          .where('status', isEqualTo: statusFilter)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return _card(context, count);
      },
    );
  }

  Widget _card(BuildContext context, int count) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
          Border.all(color: AppColors.primary.withOpacity(0.15)),
          boxShadow: [BoxShadow(
              color: AppColors.primary.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const Spacer(),
              Text('$count',
                  style: TextStyle(
                    fontSize: count == 0 ? 20 : 24,
                    fontWeight: FontWeight.w900,
                    color: count == 0
                        ? Colors.black26
                        : AppColors.primary,
                    letterSpacing: -0.5,
                  )),
            ]),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    letterSpacing: 0.1)),
            const SizedBox(height: 2),
            Text(count == 0 ? emptyLabel : '',
                style: const TextStyle(
                    fontSize: 11, color: Colors.black38)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(buttonIcon, color: AppColors.primary, size: 13),
                  const SizedBox(width: 4),
                  Text(buttonLabel,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
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

class _MenuItem {
  final IconData icon;
  final String label;
  final bool isLast;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem(
      {required this.icon,
        required this.label,
        required this.onTap,
        this.isLast = false,
        this.isDestructive = false});
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4))],
      ),
      child: Column(
          children: items
              .map((item) => _MenuTile(item: item))
              .toList()),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final _MenuItem item;
  const _MenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color =
    item.isDestructive ? Colors.red.shade400 : AppColors.primary;
    return Column(
      children: [
        InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.vertical(
              bottom: item.isLast
                  ? const Radius.circular(16)
                  : Radius.zero),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 15),
            child: Row(children: [
              Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(item.icon, color: color, size: 20)),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(item.label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: item.isDestructive
                              ? Colors.red.shade400
                              : const Color(0xFF1A1A1A)))),
              Icon(Icons.chevron_right_rounded,
                  color: color.withOpacity(0.4), size: 20),
            ]),
          ),
        ),
        if (!item.isLast)
          Divider(
              height: 1,
              thickness: 1,
              indent: 68,
              color: AppColors.primary.withOpacity(0.08)),
      ],
    );
  }
}