import 'dart:async';
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
// Translations — mirrors the web app (page.tsx → const T)
// ═══════════════════════════════════════════════════════════════════
const _T = {
  'en': {
    'pageTitle': 'Events History',
    'tabMyEvents': 'Registered Events',
    'tabInterested': 'Favorited Events',
    'loading': 'Loading events...',
    'errLoad': 'Something went wrong loading events.',
    'noMyEvents': 'No saved events yet',
    'noMyEventsSub': 'Events you plan to join will appear here',
    'noInterested': 'No interested events yet',
    'noInterestedSub': 'Events you want to keep an eye on will appear here',
    'markMyEvent': 'Mark as Registered Self - Reported',
    'markInterested': 'Mark as Favorite',
    'removeTitle': 'Remove Event?',
    'removeDesc': 'This event will be removed from your saved list.',
    'cancel': 'Cancel',
    'remove': 'Remove',
    'notSignedIn': 'You are not signed in.',
    'cancelReg': 'Cancel Registration',
    'cancelRegTitle': 'Cancel Registration?',
    'cancelRegDesc': 'This will cancel your registration for this event.',
    'movedTo': 'Moved to',
    'myEventsLabel': 'Registered Events',
    'interestedLabel': 'Favorited Events',
    'badgeRegistered': 'Registered',
    'badgeSelfReported': 'Registered · Self-Reported',
    'badgePending': 'Pending',
    'badgeApproved': 'Approved',
    'badgeWaitlist': 'Waitlist',
    'badgeRejected': 'Rejected',
  },
  'ja': {
    'pageTitle': 'イベント履歴',
    'tabMyEvents': '登録済みイベント',
    'tabInterested': 'お気に入りイベント',
    'loading': '読み込み中...',
    'errLoad': 'イベントの読み込みに失敗しました。',
    'noMyEvents': '保存したイベントはまだありません',
    'noMyEventsSub': '参加予定のイベントがここに表示されます',
    'noInterested': '興味のあるイベントはまだありません',
    'noInterestedSub': '気になるイベントがここに表示されます',
    'markMyEvent': '登録済み・自己申告にする',
    'markInterested': '興味ありにする',
    'removeTitle': 'イベントを削除しますか？',
    'removeDesc': 'このイベントは保存リストから削除されます。',
    'cancel': 'キャンセル',
    'remove': '削除',
    'notSignedIn': 'ログインしていません。',
    'cancelReg': '登録をキャンセル',
    'cancelRegTitle': '登録をキャンセルしますか？',
    'cancelRegDesc': 'このイベントの登録がキャンセルされます。',
    'movedTo': '移動しました：',
    'myEventsLabel': '登録済みイベント',
    'interestedLabel': 'お気に入りイベント',
    'badgeRegistered': '登録済み',
    'badgeSelfReported': '登録済み・自己申告',
    'badgePending': '審査中',
    'badgeApproved': '承認済み',
    'badgeWaitlist': 'ウェイティング',
    'badgeRejected': '却下',
  },
};

String _t(String lang, String key) =>
    (_T[lang]?[key] ?? _T['en']![key]) ?? key;

// Japanese weekday names — no locale initialization needed
const _jaWeekdays = ['月', '火', '水', '木', '金', '土', '日'];

String _jaDateString(DateTime d) {
  final wd = _jaWeekdays[d.weekday - 1];
  return '${d.year}年${d.month}月${d.day}日($wd)';
}

