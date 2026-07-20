import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/group_chat_screen.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';
import 'package:pikuru/screens/event_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// i18n
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'chats':                'chats',
    'search':               'Search',
    'all':                  'All',
    'unread':               'Unread',
    'groups':               'Groups',
    'events':               'Events',
    'noEventChannels':      'No event channels yet',
    'noUnread':             'No unread messages',
    'noGroupChats':         'No group chats yet',
    'noChats':              'No chats yet',
    'groupChat':            'Group Chat',
    'unknown':              'Unknown',
    'eventChannel':         'Event Channel',
    'eventChannels':        'Event Channels',
    'tapViewEventChannels': 'Tap to view event channels',
    'pastEvents':           'Past Events',
    'announceOnly':         'ANNOUNCE ONLY',
    'noMessages':           'No messages yet',
    'yesterday':            'Yesterday',
  },
  kLangJa: {
    'chats':                'チャット',
    'search':               '検索',
    'all':                  'すべて',
    'unread':               '未読',
    'groups':               'グループ',
    'events':               'イベント',
    'noEventChannels':      'イベントチャンネルはまだありません',
    'noUnread':             '未読メッセージはありません',
    'noGroupChats':         'グループチャットはまだありません',
    'noChats':              'チャットはまだありません',
    'groupChat':            'グループチャット',
    'unknown':              '不明',
    'eventChannel':         'イベントチャンネル',
    'eventChannels':        'イベントチャンネル',
    'tapViewEventChannels': 'タップしてイベントチャンネルを表示',
    'pastEvents':           '過去のイベント',
    'announceOnly':         'アナウンス専用',
    'noMessages':           'メッセージはまだありません',
    'yesterday':            '昨日',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _ChatItem {
  final String id;
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool hasUnread;
  final int unreadCount;
  final bool isGroup;
  final bool isEvent;
  final bool? repliesAllowed;
  final Map<String, dynamic> raw;

  const _ChatItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.hasUnread,
    required this.unreadCount,
    required this.isGroup,
    this.isEvent = false,
    this.repliesAllowed,
    required this.raw,
  });

  _ChatItem copyWith({String? name, String? avatarUrl}) => _ChatItem(
    id: id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    hasUnread: hasUnread,
    unreadCount: unreadCount,
    isGroup: isGroup,
    isEvent: isEvent,
    repliesAllowed: repliesAllowed,
    raw: raw,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar helpers
// ─────────────────────────────────────────────────────────────────────────────
String _toImgSrc(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  if (raw.startsWith('data:')) return raw;
  if (raw.startsWith('http')) return raw;
  return 'data:image/jpeg;base64,$raw';
}

ImageProvider? _resolveImage(String av) {
  if (av.isEmpty) return null;
  try {
    if (av.startsWith('http')) return NetworkImage(av);
    if (av.startsWith('data:')) {
      final comma = av.indexOf(',');
      if (comma != -1)
        return MemoryImage(base64Decode(av.substring(comma + 1)));
    }
    return MemoryImage(base64Decode(av));
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatsScreen
// ─────────────────────────────────────────────────────────────────────────────
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _searchCtrl = TextEditingController();
  final _me = FirebaseAuth.instance.currentUser;

  // Filter: 'All' | 'Unread' | 'Groups' | 'Events'
  String _filter = 'All';
  String _searchQuery = '';
  bool _pastEventsExpanded = false;

  List<_ChatItem> _groupItems = [];
  List<_ChatItem> _individualItems = [];
  List<_ChatItem> _eventItems = [];
  bool _loading = true;

  StreamSubscription? _groupSub;
  StreamSubscription? _individualSub;
  StreamSubscription? _eventSub;

  // Real-time profile cache
  final Map<String, Map<String, String>> _profileCache = {};
  final Map<String, StreamSubscription> _profileSubs = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()),
    );
    _subscribeGroupChats();
    _subscribeIndividualChats();
    _subscribeEventChannels();
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _individualSub?.cancel();
    _eventSub?.cancel();
    for (final sub in _profileSubs.values) sub.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Pull-to-refresh: cancel all subs, clear state, re-subscribe ───────
  Future<void> _onRefresh() async {
    setState(() {
      _loading = true;
      _groupItems = [];
      _individualItems = [];
      _eventItems = [];
    });

    // Cancel existing subscriptions
    await _groupSub?.cancel();
    await _individualSub?.cancel();
    await _eventSub?.cancel();
    for (final sub in _profileSubs.values) {
      await sub.cancel();
    }
    _profileSubs.clear();
    _profileCache.clear();

    // Re-subscribe all streams
    _subscribeGroupChats();
    _subscribeIndividualChats();
    _subscribeEventChannels();

    // Wait briefly for first snapshot to arrive
    await Future.delayed(const Duration(milliseconds: 900));
  }

  // ── Profile subscription ───────────────────────────────────────────────
  void _ensureProfileSub(String userId) {
    if (_profileSubs.containsKey(userId)) return;
    final sub = FirebaseFirestore.instance
        .collection('registration')
        .doc(userId)
        .snapshots()
        .listen((snap) {
          if (!snap.exists) return;
          final d = snap.data()!;
          final rawImg = (d['profile_img'] ?? '').toString();
          final nick = (d['nickname'] ?? '').toString().trim();
          final first = (d['firstName'] ?? '').toString().trim();
          final last = (d['lastName'] ?? '').toString().trim();
          final name = nick.isNotEmpty
              ? nick
              : (first.isNotEmpty && last.isNotEmpty)
              ? '$first $last'
              : first.isNotEmpty
              ? first
              : '';
          _profileCache[userId] = {'name': name, 'avatar': _toImgSrc(rawImg)};
          if (mounted) setState(() => _applyProfilesToIndividual());
        });
    _profileSubs[userId] = sub;
  }

  void _applyProfilesToIndividual() {
    _individualItems = _individualItems.map((item) {
      final otherId = item.raw['_other_user_id'] as String? ?? '';
      final profile = _profileCache[otherId];
      if (profile == null) return item;
      return item.copyWith(
        name: (profile['name'] ?? '').isNotEmpty ? profile['name']! : item.name,
        avatarUrl: (profile['avatar'] ?? '').isNotEmpty
            ? profile['avatar']!
            : item.avatarUrl,
      );
    }).toList();
  }

  Future<int> _countUnreadMessages({
    required String collectionName,
    required String chatId,
    required DateTime? lastReadAt,
    required int fallbackCount,
  }) async {
    final me = _me;
    if (me == null) return 0;

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection(collectionName)
          .doc(chatId)
          .collection('messages');

      if (lastReadAt != null) {
        query = query.where(
          'sent_at',
          isGreaterThan: Timestamp.fromDate(lastReadAt),
        );
      }

      final snap = await query.get();
      return snap.docs.where((doc) {
        final data = doc.data();
        return (data['sender_id'] ?? '').toString() != me.uid;
      }).length;
    } catch (e) {
      debugPrint('[unreadCount] failed for $collectionName/$chatId: $e');
      return fallbackCount;
    }
  }

  // ── Group chats subscription ──────────────────────────────────────────
  void _subscribeGroupChats() {
    final me = _me;
    if (me == null) return;

    _groupSub = FirebaseFirestore.instance
        .collection('group_chats')
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .listen((snap) async {
          final lang = ref.read(appLangProvider);
          final List<_ChatItem> items = [];
          for (final doc in snap.docs) {
            final data = doc.data();
            // Skip event channels — handled separately
            if ((data['type'] ?? '').toString() == 'event') continue;

            final participantDoc = await FirebaseFirestore.instance
                .collection('group_chats')
                .doc(doc.id)
                .collection('participants')
                .doc(me.uid)
                .get();
            if (!participantDoc.exists) continue;

            final lastMsgAt = (data['last_message_at'] as Timestamp?)?.toDate();
            final lastReadAt =
                (participantDoc.data()?['last_read_at'] as Timestamp?)
                    ?.toDate();
            final hasUnread =
                lastMsgAt != null &&
                (lastReadAt == null || lastMsgAt.isAfter(lastReadAt)) &&
                (data['last_message_by'] ?? '') != me.uid &&
                (data['last_message'] ?? '').toString().isNotEmpty;
            final unreadCount = hasUnread
                ? await _countUnreadMessages(
                    collectionName: 'group_chats',
                    chatId: doc.id,
                    lastReadAt: lastReadAt,
                    fallbackCount: 1,
                  )
                : 0;

            final orgId = (data['org_id'] ?? doc.id).toString();
            String name = _t(lang, 'groupChat');
            String avatarUrl = '';

            if (orgId.isNotEmpty) {
              try {
                final orgDoc = await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(orgId)
                    .get();
                if (orgDoc.exists) {
                  name = (orgDoc.data()!['org_name'] ?? _t(lang, 'groupChat'))
                      .toString();
                  avatarUrl = (orgDoc.data()!['org_image'] ?? '').toString();
                } else {
                  final orgSnap = await FirebaseFirestore.instance
                      .collection('organizations')
                      .where('org_id', isEqualTo: orgId)
                      .limit(1)
                      .get();
                  if (orgSnap.docs.isNotEmpty) {
                    name =
                        (orgSnap.docs.first.data()['org_name'] ??
                                _t(lang, 'groupChat'))
                            .toString();
                    avatarUrl = (orgSnap.docs.first.data()['org_image'] ?? '')
                        .toString();
                  }
                }
              } catch (_) {}
            }

            items.add(
              _ChatItem(
                id: doc.id,
                name: name,
                avatarUrl: avatarUrl,
                lastMessage: (data['last_message'] ?? '').toString(),
                lastMessageAt: lastMsgAt,
                hasUnread: unreadCount > 0,
                unreadCount: unreadCount,
                isGroup: true,
                raw: {
                  ...data,
                  '_doc_id': doc.id,
                  'org_name': name,
                  'org_image': avatarUrl,
                },
              ),
            );
          }
          if (mounted)
            setState(() {
              _groupItems = items;
              _loading = false;
            });
        });
  }

  // ── Individual chats subscription ──────────────────────────────────────
  void _subscribeIndividualChats() {
    final me = _me;
    if (me == null) return;

    _individualSub = FirebaseFirestore.instance
        .collection('individual_chats')
        .where('participants', arrayContains: me.uid)
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .listen((snap) async {
          final lang = ref.read(appLangProvider);
          final List<_ChatItem> items = [];
          for (final doc in snap.docs) {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final otherId = participants.firstWhere(
              (id) => id != me.uid,
              orElse: () => '',
            );
            if (otherId.isEmpty) continue;

            _ensureProfileSub(otherId);

            final names = Map<String, dynamic>.from(
              data['participant_names'] ?? {},
            );
            final avatars = Map<String, dynamic>.from(
              data['participant_avatars'] ?? {},
            );
            final lastMsgAt = (data['last_message_at'] as Timestamp?)?.toDate();
            final lastReadMap = data['last_read'] as Map<String, dynamic>?;
            final myLastRead = lastReadMap != null
                ? (lastReadMap[me.uid] as Timestamp?)?.toDate()
                : null;
            final hasUnread =
                (data['last_message_by'] ?? '') != me.uid &&
                (data['last_message'] ?? '').toString().isNotEmpty &&
                lastMsgAt != null &&
                (myLastRead == null || lastMsgAt.isAfter(myLastRead));
            final unreadCount = hasUnread
                ? await _countUnreadMessages(
                    collectionName: 'individual_chats',
                    chatId: doc.id,
                    lastReadAt: myLastRead,
                    fallbackCount: 1,
                  )
                : 0;

            final cached = _profileCache[otherId];
            final resolvedName = ((cached?['name'] ?? '').isNotEmpty)
                ? cached!['name']!
                : (names[otherId] ?? _t(lang, 'unknown')).toString();
            final resolvedAvatar = ((cached?['avatar'] ?? '').isNotEmpty)
                ? cached!['avatar']!
                : _toImgSrc((avatars[otherId] ?? '').toString());

            items.add(
              _ChatItem(
                id: doc.id,
                name: resolvedName,
                avatarUrl: resolvedAvatar,
                lastMessage: (data['last_message'] ?? '').toString(),
                lastMessageAt: lastMsgAt,
                hasUnread: unreadCount > 0,
                unreadCount: unreadCount,
                isGroup: false,
                raw: {
                  ...data,
                  '_other_user_id': otherId,
                  '_other_user_name': resolvedName,
                  '_other_user_avatar': resolvedAvatar,
                },
              ),
            );
          }
          if (mounted)
            setState(() {
              _individualItems = items;
              _loading = false;
            });
        });
  }

  // ── Event channels subscription ────────────────────────────────────────
  // Mirrors web's dedicated event subscription — resolves event dates so we
  // can split current vs past event channels.
  void _subscribeEventChannels() {
    final me = _me;
    if (me == null) return;

    _eventSub = FirebaseFirestore.instance
        .collection('group_chats')
        .where('type', isEqualTo: 'event')
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .listen((snap) async {
          final lang = ref.read(appLangProvider);
          final List<_ChatItem> items = [];
          final List<String> eventIds = [];

          for (final doc in snap.docs) {
            final data = doc.data();

            // Hide cleared channels (mirrors web messages_cleared check)
            if (data['messages_cleared'] == true) continue;

            final lastMsgAt = (data['last_message_at'] as Timestamp?)?.toDate();
            final participantDoc = await FirebaseFirestore.instance
                .collection('group_chats')
                .doc(doc.id)
                .collection('participants')
                .doc(me.uid)
                .get();
            final lastReadAt =
                (participantDoc.data()?['last_read_at'] as Timestamp?)
                    ?.toDate();
            final hasUnread =
                lastMsgAt != null &&
                (lastReadAt == null || lastMsgAt.isAfter(lastReadAt)) &&
                (data['last_message_by'] ?? '') != me.uid &&
                (data['last_message'] ?? '').toString().isNotEmpty;
            final unreadCount = hasUnread
                ? await _countUnreadMessages(
                    collectionName: 'group_chats',
                    chatId: doc.id,
                    lastReadAt: lastReadAt,
                    fallbackCount: 1,
                  )
                : 0;

            final name = (data['name'] ?? '').toString().isNotEmpty
                ? data['name'].toString()
                : _t(lang, 'eventChannel');
            final imgUrl = (data['image'] ?? '').toString();

            final eventId = (data['event_id'] ?? doc.id).toString();
            if (eventId.isNotEmpty) eventIds.add(eventId);

            items.add(
              _ChatItem(
                id: doc.id,
                name: name,
                avatarUrl: imgUrl,
                lastMessage: (data['last_message'] ?? '').toString(),
                lastMessageAt: lastMsgAt,
                hasUnread: unreadCount > 0,
                unreadCount: unreadCount,
                isGroup: true,
                isEvent: true,
                repliesAllowed: data['replies_allowed'] != false,
                raw: {...data, '_doc_id': doc.id, '_event_id': eventId},
              ),
            );
          }

          // Resolve event dates in chunks of 30 (Firestore whereIn limit)
          final Map<String, Map<String, DateTime?>> datesMap = {};
          try {
            final uniqueIds = eventIds
                .where((id) => id.trim().isNotEmpty)
                .toSet()
                .toList();
            for (var i = 0; i < uniqueIds.length; i += 30) {
              final chunk = uniqueIds.sublist(
                i,
                i + 30 > uniqueIds.length ? uniqueIds.length : i + 30,
              );
              final evsSnap = await FirebaseFirestore.instance
                  .collection('events')
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();
              for (final d in evsSnap.docs) {
                final ed = d.data();
                datesMap[d.id] = {
                  'event_date': (ed['event_date'] as Timestamp?)?.toDate(),
                  'event_date_end': (ed['event_date_end'] as Timestamp?)
                      ?.toDate(),
                };
              }
            }
          } catch (e) {
            debugPrint('[eventDates] resolve failed: $e');
          }

          for (final item in items) {
            final evId = (item.raw['_event_id'] ?? item.id).toString();
            final dates = datesMap[evId];
            if (dates != null) {
              item.raw['event_date'] = dates['event_date'];
              item.raw['event_date_end'] = dates['event_date_end'];
            }
          }

          if (mounted)
            setState(() {
              _eventItems = items;
              _loading = false;
            });
        });
  }

  // ── Merged list (All / Unread / Groups) ───────────────────────────────
  List<_ChatItem> get _mergedItems {
    List<_ChatItem> all = [];
    if (_filter != 'Groups' && _filter != 'Events')
      all.addAll(_individualItems);
    if (_filter != 'Unread' && _filter != 'Events') all.addAll(_groupItems);
    if (_filter == 'Unread') all = [..._individualItems, ..._groupItems];

    if (_searchQuery.isNotEmpty) {
      all = all
          .where((c) => c.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
    if (_filter == 'Unread') all = all.where((c) => c.hasUnread).toList();

    all.sort((a, b) {
      final ta = a.lastMessageAt ?? DateTime(2000);
      final tb = b.lastMessageAt ?? DateTime(2000);
      return tb.compareTo(ta);
    });
    return all;
  }

  List<_ChatItem> get _filteredEventItems {
    if (_searchQuery.isEmpty) return _eventItems;
    return _eventItems
        .where((e) => e.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  // Split event channels into current vs past based on event_date_end / event_date
  // Mirrors web's currentEventItems / pastEventItems logic.
  ({List<_ChatItem> current, List<_ChatItem> past}) get _splitEventItems {
    final List<_ChatItem> current = [];
    final List<_ChatItem> past = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final item in _filteredEventItems) {
      final endRaw = item.raw['event_date_end'];
      final startRaw = item.raw['event_date'];
      DateTime? endDate;
      DateTime? startDate;
      if (endRaw is DateTime)
        endDate = endRaw;
      else if (endRaw is Timestamp)
        endDate = endRaw.toDate();
      if (startRaw is DateTime)
        startDate = startRaw;
      else if (startRaw is Timestamp)
        startDate = startRaw.toDate();

      bool isPast = false;
      if (endDate != null) {
        isPast = endDate.isBefore(now);
      } else if (startDate != null) {
        final startDay = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        isPast = startDay.isBefore(today);
      }
      if (isPast)
        past.add(item);
      else
        current.add(item);
    }
    return (current: current, past: past);
  }

  int get _unreadTotal {
    return [
      ..._individualItems,
      ..._groupItems,
      ..._eventItems,
    ].fold<int>(0, (total, item) => total + item.unreadCount);
  }

  int get _eventUnreadTotal {
    return _filteredEventItems.fold<int>(
      0,
      (total, item) => total + item.unreadCount,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(lang),
            const SizedBox(height: 12),
            _buildSearchBar(lang),
            const SizedBox(height: 12),
            _buildFilterTabs(lang),
            const SizedBox(height: 4),
            Expanded(child: _buildRefreshableBody(lang)),
          ],
        ),
      ),
    );
  }

  // ── Refresh wrapper ───────────────────────────────────────────────────
  Widget _buildRefreshableBody(String lang) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      backgroundColor: Colors.white,
      displacement: 20,
      notificationPredicate: (notification) => notification.depth == 0,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      child: _buildBody(lang),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            _t(lang, 'chats'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.primary.withOpacity(0.9),
                      size: 24,
                    ),
                  ),
                ),
                if (_unreadTotal > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf44336),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_unreadTotal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────
  Widget _buildSearchBar(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
          decoration: InputDecoration(
            hintText: _t(lang, 'search'),
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontSize: 15,
            ),
            suffixIcon: Icon(
              Icons.search,
              color: Colors.black.withOpacity(0.35),
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter Tabs ───────────────────────────────────────────────────────
  Widget _buildFilterTabs(String lang) {
    // Internal filter values stay in English; only the visible label is
    // translated via the _L map ('all' / 'unread' / 'groups' / 'events').
    final tabs = ['All', 'Unread', 'Groups', 'Events'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((label) {
            final selected = _filter == label;
            final isEvent = label == 'Events';
            final activeColor = isEvent
                ? const Color(0xFFFF9933)
                : AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? activeColor : const Color(0xFFF0F4F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEvent) ...[
                        Icon(
                          Icons.campaign_rounded,
                          size: 13,
                          color: selected
                              ? Colors.white
                              : Colors.black.withOpacity(0.45),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _t(lang, label.toLowerCase()),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : Colors.black.withOpacity(0.45),
                        ),
                      ),
                      if (isEvent && _eventUnreadTotal > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withOpacity(0.25)
                                : const Color(0xFFFF9933).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_eventUnreadTotal',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFFF9933),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────
  Widget _buildBody(String lang) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      );
    }

    // Events tab: current event channels list + collapsible past events
    if (_filter == 'Events') {
      final split = _splitEventItems;
      final current = split.current;
      final past = split.past;
      if (current.isEmpty && past.isEmpty) {
        return _buildScrollableEmpty(_t(lang, 'noEventChannels'));
      }
      return ListView(
        children: [
          ...List.generate(
            current.length,
            (i) => Column(
              children: [
                _buildEventTile(current[i], lang),
                if (i < current.length - 1)
                  const Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 20,
                    color: Color(0xFFF0F0F0),
                  ),
              ],
            ),
          ),
          if (past.isNotEmpty) _buildPastEventsSection(past, lang),
        ],
      );
    }

    // All / Unread / Groups tabs
    final items = _mergedItems;
    final evs = _filteredEventItems;
    final eventShortcutItems = _filter == 'Unread'
        ? evs.where((e) => e.hasUnread).toList()
        : evs;

    if (items.isEmpty && eventShortcutItems.isEmpty) {
      return _buildScrollableEmpty(
        _filter == 'Unread'
            ? _t(lang, 'noUnread')
            : _filter == 'Groups'
            ? _t(lang, 'noGroupChats')
            : _t(lang, 'noChats'),
      );
    }

    return ListView(
      children: [
        // ── Event Channels button (only in All/Unread) — routes to Events tab ──
        if ((_filter == 'All' || _filter == 'Unread') &&
            eventShortcutItems.isNotEmpty) ...[
          _buildEventChannelsButton(eventShortcutItems, lang),
          if (items.isNotEmpty)
            Divider(
              height: 1,
              indent: 0,
              endIndent: 0,
              color: Colors.black.withOpacity(0.04),
            ),
        ],

        // ── Regular chats ──────────────────────────────────────────────
        ...List.generate(items.length, (i) {
          return Column(
            children: [
              _buildChatTile(items[i], lang),
              if (i < items.length - 1)
                const Divider(
                  height: 1,
                  indent: 76,
                  endIndent: 20,
                  color: Color(0xFFF0F0F0),
                ),
            ],
          );
        }),
      ],
    );
  }

  // ── Scrollable empty state (needed so RefreshIndicator triggers on empty lists) ──
  Widget _buildScrollableEmpty(String message) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 52,
                  color: Colors.black.withOpacity(0.12),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.35),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Event Channels Button (All/Unread tab) ────────────────────────────
  // Single tappable button that routes to the Events tab. Replaces the
  // previous preview-list section.
  Widget _buildEventChannelsButton(List<_ChatItem> evs, String lang) {
    final unreadCount = evs.fold<int>(
      0,
      (total, item) => total + item.unreadCount,
    );
    final hasUnread = unreadCount > 0;
    const orange = Color(0xFFFF9933);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _filter = 'Events'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: orange.withOpacity(0.06),
            border: Border.all(color: orange.withOpacity(0.35), width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(lang, 'eventChannels'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _t(lang, 'tapViewEventChannels'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF8A8A8E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUnread) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFf44336),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (hasUnread) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: orange.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: orange,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right, color: orange, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Past Events collapsible section (Events tab) ──────────────────────
  Widget _buildPastEventsSection(List<_ChatItem> past, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Divider(height: 1, color: Colors.black.withOpacity(0.05)),
        InkWell(
          onTap: () =>
              setState(() => _pastEventsExpanded = !_pastEventsExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: Colors.black.withOpacity(0.45),
                ),
                const SizedBox(width: 8),
                Text(
                  _t(lang, 'pastEvents'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black.withOpacity(0.55),
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${past.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.45),
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _pastEventsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_pastEventsExpanded)
          ...List.generate(
            past.length,
            (i) => Column(
              children: [
                _buildEventTile(past[i], lang),
                if (i < past.length - 1)
                  const Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 20,
                    color: Color(0xFFF0F0F0),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Event Channel Tile ────────────────────────────────────────────────
  Widget _buildEventTile(_ChatItem item, String lang) {
    final avatarImage = _resolveImage(item.avatarUrl);
    return InkWell(
      onTap: () => _openChat(item),
      splashColor: const Color(0xFFFF9933).withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: const Color(0xFFFF9933).withOpacity(0.12),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Text(
                          item.name.isNotEmpty
                              ? item.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF9933),
                          ),
                        )
                      : null,
                ),
                // Event badge overlay
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9933),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: item.hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: const Color(0xFF1C1C1E),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(item.lastMessageAt, lang),
                        style: TextStyle(
                          fontSize: 12,
                          color: item.hasUnread
                              ? const Color(0xFFFF9933)
                              : Colors.black.withOpacity(0.35),
                          fontWeight: item.hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Announce-only badge
                      if (item.repliesAllowed == false) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9933).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _t(lang, 'announceOnly'),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF9933),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          item.lastMessage.isEmpty
                              ? _t(lang, 'noMessages')
                              : item.lastMessage,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: item.hasUnread
                                ? const Color(0xFF1C1C1E)
                                : Colors.black.withOpacity(0.38),
                            fontWeight: item.hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9933).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.unreadCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF9933),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Regular Chat Tile ─────────────────────────────────────────────────
  Widget _buildChatTile(_ChatItem item, String lang) {
    final avatarImage = _resolveImage(item.avatarUrl);
    return InkWell(
      onTap: () => _openChat(item),
      splashColor: AppColors.primary.withOpacity(0.05),
      highlightColor: AppColors.primary.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Text(
                          item.name.isNotEmpty
                              ? item.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                if (item.isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.group,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: item.hasUnread
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.lastMessage.isEmpty
                        ? _t(lang, 'noMessages')
                        : item.lastMessage,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: item.hasUnread
                          ? const Color(0xFF1C1C1E)
                          : Colors.black.withOpacity(0.38),
                      fontWeight: item.hasUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatTime(item.lastMessageAt, lang),
                  style: TextStyle(
                    fontSize: 12,
                    color: item.hasUnread
                        ? AppColors.primary
                        : Colors.black.withOpacity(0.35),
                    fontWeight: item.hasUnread
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                if (item.hasUnread) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────
  void _openChat(_ChatItem item) {
    if (item.isEvent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventChatScreen(chatId: item.id, eventData: item.raw),
        ),
      );
    } else if (item.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: item.raw)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IndividualChatScreen(
            otherUserId: item.raw['_other_user_id'] ?? '',
            otherUserName: item.raw['_other_user_name'] ?? '',
            otherUserAvatar: item.raw['_other_user_avatar'] ?? '',
          ),
        ),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  Widget _buildEmpty(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: 52,
          color: Colors.black.withOpacity(0.12),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          style: TextStyle(
            color: Colors.black.withOpacity(0.35),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  String _formatTime(DateTime? dt, String lang) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff == 0) {
      final h = dt.hour > 12
          ? dt.hour - 12
          : dt.hour == 0
          ? 12
          : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      if (lang == kLangJa) {
        return '${dt.hour >= 12 ? '午後' : '午前'}$h:$m';
      }
      return '$h:$m ${dt.hour >= 12 ? 'pm' : 'am'}';
    } else if (diff == 1) {
      return _t(lang, 'yesterday');
    } else if (diff < 7) {
      if (lang == kLangJa) {
        const days = ['月', '火', '水', '木', '金', '土', '日'];
        return '${days[dt.weekday - 1]}曜日';
      }
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      if (lang == kLangJa) {
        return '${dt.month}月${dt.day}日';
      }
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    }
  }
}
