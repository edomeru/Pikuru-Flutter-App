import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/widgets/event_card.dart';
import 'package:pikuru/widgets/group_card.dart';
import 'package:pikuru/widgets/court_card.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/chats_screen.dart';
import 'package:pikuru/screens/what_is_pikuru_screen.dart';
import 'package:pikuru/screens/about_pikuru_screen.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localised strings (mirrors the web app's T map)
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'upcomingEvents':    'Upcoming events',
    'localGroups':       'Local groups',
    'pickleballCourts':  'Pickleball courts',
    'seeAll':            'See all',
    'whatIsPickleball':  'What is Pickleball?',
    'aboutPikuru':       'About Pikuru',
    'findCourts':        'Find courts near you',
    'browseEvents':      'Browse upcoming events',
    'welcomeTitle':      'Welcome to\nPikuru!',
    'welcomeSub':        'Find courts, join events, and connect\nwith players across Japan.',
    'badgeLabel':        "Japan's #1 Pickleball App",
    'noEvents':          'No events yet',
    'noGroups':          'No groups yet',
    'noCourts':          'No courts yet',
    'unknownLocation':   'Unknown location',
    'dateTbd':           'Date TBD',
    'langEn':            'EN',
    'langJa':            '日本語',
  },
  kLangJa: {
    'upcomingEvents':    '開催予定のイベント',
    'localGroups':       'ローカルグループ',
    'pickleballCourts':  'ピックルボールコート',
    'seeAll':            'すべて見る',
    'whatIsPickleball':  'ピックルボールとは？',
    'aboutPikuru':       'Pikuruについて',
    'findCourts':        '近くのコートを探す',
    'browseEvents':      '開催予定のイベントを見る',
    'welcomeTitle':      'Pikuruへ\nようこそ！',
    'welcomeSub':        '日本全国のコート、イベント、\nプレイヤーとつながろう。',
    'badgeLabel':        '日本No.1ピックルボールアプリ',
    'noEvents':          'イベントはまだありません',
    'noGroups':          'グループはまだありません',
    'noCourts':          'コートはまだありません',
    'unknownLocation':   '場所不明',
    'dateTbd':           '日時未定',
    'langEn':            'EN',
    'langJa':            '日本語',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Direct Firestore provider for home screen events
// ─────────────────────────────────────────────────────────────────────────────
final _homeEventsProvider =
FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final in30  = today.add(const Duration(days: 30));

  final snap = await FirebaseFirestore.instance
      .collection('events')
      .where('event_active',         isEqualTo: true)
      .where('event_checked',        isEqualTo: true)
      .where('event_pending_review', isEqualTo: false)
      .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
      .where('event_date', isLessThanOrEqualTo:    Timestamp.fromDate(in30))
      .orderBy('event_date')
      .limit(50)
      .get();

  final raw = snap.docs
      .map((d) => <String, dynamic>{...d.data(), '_doc_id': d.id})
      .toList();

  final enriched = await Future.wait(raw.map(_resolveEventLocation));

  return enriched.where((e) {
    final pref = (e['_pref'] ?? '').toString().toLowerCase();
    return pref.contains('tokyo') || pref.contains('東京');
  }).take(8).toList();
});

