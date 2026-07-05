import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Translations
// ─────────────────────────────────────────────────────────────────────────────
const _T = {
  'en': {
    'pageTitle': 'Joined Groups',
    'tabJoined': 'Joined Groups',
    'tabInterested': 'Favorited Groups',
    'loading': 'Loading groups...',
    'errLoad': 'Something went wrong loading groups.',
    'noJoined': 'No joined groups yet',
    'noJoinedSub': 'Groups you join will appear here',
    'noInterested': 'No favorited groups yet',
    'noInterestedSub': 'Groups you favorited will appear here',
    'notSignedIn': 'You are not signed in.',
    'statusOrganizer': 'Organizer',
    'statusMember': 'Member',
    'statusInterested': 'Favorited',
    'joinedOn': 'Joined',
    'markedOn': 'Favorited since',
    'browseGroups': 'Browse Groups',
  },
  'ja': {
    'pageTitle': '参加グループ',
    'tabJoined': '参加グループ',
    'tabInterested': 'お気に入り',
    'loading': '読み込み中...',
    'errLoad': 'グループの読み込みに失敗しました。',
    'noJoined': '参加中のグループはまだありません',
    'noJoinedSub': '参加したグループがここに表示されます',
    'noInterested': 'お気に入りグループはまだありません',
    'noInterestedSub': 'お気に入りのグループがここに表示されます',
    'notSignedIn': 'ログインしていません。',
    'statusOrganizer': 'オーガナイザー',
    'statusMember': 'メンバー',
    'statusInterested': 'お気に入り',
    'joinedOn': '参加日',
    'markedOn': 'お気に入り登録日',
    'browseGroups': 'グループを探す',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T['en']![key]) ?? key;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class GroupHistoryScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const GroupHistoryScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<GroupHistoryScreen> createState() => _GroupHistoryScreenState();
}

class _GroupHistoryScreenState extends ConsumerState<GroupHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            automaticallyImplyLeading: false,
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
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: _t(lang, 'tabJoined')),
                    Tab(text: _t(lang, 'tabInterested')),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _GroupList(tab: 'joined', lang: lang),
            _GroupList(tab: 'interested', lang: lang),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group List
// ─────────────────────────────────────────────────────────────────────────────
class _GroupList extends StatefulWidget {
  final String tab; // 'joined' | 'interested'
  final String lang;

  const _GroupList({required this.tab, required this.lang});

  @override
  State<_GroupList> createState() => _GroupListState();
}

class _GroupListState extends State<_GroupList> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;          // joined tab
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _favStream; // favorited tab
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _buildStream();
  }

  void _buildStream() {
    final uid = _uid;
    if (uid == null) return;

    if (widget.tab == 'joined') {
      _stream = FirebaseFirestore.instance
          .collection('user_groups')
          .where('user_id', isEqualTo: uid)
          .where('status', whereIn: ['active', 'pending', 'approved', 'rejected', 'removed'])
          .snapshots();
    } else {
      // Favorited tab: fetch all user's records and filter client-side so we
      // catch both legacy (status == 'interested') and new (is_favorite == true) entries.
      _favStream = FirebaseFirestore.instance
          .collection('user_groups')
          .where('user_id', isEqualTo: uid)
          .snapshots()
          .map((snap) => snap.docs.where((d) {
                final data = d.data();
                return data['status'] == 'interested' || data['is_favorite'] == true;
              }).toList());
    }
  }

  int _sortMillis(Map<String, dynamic> item) {
    final v = item['joined_at'] ?? item['marked_at'] ?? item['requested_at'];
    if (v == null) return 0;
    if (v is Timestamp) return v.toDate().millisecondsSinceEpoch;
    if (v is DateTime) return v.millisecondsSinceEpoch;
    return 0;
  }

  Widget _buildList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return _EmptyState(
        icon: widget.tab == 'joined'
            ? Icons.groups_outlined
            : Icons.favorite_border_rounded,
        title: widget.tab == 'joined'
            ? _t(widget.lang, 'noJoined')
            : _t(widget.lang, 'noInterested'),
        subtitle: widget.tab == 'joined'
            ? _t(widget.lang, 'noJoinedSub')
            : _t(widget.lang, 'noInterestedSub'),
        lang: widget.lang,
        showBrowse: true,
      );
    }
    final sortedDocs = docs.toList()
      ..sort((a, b) {
        final aMs = _sortMillis(a.data());
        final bMs = _sortMillis(b.data());
        return bMs.compareTo(aMs);
      });
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: sortedDocs.length,
      itemBuilder: (context, i) {
        final docSnap = sortedDocs[i];
        return _GroupHistoryCard(
          data: docSnap.data(),
          docId: docSnap.id,
          uid: _uid!,
          lang: widget.lang,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Center(
        child: Text(
          _t(widget.lang, 'notSignedIn'),
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }

    if (widget.tab == 'interested') {
      // Use dedicated list stream for the Favorited tab
      return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _favStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2));
          }
          if (snap.hasError) {
            return _EmptyState(
              icon: Icons.error_outline_rounded,
              title: _t(widget.lang, 'errLoad'),
              subtitle: snap.error.toString(),
              lang: widget.lang,
            );
          }
          return _buildList(snap.data ?? []);
        },
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2));
        }
        if (snap.hasError) {
          return _EmptyState(
            icon: Icons.error_outline_rounded,
            title: _t(widget.lang, 'errLoad'),
            subtitle: snap.error.toString(),
            lang: widget.lang,
          );
        }
        return _buildList(snap.data?.docs ?? []);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Card