int _sortMillis(Map<String, dynamic> item) {
  final v = item['saved_at'] ?? item['registered_at'];
  if (v == null) return 0;
  if (v is Timestamp) return v.toDate().millisecondsSinceEpoch;
  if (v is DateTime) return v.millisecondsSinceEpoch;
  if (v is String) {
    try {
      return DateTime.parse(v).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }
  return 0;
}

// ═══════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════
class EventHistoryScreen extends ConsumerStatefulWidget {
  /// Which tab to open on: 0 = Registered Events, 1 = Favorited Events.
  final int initialTab;
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
// Event List — merges user_events + event_registrations (web parity)
// ═══════════════════════════════════════════════════════════════════
class _EventList extends StatefulWidget {
  final String status; // 'my_events' | 'interested'
  final String lang;

  const _EventList({required this.status, required this.lang});

  @override
  State<_EventList> createState() => _EventListState();
}

class _EventListState extends State<_EventList> {
  Stream<List<_SavedItem>>? _stream;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _stream = _buildStream();
  }

  Stream<List<_SavedItem>>? _buildStream() {
    final uid = _uid;
    if (uid == null) return null;

    final userEventsStream = FirebaseFirestore.instance
        .collection('user_events')
        .where('user_id', isEqualTo: uid)
        .where('status', isEqualTo: widget.status)
        .orderBy('saved_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => _SavedItem(
      docRef: d.reference,
      id: d.id,
      data: d.data(),
      source: 'user_event',
    ))
        .toList());

    // The web app only merges registrations into the "Registered Events" tab.
    if (widget.status != 'my_events') {
      return userEventsStream;
    }

    final regsStream = FirebaseFirestore.instance
        .collection('event_registrations')
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => _SavedItem(
      docRef: d.reference,
      id: d.id,
      data: d.data(),
      source: 'event_registration',
    ))
        .toList())
        .handleError((_) => <_SavedItem>[]);

    return _combineLatest2<List<_SavedItem>, List<_SavedItem>, List<_SavedItem>>(
      userEventsStream,
      regsStream,
          (a, b) {
        final merged = [...a, ...b];
        merged.sort((x, y) => _sortMillis(y.data).compareTo(_sortMillis(x.data)));
        return merged;
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

    return StreamBuilder<List<_SavedItem>>(
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
          );
        }
        final items = snap.data ?? const <_SavedItem>[];
        if (items.isEmpty) {
          return _EmptyState(
            icon: widget.status == 'my_events'
                ? Icons.bookmark_outline_rounded
                : Icons.star_outline_rounded,
            title: widget.status == 'my_events'
                ? _t(widget.lang, 'noMyEvents')
                : _t(widget.lang, 'noInterested'),
            subtitle: widget.status == 'my_events'
                ? _t(widget.lang, 'noMyEventsSub')
                : _t(widget.lang, 'noInterestedSub'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final it = items[i];
            return _EventCard(
              key: ValueKey('${it.source}_${it.id}'),
              item: it,
              otherStatus:
              widget.status == 'my_events' ? 'interested' : 'my_events',
              lang: widget.lang,
            );
          },
        );
      },
    );
  }
}

// Simple combineLatest for two streams (avoids adding rxdart).
Stream<R> _combineLatest2<A, B, R>(
    Stream<A> a, Stream<B> b, R Function(A, B) combiner) async* {
  A? lastA;
  B? lastB;
  bool hasA = false;
  bool hasB = false;

  final controller = StreamController<R>();
  final subA = a.listen((v) {
    lastA = v;
    hasA = true;
    if (hasB) controller.add(combiner(lastA as A, lastB as B));
  }, onError: controller.addError);
  final subB = b.listen((v) {
    lastB = v;
    hasB = true;
    if (hasA) controller.add(combiner(lastA as A, lastB as B));
  }, onError: controller.addError);

  controller.onCancel = () async {
    await subA.cancel();
    await subB.cancel();
  };

  yield* controller.stream;
}

class _SavedItem {
  final DocumentReference docRef;
  final String id;
  final Map<String, dynamic> data;
  final String source; // 'user_event' | 'event_registration'

