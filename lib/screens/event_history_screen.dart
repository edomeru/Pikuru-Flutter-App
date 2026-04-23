import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════════════════
// Translations
// ═══════════════════════════════════════════════════════════════════
const _T = {
  'en': {
    'pageTitle': 'Events History',
    'tabMyEvents': 'My Events',
    'tabInterested': 'Interested Events',
    'noMyEvents': 'No saved events yet',
    'noMyEventsSub': 'Events you plan to join will appear here',
    'noInterested': 'No interested events yet',
    'noInterestedSub': 'Events you want to keep an eye on will appear here',
    'markMyEvent': 'Mark as My Event',
    'markInterested': 'Mark as Interested',
    'movedTo': 'Moved to',
    'removeTitle': 'Remove Event?',
    'removeDesc': 'This event will be removed from your saved list.',
    'cancel': 'Cancel',
    'remove': 'Remove',
    'notSignedIn': 'Not signed in',
    'errLoad': 'Something went wrong',
    'myEventsLabel': 'My Events',
    'interestedLabel': 'Interested',
  },
  'ja': {
    'pageTitle': 'イベント履歴',
    'tabMyEvents': '参加イベント',
    'tabInterested': '興味あり',
    'noMyEvents': '保存したイベントはまだありません',
    'noMyEventsSub': '参加予定のイベントがここに表示されます',
    'noInterested': '興味のあるイベントはまだありません',
    'noInterestedSub': '気になるイベントがここに表示されます',
    'markMyEvent': '参加イベントにする',
    'markInterested': '興味ありにする',
    'movedTo': '移動しました：',
    'removeTitle': 'イベントを削除しますか？',
    'removeDesc': 'このイベントは保存リストから削除されます。',
    'cancel': 'キャンセル',
    'remove': '削除',
    'notSignedIn': 'ログインしていません',
    'errLoad': '読み込みに失敗しました',
    'myEventsLabel': '参加イベント',
    'interestedLabel': '興味あり',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T['en']![key]) ?? key;

// Japanese weekday names — no locale initialization needed
const _jaWeekdays = ['月', '火', '水', '木', '金', '土', '日'];

/// Formats a [DateTime] as Japanese date string without requiring
/// initializeDateFormatting — e.g. "2025年4月20日(日)"
String _jaDateString(DateTime d) {
  final wd = _jaWeekdays[d.weekday - 1]; // weekday: 1=Mon … 7=Sun
  return '${d.year}年${d.month}月${d.day}日($wd)';
}

// ═══════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════
class EventHistoryScreen extends ConsumerStatefulWidget {
  /// Which tab to open on: 0 = My Events, 1 = Interested Events.
  final int initialTab;

  /// Called when the user taps the back button.
  final VoidCallback? onBack;

  const EventHistoryScreen({
    super.key,
    this.initialTab = 0,
    this.onBack,
  });

  @override
  ConsumerState<EventHistoryScreen> createState() =>
      _EventHistoryScreenState();
}

class _EventHistoryScreenState extends ConsumerState<EventHistoryScreen>
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

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context);
    }
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
              onTap: _handleBack,
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
                    Tab(text: _t(lang, 'tabMyEvents')),
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
            _EventList(status: 'my_events', lang: lang),
            _EventList(status: 'interested', lang: lang),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Event List
// ═══════════════════════════════════════════════════════════════════
class _EventList extends StatelessWidget {
  final String status;
  final String lang;