Future<Map<String, dynamic>> _resolveEventLocation(
    Map<String, dynamic> event) async {
  final locId =
  (event['event_loc_id'] ?? event['loc_id'] ?? '').toString().trim();
  Map<String, dynamic> locDoc = {};

  if (locId.isNotEmpty) {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('locations')
          .where('loc_id', isEqualTo: locId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) locDoc = snap.docs.first.data();
    } catch (_) {}
  }

  String get(String key) =>
      ((locDoc[key] ?? event[key] ?? '')).toString().trim();

  final cityEn = [get('loc_city_en'), get('loc_city')].firstWhere(
          (v) => v.isNotEmpty, orElse: () => '');
  final prefEn = [get('loc_prefecture_en'), get('loc_prefecture')].firstWhere(
          (v) => v.isNotEmpty, orElse: () => '');
  final cityJp = [get('loc_city_jp'), get('loc_city')].firstWhere(
          (v) => v.isNotEmpty, orElse: () => '');
  final prefJp = [get('loc_prefecture_jp'), get('loc_prefecture')].firstWhere(
          (v) => v.isNotEmpty, orElse: () => '');
  final country = get('loc_country');

  String locEn = cityEn.isNotEmpty && prefEn.isNotEmpty
      ? '$cityEn, $prefEn'
      : cityEn.isNotEmpty && country.isNotEmpty
      ? '$cityEn, $country'
      : cityEn.isNotEmpty
      ? cityEn
      : prefEn.isNotEmpty
      ? prefEn
      : country;

  String locJp = prefJp.isNotEmpty && cityJp.isNotEmpty
      ? '$prefJp$cityJp'
      : cityJp.isNotEmpty
      ? cityJp
      : prefJp.isNotEmpty
      ? prefJp
      : country;

  return {
    ...event,
    'location':    locEn,
    'location_jp': locJp,
    '_pref':       prefEn,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom pickleball pull-to-refresh widget
// ─────────────────────────────────────────────────────────────────────────────
class _PickleballRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const _PickleballRefresh({
    required this.child,
    required this.onRefresh,
  });

  @override
  State<_PickleballRefresh> createState() => _PickleballRefreshState();
}