  _SavedItem({
    required this.docRef,
    required this.id,
    required this.data,
    required this.source,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Event Card
// ═══════════════════════════════════════════════════════════════════
class _EventCard extends StatelessWidget {
  final _SavedItem item;
  final String otherStatus;
  final String lang;

  const _EventCard({
    super.key,
    required this.item,
    required this.otherStatus,
    required this.lang,
  });

  bool get _isReg => item.source == 'event_registration';
  Map<String, dynamic> get savedData => item.data;

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

  String _formatDate(dynamic raw) {
    DateTime? d;
    if (raw is Timestamp) {
      d = raw.toDate();
    } else if (raw is String && raw.isNotEmpty) {
      try {
        d = DateTime.parse(raw);
      } catch (_) {
        return raw;
      }
    }
    if (d == null) return '';
    if (lang == kLangJa) return _jaDateString(d);
    return DateFormat('MMM d, yyyy').format(d);
  }

  String _formatTime(dynamic raw) {
    if (raw is Timestamp) {
      final d = raw.toDate();
      if (lang == kLangJa) return DateFormat('H:mm').format(d);
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
      await item.docRef.update({'status': otherStatus});
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

  Future<void> _removeOrCancel(
      BuildContext context, Map<String, dynamic>? eventData) async {
    HapticFeedback.mediumImpact();
    final isReg = _isReg;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          isReg ? _t(lang, 'cancelRegTitle') : _t(lang, 'removeTitle'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          isReg ? _t(lang, 'cancelRegDesc') : _t(lang, 'removeDesc'),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Text(_t(lang, 'cancel'),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(isReg ? _t(lang, 'cancelReg') : _t(lang, 'remove'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (isReg) {
        final status = (savedData['status'] ?? '').toString();
        final docId = (eventData?['_doc_id'] ?? '').toString();
        if (status == 'approved' && docId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('events')
                .doc(docId)
                .update({'event_approved_count': FieldValue.increment(-1)});
          } catch (_) {}
        }
        await item.docRef.delete();
      } else {
        await item.docRef.delete();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchEvent(),
      builder: (context, snap) {
        final eventData = snap.data;
        final title = _localTitle(eventData);
        final imageUrl =
        (eventData?['event_pic'] ?? savedData['event_pic'] ?? '')
            .toString();
        final dateStr = eventData != null
            ? _formatDate(eventData['event_date'])
            : _formatDate(savedData['event_date']);
        final timeStr = eventData != null
            ? _formatTime(eventData['event_time'])
            : _formatTime(savedData['event_time']);
        final locCity = eventData != null
            ? (eventData['_loc_city'] ?? '').toString()
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

        final showBadges = otherStatus == 'interested';

        return GestureDetector(
          onTap: eventData != null
              ? () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(event: eventData),
            ),
          )
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
              Border.all(color: AppColors.primary.withOpacity(0.10)),
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
                                        color:
                                        Colors.black.withOpacity(0.5),
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
                            if (showBadges) ...[
                              const SizedBox(height: 8),
                              _BadgesRow(
                                  isReg: _isReg,
                                  savedData: savedData,
                                  lang: lang),
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
                  child: _isReg
                      ? _CancelRegBar(
                      onTap: () =>
                          _removeOrCancel(context, eventData),
                      label: _t(lang, 'cancelReg'))
                      : Row(
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
                                          fontWeight:
                                          FontWeight.w700,
                                          color: switchColor),
                                      overflow:
                                      TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 20,
                          color: AppColors.primary
                              .withOpacity(0.12)),
                      GestureDetector(
                        onTap: () =>
                            _removeOrCancel(context, eventData),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 11, horizontal: 16),
                          child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade400,
                              size: 18),
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
// Cancel Registration Bar (full-width red bar — web parity)
// ═══════════════════════════════════════════════════════════════════
class _CancelRegBar extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _CancelRegBar({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
      const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded,
                color: Colors.red.shade400, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade400)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Badges Row — mirrors the web app status pills.
// ═══════════════════════════════════════════════════════════════════
class _BadgesRow extends StatelessWidget {
  final bool isReg;
  final Map<String, dynamic> savedData;
  final String lang;

  const _BadgesRow({
    required this.isReg,
    required this.savedData,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    if (!isReg) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _Badge(
            label: _t(lang, 'badgeSelfReported'),
            icon: Icons.check_rounded,
            color: AppColors.primary,
            bg: AppColors.primary.withOpacity(0.10),
            borderColor: AppColors.primary.withOpacity(0.30),
          ),
        ],
      );
    }

    final status = (savedData['status'] ?? 'pending').toString();
    late String label;
    late IconData icon;
    late Color color;

    switch (status) {
      case 'approved':
        label = _t(lang, 'badgeApproved');
        icon = Icons.check_rounded;
        color = AppColors.primary;
        break;
      case 'waitlist':
      case 'waitlisted':
      case 'waiting_list':
        label = _t(lang, 'badgeWaitlist');
        icon = Icons.access_time_rounded;
        color = const Color(0xFFF97316);
        break;
      case 'rejected':
        label = _t(lang, 'badgeRejected');
        icon = Icons.close_rounded;
        color = const Color(0xFFEF4444);
        break;
      default:
        label = _t(lang, 'badgePending');
        icon = Icons.access_time_rounded;
        color = const Color(0xFFE6A817);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Badge(
          label: _t(lang, 'badgeRegistered'),
          icon: Icons.check_rounded,
          color: AppColors.primary,
          bg: AppColors.primary.withOpacity(0.10),
          borderColor: AppColors.primary.withOpacity(0.30),
        ),
        _Badge(
          label: label,
          icon: icon,
          color: color,
          bg: color.withOpacity(0.10),
          borderColor: color.withOpacity(0.30),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final Color borderColor;

  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: color)),
        ],
      ),
    );
  }
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