// ─────────────────────────────────────────────────────────────────────────────
class _GroupHistoryCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String uid;
  final String lang;

  const _GroupHistoryCard({
    required this.data,
    required this.docId,
    required this.uid,
    required this.lang,
  });

  @override
  State<_GroupHistoryCard> createState() => _GroupHistoryCardState();
}

class _GroupHistoryCardState extends State<_GroupHistoryCard> {
  bool _isCreator = false;

  String get _groupId {
    final rawGroupId = widget.data['group_id'] ?? widget.data['org_id'] ?? '';
    if (rawGroupId.isNotEmpty) return rawGroupId.toString();
    if (widget.docId.contains('_')) {
      return widget.docId.split('_')[1];
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _checkCreator();
  }

  Future<void> _checkCreator() async {
    final gid = _groupId;
    if (gid.isEmpty) return;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(gid)
          .get();

      if (docSnap.exists) {
        final submitBy = docSnap.data()?['submittedBy']?.toString() ?? '';
        final addedBy = docSnap.data()?['org_addedby']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _isCreator = (submitBy == widget.uid) || (addedBy == widget.uid);
          });
        }
      } else {
        // query fallback
        final qSnap = await FirebaseFirestore.instance
            .collection('organizations')
            .where('org_id', isEqualTo: gid)
            .limit(1)
            .get();

        if (qSnap.docs.isNotEmpty) {
          final submitBy = qSnap.docs.first.data()['submittedBy']?.toString() ?? '';
          final addedBy = qSnap.docs.first.data()['org_addedby']?.toString() ?? '';
          if (mounted) {
            setState(() {
              _isCreator = (submitBy == widget.uid) || (addedBy == widget.uid);
            });
          }
        }
      }
    } catch (_) {}
  }

  void _navigateToDetail() {
    final gid = _groupId;
    if (gid.isEmpty) return;

    // Load full group detail and navigate
    FirebaseFirestore.instance
        .collection('organizations')
        .doc(gid)
        .get()
        .then((docSnap) {
      if (docSnap.exists) {
        final gData = {
          ...docSnap.data()!,
          '_doc_id': docSnap.id,
        };
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(group: gData),
            ),
          );
        }
      } else {
        FirebaseFirestore.instance
            .collection('organizations')
            .where('org_id', isEqualTo: gid)
            .limit(1)
            .get()
            .then((qSnap) {
          if (qSnap.docs.isNotEmpty) {
            final gData = {
              ...qSnap.docs.first.data(),
              '_doc_id': qSnap.docs.first.id,
            };
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(group: gData),
                ),
              );
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gName = widget.data['group_name'] ??
        (widget.lang == 'ja' ? '不明なグループ' : 'Unknown Group');
    final gImage = widget.data['group_image'] ?? '';
    final status = widget.data['status'] ?? 'active';

    final dateTs = widget.data['joined_at'] ?? widget.data['marked_at'];
    final dateLabel = status == 'interested'
        ? _t(widget.lang, 'markedOn')
        : _t(widget.lang, 'joinedOn');
    String dateStr = '';
    if (dateTs is Timestamp) {
      final dt = dateTs.toDate();
      dateStr = widget.lang == 'ja'
          ? '${dt.year}年${dt.month}月${dt.day}日'
          : DateFormat.yMMMd().format(dt);
    }

    // Badge styling
    String badgeLabel;
    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;

    if (status == 'interested') {
      badgeLabel = _t(widget.lang, 'statusInterested');
      badgeColor = const Color(0xFFF97316);
      badgeBg = const Color(0xFFF97316).withOpacity(0.12);
      badgeIcon = Icons.favorite_rounded;
    } else if (_isCreator) {
      badgeLabel = _t(widget.lang, 'statusOrganizer');
      badgeColor = const Color(0xFF818CF8);
      badgeBg = const Color(0xFF818CF8).withOpacity(0.12);
      badgeIcon = Icons.star_rounded;
    } else {
      badgeLabel = _t(widget.lang, 'statusMember');
      badgeColor = AppColors.primary;
      badgeBg = AppColors.primary.withOpacity(0.12);
      badgeIcon = Icons.check_circle_outline_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _navigateToDetail,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: gImage.isNotEmpty
                      ? Image.network(gImage, fit: BoxFit.cover)
                      : const Center(
                          child: Icon(Icons.groups_rounded,
                              color: Colors.black26, size: 32)),
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: Colors.black.withOpacity(0.4)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$dateLabel · $dateStr',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.4),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: badgeColor.withOpacity(0.25), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 10, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Chevron
              Icon(Icons.chevron_right_rounded,
                  color: Colors.black.withOpacity(0.15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String lang;
  final bool showBrowse;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.lang,
    this.showBrowse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.4),
              height: 1.4,
            ),
          ),
          if (showBrowse) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate back to the home tabs & select groups tab
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _t(lang, 'browseGroups'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