class _PickleballRefreshState extends State<_PickleballRefresh>
    with SingleTickerProviderStateMixin {
  static const double _triggerDistance = 80.0;
  static const double _ballSize        = 44.0;

  late AnimationController _spinController;

  double _dragOffset   = 0.0;
  bool   _isRefreshing = false;
  bool   _triggered    = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    if (notification is OverscrollNotification && notification.overscroll < 0) {
      setState(() {
        _dragOffset = (_dragOffset - notification.overscroll)
            .clamp(0.0, _triggerDistance * 1.4);
        _triggered = _dragOffset >= _triggerDistance;
      });
      if (_triggered && !_spinController.isAnimating) {
        _spinController.repeat();
      }
    }

    if (notification is ScrollEndNotification) {
      if (_triggered && !_isRefreshing) {
        _startRefresh();
      } else {
        _resetDrag();
      }
    }

    return false;
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
      _dragOffset   = _triggerDistance;
    });
    if (!_spinController.isAnimating) _spinController.repeat();
    await widget.onRefresh();
    if (mounted) _resetDrag();
  }

  void _resetDrag() {
    _spinController.stop();
    setState(() {
      _dragOffset   = 0.0;
      _isRefreshing = false;
      _triggered    = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress         = (_dragOffset / _triggerDistance).clamp(0.0, 1.0);
    final indicatorVisible = _dragOffset > 4.0;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        children: [
          AnimatedPadding(
            duration: _isRefreshing
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            padding: EdgeInsets.only(top: _dragOffset.clamp(0.0, _triggerDistance)),
            child: widget.child,
          ),
          if (indicatorVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: _dragOffset.clamp(0.0, _triggerDistance),
                child: Center(
                  child: Opacity(
                    opacity: progress.clamp(0.2, 1.0),
                    child: RotationTransition(
                      turns: _isRefreshing || _triggered
                          ? _spinController
                          : AlwaysStoppedAnimation(progress * 1.5),
                      child: Image.asset(
                        'assets/pickleball_ball_no_bg_1.png',
                        width:  _ballSize * (0.6 + 0.4 * progress),
                        height: _ballSize * (0.6 + 0.4 * progress),
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

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // ── Unread count streams ───────────────────────────────────────────────────
  int _unreadCount      = 0;
  int _individualUnread = 0;
  int _groupUnread      = 0;

  @override
  void initState() {
    super.initState();
    _listenUnread();
  }

  void _listenUnread() {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    // ── Individual chats ──────────────────────────────────────────────────────
    FirebaseFirestore.instance
        .collection('individual_chats')
        .where('participants', arrayContains: me.uid)
        .snapshots()
        .listen((snap) {
      int count = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final lastMsg = (d['last_message'] ?? '').toString();
        if (lastMsg.isEmpty) continue;
        if ((d['last_message_by'] ?? '') == me.uid) continue;
        final lastReadMap = d['last_read'] as Map<String, dynamic>?;
        final myLastRead  = lastReadMap != null
            ? (lastReadMap[me.uid] as Timestamp?)?.toDate()
            : null;
        final lastMsgAt = (d['last_message_at'] as Timestamp?)?.toDate();
        if (lastMsgAt != null &&
            (myLastRead == null || lastMsgAt.isAfter(myLastRead))) {
          count++;
        }
      }
      if (mounted) {
        setState(() {
          _individualUnread = count;
          _unreadCount = _individualUnread + _groupUnread;
        });
      }
    });

    // ── Group chats ────────────────────────────────────────────────────────────
    FirebaseFirestore.instance
        .collection('group_chats')
        .snapshots()
        .listen((snap) async {
      int count = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        if ((d['last_message'] ?? '').toString().isEmpty) continue;
        if ((d['last_message_by'] ?? '') == me.uid) continue;
        try {
          final pDoc = await FirebaseFirestore.instance
              .collection('group_chats')
              .doc(doc.id)
              .collection('participants')
              .doc(me.uid)
              .get();
          if (!pDoc.exists) continue;
          final lastRead =
          (pDoc.data()?['last_read_at'] as Timestamp?)?.toDate();
          final lastMsg = (d['last_message_at'] as Timestamp?)?.toDate();
          if (lastMsg != null &&
              (lastRead == null || lastMsg.isAfter(lastRead))) {
            count++;
          }
        } catch (_) {
          continue;
        }
      }
      if (mounted) {
        setState(() {
          _groupUnread = count;
          _unreadCount = _individualUnread + _groupUnread;
        });
      }
    });
  }

  // ── Refresh: invalidate all three home-screen providers ──────────────────
  Future<void> _refresh() async {
    ref.invalidate(_homeEventsProvider);
    ref.invalidate(organizationsProvider);
    ref.invalidate(locationsProvider);
    // Wait for the primary events provider to settle before hiding the ball
    await ref.read(_homeEventsProvider.future).catchError((_) => <Map<String, dynamic>>[]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers (mirror web app logic)
  // ─────────────────────────────────────────────────────────────────────────

  String _eventTitle(Map<String, dynamic> data, String lang) {
    if (lang == kLangJa) {
      final jp = (data['event_title_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (data['event_title'] ?? 'Untitled').toString();
  }

  String _groupName(Map<String, dynamic> data, String lang) {
    if (lang == kLangJa) {
      final jp = (data['org_name_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (data['org_name'] ?? 'Unnamed Group').toString();
  }

  String _courtName(Map<String, dynamic> data, String lang) {
    if (lang == kLangJa) {
      final jp = (data['loc_name_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (data['loc_name'] ?? 'Unnamed Court').toString();
  }

  String _courtLocation(Map<String, dynamic> data, String lang) {
    final String city = lang == kLangJa
        ? ((data['loc_city_jp'] ?? data['loc_city'] ?? '').toString().trim())
        : ((data['loc_city_en'] ?? data['loc_city'] ?? '').toString().trim());
    final String country = (data['loc_country'] ?? '').toString().trim();

    if (city.isNotEmpty && country.isNotEmpty && lang != kLangJa) {
      return '$city, $country';
    }
    if (city.isNotEmpty) return city;
    return '';
  }

  String _formatEventDateTime(Map<String, dynamic> data, String lang) {
    final rawDate = data['event_date'];
    final rawTime = data['event_time'];

    String dateStr = '';
    if (rawDate is Timestamp) {
      final d = rawDate.toDate();
      if (lang == kLangJa) {
        const jpWeekdays = ['日', '月', '火', '水', '木', '金', '土'];
        final weekday = jpWeekdays[d.weekday % 7];
        dateStr = '${d.month}月${d.day}日($weekday)';
      } else {
        dateStr = DateFormat('EEE, MMM d').format(d);
      }
    }

    String timeStr = '';
    if (rawTime is Timestamp) {
      final t = rawTime.toDate();
      if (lang == kLangJa) {
        timeStr = '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
      } else {
        timeStr = DateFormat('h:mm a').format(t);
      }
    } else if (rawTime is String && rawTime.isNotEmpty) {
      timeStr = rawTime;
    }

    if (dateStr.isNotEmpty && timeStr.isNotEmpty) return '$dateStr · $timeStr';
    if (dateStr.isNotEmpty) return dateStr;
    return _t(lang, 'dateTbd');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: SizedBox(
          height: 132,
          child: Image.asset('assets/pikuru_logo.png', fit: BoxFit.contain),
        ),
        centerTitle: true,
        actions: [
          // ── EN / JP language toggle ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LangButton(
                    label: _t(lang, 'langEn'),
                    selected: lang == kLangEn,
                    onTap: () =>
                        ref.read(appLangProvider.notifier).setLang(kLangEn),
                  ),
                  _LangButton(
                    label: _t(lang, 'langJa'),
                    selected: lang == kLangJa,
                    onTap: () =>
                        ref.read(appLangProvider.notifier).setLang(kLangJa),
                  ),
                ],
              ),
            ),
          ),
          // ── Chat icon with unread badge ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatsScreen()),
              ).then((_) {
                if (mounted) _listenUnread();
              }),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(
                            minWidth: 18, minHeight: 18),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(10),
                          border:
                          Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _unreadCount > 99 ? '99+' : '$_unreadCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      // ── Body: _PickleballRefresh wraps the entire ScrollView ────────────
      body: _PickleballRefresh(
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ── UPCOMING EVENTS ────────────────────────────────────────
                _sectionHeader(
                  _t(lang, 'upcomingEvents'),
                  onSeeAll: () => widget.onNavigateToTab?.call(2),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                SizedBox(height: 265, child: _buildEventsSection(ref, lang)),

                const SizedBox(height: 30),
                _divider(),
                const SizedBox(height: 20),

                // ── LOCAL GROUPS ───────────────────────────────────────────
                _sectionHeader(
                  _t(lang, 'localGroups'),
                  onSeeAll: () => widget.onNavigateToTab?.call(3),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                SizedBox(height: 235, child: _buildGroupsSection(ref, lang)),

                const SizedBox(height: 30),
                _divider(),
                const SizedBox(height: 20),

                // ── PICKLEBALL COURTS ──────────────────────────────────────
                _sectionHeader(
                  _t(lang, 'pickleballCourts'),
                  onSeeAll: () {
                    ref.read(focusedCourtIdProvider.notifier).state = null;
                    ref.read(resetCourtsFilterProvider.notifier).state++;
                    widget.onNavigateToTab?.call(1);
                  },
                  lang: lang,
                ),
                const SizedBox(height: 16),
                SizedBox(height: 240, child: _buildCourtsSection(ref, lang)),

                const SizedBox(height: 30),

                // ── WELCOME CARD ───────────────────────────────────────────
                _buildWelcomeCard(context, lang),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Welcome card (localised)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWelcomeCard(BuildContext context, String lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, const Color(0xFF0D3D26), 0.55)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30, top: -30,
            child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06))),
          ),
          Positioned(
            right: 30, bottom: -20,
            child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05))),
          ),
          Positioned(
            left: -20, bottom: 20,
            child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25), width: 1),
                  ),
                  child: Text(
                    '🎾  ${_t(lang, 'badgeLabel')}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t(lang, 'welcomeTitle'),
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -1.0),
                ),
                const SizedBox(height: 10),
                Text(
                  _t(lang, 'welcomeSub'),
                  style: TextStyle(
                      fontSize: 14.5,
                      color: Colors.white.withOpacity(0.75),
                      height: 1.55,
                      letterSpacing: 0.1),
                ),
                const SizedBox(height: 24),

                _quickActionStrip(
                  icon: Icons.location_on_rounded,
                  label: _t(lang, 'findCourts'),
                  onTap: () => widget.onNavigateToTab?.call(1),
                ),
                const SizedBox(height: 10),
                _quickActionStrip(
                  icon: Icons.event_rounded,
                  label: _t(lang, 'browseEvents'),
                  onTap: () => widget.onNavigateToTab?.call(2),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _cardButton(
                        label: _t(lang, 'whatIsPickleball'),
                        isPrimary: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WhatIsPikuruScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _cardButton(
                        label: _t(lang, 'aboutPikuru'),
                        isPrimary: false,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AboutPikuruScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionStrip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border:
          Border.all(color: Colors.white.withOpacity(0.18), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.2)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _cardButton({
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(
              color: Colors.white.withOpacity(0.3), width: 1.2),
          boxShadow: isPrimary
              ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]
              : null,
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPrimary ? AppColors.primary : Colors.white,
                letterSpacing: -0.2)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Events section
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEventsSection(WidgetRef ref, String lang) {
    final eventsAsync = ref.watch(_homeEventsProvider);
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Center(child: Text(_t(lang, 'noEvents')));
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: events.length,
          itemBuilder: (context, index) {
            final data              = events[index];
            final imageUrl          = (data['event_pic'] ??
                data['event_pic_thumbnail'] ??
                data['event_image'] ??
                '')
                .toString();
            final title             = _eventTitle(data, lang);
            final formattedDateTime = _formatEventDateTime(data, lang);
            final location = lang == kLangJa
                ? (data['location_jp'] ?? data['location'] ?? '').toString()
                : (data['location'] ?? '').toString();

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: data),
                ),
              ),
              child: EventCard(
                imageUrl: imageUrl,
                title: title,
                dateTime: formattedDateTime,
                location: location.isNotEmpty
                    ? location
                    : _t(lang, 'unknownLocation'),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Groups section
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGroupsSection(WidgetRef ref, String lang) {
    final orgsAsync = ref.watch(organizationsProvider);
    return orgsAsync.when(
      data: (orgs) {
        if (orgs.isEmpty) {
          return Center(child: Text(_t(lang, 'noGroups')));
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: orgs.length,
          itemBuilder: (context, index) {
            final data     = orgs[index];
            final name     = _groupName(data, lang);
            final orgLocId = (data['org_loc_id'] ?? '').toString();

            return Consumer(
              builder: (context, ref, child) {
                final locationAsync =
                ref.watch(locationResolverProvider(orgLocId));
                return locationAsync.when(
                  data: (locationEn) {
                    final location = lang == kLangJa
                        ? (data['location_jp'] as String? ?? '').isNotEmpty
                        ? (data['location_jp'] as String)
                        : locationEn
                        : locationEn;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(group: data),
                        ),
                      ),
                      child: GroupCard(
                          imageUrl:
                          (data['org_image'] ?? '').toString(),
                          name: name,
                          location: location),
                    );
                  },
                  loading: () => GroupCard(
                      imageUrl: (data['org_image'] ?? '').toString(),
                      name: name,
                      location: '...'),
                  error: (_, __) => GroupCard(
                      imageUrl: (data['org_image'] ?? '').toString(),
                      name: name,
                      location: _t(lang, 'unknownLocation')),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Courts section
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCourtsSection(WidgetRef ref, String lang) {
    final courtsAsync = ref.watch(locationsProvider);
    return courtsAsync.when(
      data: (allCourts) {
        final courts = allCourts.where((d) {
          final pref = (d['loc_prefecture_en'] ?? d['loc_prefecture'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return pref == 'tokyo' || pref == '東京' || pref.contains('tokyo');
        }).toList();
        if (courts.isEmpty) {
          return Center(child: Text(_t(lang, 'noCourts')));
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: courts.length,
          itemBuilder: (context, index) {
            final data     = courts[index];
            final name     = _courtName(data, lang);
            final location = _courtLocation(data, lang);

            return GestureDetector(
              onTap: () {
                final docId = (data['_doc_id'] ?? '').toString();
                if (docId.isNotEmpty) {
                  ref.read(focusedCourtIdProvider.notifier).state = docId;
                }
                widget.onNavigateToTab?.call(1);
              },
              child: CourtCard(
                imageUrl: (data['loc_image'] ?? '').toString(),
                name: name,
                location: location.isNotEmpty
                    ? location
                    : _t(lang, 'unknownLocation'),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────────────────────────────────
  Widget _sectionHeader(
      String title, {
        required VoidCallback onSeeAll,
        required String lang,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: onSeeAll,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _t(lang, 'seeAll'),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(height: 1, color: const Color(0xFFEEEFF1));
}

// ─────────────────────────────────────────────────────────────────────────────
// _LangButton — reusable pill segment
// ─────────────────────────────────────────────────────────────────────────────
class _LangButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : AppColors.primary.withOpacity(0.6)),
        ),
      ),
    );
  }
}