  const _EventList({required this.status, required this.lang});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Center(
        child: Text(
          _t(lang, 'notSignedIn'),
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_events')
          .where('user_id', isEqualTo: uid)
          .where('status', isEqualTo: status)
          .orderBy('saved_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2));
        }
        if (snap.hasError) {
          return _EmptyState(
            icon: Icons.error_outline_rounded,
            title: _t(lang, 'errLoad'),
            subtitle: snap.error.toString(),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: status == 'my_events'
                ? Icons.bookmark_outline_rounded
                : Icons.star_outline_rounded,
            title: status == 'my_events'
                ? _t(lang, 'noMyEvents')
                : _t(lang, 'noInterested'),
            subtitle: status == 'my_events'
                ? _t(lang, 'noMyEventsSub')
                : _t(lang, 'noInterestedSub'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _EventCard(
              userEventDoc: docs[i],
              savedData: data,
              otherStatus:
              status == 'my_events' ? 'interested' : 'my_events',
              lang: lang,
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Event Card
// ═══════════════════════════════════════════════════════════════════
class _EventCard extends StatelessWidget {
  final QueryDocumentSnapshot userEventDoc;
  final Map<String, dynamic> savedData;
  final String otherStatus;
  final String lang;

  const _EventCard({
    required this.userEventDoc,
    required this.savedData,
    required this.otherStatus,
    required this.lang,
  });

  Future<Map<String, dynamic>?> _fetchEvent() async {
    final eventId = (savedData['event_id'] ?? '').toString();
    if (eventId.isEmpty) return null;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      if (docSnap.exists) {
        final d = docSnap.data()!;
        d['_doc_id'] = docSnap.id;
        return d;
      }
      final q = await FirebaseFirestore.instance
          .collection('events')
          .where('event_id', isEqualTo: eventId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        d['_doc_id'] = q.docs.first.id;
        return d;
      }
    } catch (_) {}
    return null;
  }

  /// Picks the localised title: uses `event_title_jp` when lang is 'ja'
  /// and the field is non-empty, otherwise falls back to `event_title`.
  String _localTitle(Map<String, dynamic>? eventData) {
    if (lang == kLangJa) {
      final jp = (eventData?['event_title_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (eventData?['event_title'] ??
        savedData['event_title'] ??
        'Loading...')
        .toString();
  }

  /// Converts raw Firestore date to a display string.
  /// Uses plain DateFormat for English, manual string for Japanese
  /// (avoids initializeDateFormatting requirement).
  String _formatDate(dynamic raw) {
    DateTime? d;
    if (raw is Timestamp) {
      d = raw.toDate();
    } else if (raw is String && raw.isNotEmpty) {
      try {
        d = DateTime.parse(raw);
      } catch (_) {
        return raw; // return as-is if unparseable
      }
    }
    if (d == null) return '';

    if (lang == kLangJa) {
      return _jaDateString(d);
    }
    return DateFormat('MMM d, yyyy').format(d);
  }

  String _formatTime(dynamic raw) {
    if (raw is Timestamp) {
      final d = raw.toDate();
      // Use 24-hour format for Japanese, 12-hour for English — no locale needed
      if (lang == kLangJa) {
        return DateFormat('H:mm').format(d);
      }
      return DateFormat('h:mm a').format(d);
    }
    if (raw is String && raw.isNotEmpty) return raw;
    return '';
  }

  Future<void> _switchStatus(BuildContext context) async {
    HapticFeedback.lightImpact();
    final label = otherStatus == 'my_events'
        ? _t(lang, 'myEventsLabel')
        : _t(lang, 'interestedLabel');
    try {
      await userEventDoc.reference.update({'status': otherStatus});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_t(lang, 'movedTo')} $label'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {}
  }

  Future<void> _removeEvent(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          _t(lang, 'removeTitle'),
          style:
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          _t(lang, 'removeDesc'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, color: Colors.black54, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Text(_t(lang, 'cancel'),
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(_t(lang, 'remove'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await userEventDoc.reference.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchEvent(),
      builder: (context, snap) {
        final title = _localTitle(snap.data);
        final imageUrl =
        (snap.data?['event_pic'] ?? savedData['event_pic'] ?? '')
            .toString();
        final dateStr =
        snap.data != null ? _formatDate(snap.data!['event_date']) : '';
        final timeStr =
        snap.data != null ? _formatTime(snap.data!['event_time']) : '';
        final locCity = snap.data != null
            ? (snap.data!['_loc_city'] ?? '').toString()
            : '';

        final switchLabel = otherStatus == 'my_events'
            ? _t(lang, 'markMyEvent')
            : _t(lang, 'markInterested');
        final switchIcon = otherStatus == 'my_events'
            ? Icons.bookmark_rounded
            : Icons.star_rounded;
        final switchColor = otherStatus == 'my_events'
            ? AppColors.primary
            : const Color(0xFFE6A817);

        return GestureDetector(
          onTap: snap.data != null
              ? () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EventDetailScreen(event: snap.data!),
            ),
          )
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholder())
                            : _placeholder(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D0D0D),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            if (dateStr.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 12,
                                    color: AppColors.primary
                                        .withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    timeStr.isNotEmpty
                                        ? '$dateStr · $timeStr'
                                        : dateStr,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black
                                            .withOpacity(0.5),
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ],
                            if (locCity.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.location_on_rounded,
                                    size: 12,
                                    color: AppColors.primary
                                        .withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(locCity,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black
                                              .withOpacity(0.5)),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.primary.withOpacity(0.3),
                          size: 20),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F9F7),
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchStatus(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 11, horizontal: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(switchIcon,
                                    color: switchColor, size: 14),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(switchLabel,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: switchColor),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 20,
                          color: AppColors.primary.withOpacity(0.12)),
                      GestureDetector(
                        onTap: () => _removeEvent(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 11, horizontal: 16),
                          child: Icon(Icons.delete_outline_rounded,
                              color: Colors.red.shade400, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
    width: 76,
    height: 76,
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(Icons.event_rounded,
        color: AppColors.primary.withOpacity(0.3), size: 32),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: Icon(icon,
                  color: AppColors.primary.withOpacity(0.4), size: 36),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D0D0D)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.4),
                    height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}