import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/group_chat_screen.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';
import 'package:pikuru/screens/event_chat_screen.dart';

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
      if (comma != -1) return MemoryImage(base64Decode(av.substring(comma + 1)));
    }
    return MemoryImage(base64Decode(av));
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatsScreen
// ─────────────────────────────────────────────────────────────────────────────
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _searchCtrl = TextEditingController();
  final _me = FirebaseAuth.instance.currentUser;

  // Filter: 'All' | 'Unread' | 'Groups' | 'Events'
  String _filter = 'All';
  String _searchQuery = '';

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
    _searchCtrl
        .addListener(() => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
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

  // ── Group chats subscription ──────────────────────────────────────────
  void _subscribeGroupChats() {
    final me = _me;
    if (me == null) return;

    _groupSub = FirebaseFirestore.instance
        .collection('group_chats')
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .listen((snap) async {
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
        (participantDoc.data()?['last_read_at'] as Timestamp?)?.toDate();
        final hasUnread = lastMsgAt != null &&
            (lastReadAt == null || lastMsgAt.isAfter(lastReadAt)) &&
            (data['last_message_by'] ?? '') != me.uid &&
            (data['last_message'] ?? '').toString().isNotEmpty;

        final orgId = (data['org_id'] ?? doc.id).toString();
        String name = 'Group Chat';
        String avatarUrl = '';

        if (orgId.isNotEmpty) {
          try {
            final orgDoc = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(orgId)
                .get();
            if (orgDoc.exists) {
              name = (orgDoc.data()!['org_name'] ?? 'Group Chat').toString();
              avatarUrl = (orgDoc.data()!['org_image'] ?? '').toString();
            } else {
              final orgSnap = await FirebaseFirestore.instance
                  .collection('organizations')
                  .where('org_id', isEqualTo: orgId)
                  .limit(1)
                  .get();
              if (orgSnap.docs.isNotEmpty) {
                name = (orgSnap.docs.first.data()['org_name'] ?? 'Group Chat').toString();
                avatarUrl = (orgSnap.docs.first.data()['org_image'] ?? '').toString();
              }
            }
          } catch (_) {}
        }

        items.add(_ChatItem(
          id: doc.id,
          name: name,
          avatarUrl: avatarUrl,
          lastMessage: (data['last_message'] ?? '').toString(),
          lastMessageAt: lastMsgAt,
          hasUnread: hasUnread,
          isGroup: true,
          raw: {...data, '_doc_id': doc.id, 'org_name': name, 'org_image': avatarUrl},
        ));
      }
      if (mounted) setState(() { _groupItems = items; _loading = false; });
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
        .listen((snap) {
      final List<_ChatItem> items = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherId =
        participants.firstWhere((id) => id != me.uid, orElse: () => '');
        if (otherId.isEmpty) continue;

        _ensureProfileSub(otherId);

        final names = Map<String, dynamic>.from(data['participant_names'] ?? {});
        final avatars = Map<String, dynamic>.from(data['participant_avatars'] ?? {});
        final lastMsgAt = (data['last_message_at'] as Timestamp?)?.toDate();
        final lastReadMap = data['last_read'] as Map<String, dynamic>?;
        final myLastRead =
        lastReadMap != null ? (lastReadMap[me.uid] as Timestamp?)?.toDate() : null;
        final hasUnread = (data['last_message_by'] ?? '') != me.uid &&
            (data['last_message'] ?? '').toString().isNotEmpty &&
            lastMsgAt != null &&
            (myLastRead == null || lastMsgAt.isAfter(myLastRead));

        final cached = _profileCache[otherId];
        final resolvedName = ((cached?['name'] ?? '').isNotEmpty)
            ? cached!['name']!
            : (names[otherId] ?? 'Unknown').toString();
        final resolvedAvatar = ((cached?['avatar'] ?? '').isNotEmpty)
            ? cached!['avatar']!
            : _toImgSrc((avatars[otherId] ?? '').toString());

        items.add(_ChatItem(
          id: doc.id,
          name: resolvedName,
          avatarUrl: resolvedAvatar,
          lastMessage: (data['last_message'] ?? '').toString(),
          lastMessageAt: lastMsgAt,
          hasUnread: hasUnread,
          isGroup: false,
          raw: {
            ...data,
            '_other_user_id': otherId,
            '_other_user_name': resolvedName,
            '_other_user_avatar': resolvedAvatar,
          },
        ));
      }
      if (mounted) setState(() { _individualItems = items; _loading = false; });
    });
  }

  // ── Event channels subscription ────────────────────────────────────────
  // Mirrors web's dedicated event subscription — no per-doc reads needed.
  void _subscribeEventChannels() {
    final me = _me;
    if (me == null) return;

    _eventSub = FirebaseFirestore.instance
        .collection('group_chats')
        .where('type', isEqualTo: 'event')
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .listen((snap) {
      final List<_ChatItem> items = [];
      for (final doc in snap.docs) {
        final data = doc.data();

        // Hide cleared channels (mirrors web messages_cleared check)
        if (data['messages_cleared'] == true) continue;

        final lastMsgAt = (data['last_message_at'] as Timestamp?)?.toDate();
        // Zero-cost unread heuristic — same as web
        final hasUnread = lastMsgAt != null &&
            (data['last_message_by'] ?? '') != me.uid &&
            (data['last_message'] ?? '').toString().isNotEmpty;

        final name = (data['name'] ?? '').toString().isNotEmpty
            ? data['name'].toString()
            : 'Event Channel';
        final imgUrl = (data['image'] ?? '').toString();

        items.add(_ChatItem(
          id: doc.id,
          name: name,
          avatarUrl: imgUrl,
          lastMessage: (data['last_message'] ?? '').toString(),
          lastMessageAt: lastMsgAt,
          hasUnread: hasUnread,
          isGroup: true,
          isEvent: true,
          repliesAllowed: data['replies_allowed'] != false,
          raw: {...data, '_doc_id': doc.id},
        ));
      }
      if (mounted) setState(() { _eventItems = items; _loading = false; });
    });
  }

  // ── Merged list (All / Unread / Groups) ───────────────────────────────
  List<_ChatItem> get _mergedItems {
    List<_ChatItem> all = [];
    if (_filter != 'Groups' && _filter != 'Events') all.addAll(_individualItems);
    if (_filter != 'Unread' && _filter != 'Events') all.addAll(_groupItems);
    if (_filter == 'Unread') all = [..._individualItems, ..._groupItems];

    if (_searchQuery.isNotEmpty) {
      all = all.where((c) => c.name.toLowerCase().contains(_searchQuery)).toList();
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

  int get _unreadTotal {
    return [..._individualItems, ..._groupItems, ..._eventItems]
        .where((c) => c.hasUnread)
        .length;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildFilterTabs(),
          const SizedBox(height: 4),
          Expanded(child: _buildRefreshableBody()),
        ]),
      ),
    );
  }

  // ── Refresh wrapper ───────────────────────────────────────────────────
  Widget _buildRefreshableBody() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      backgroundColor: Colors.white,
      displacement: 20,
      notificationPredicate: (notification) => notification.depth == 0,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      child: _buildBody(),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 14),
        const Text('chats',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: -0.5)),
        const Spacer(),
        // Unread badge
        if (_unreadTotal > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFf44336).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20)),
            child: Text('$_unreadTotal',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
      ]),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
            color: const Color(0xFFF0F4F0),
            borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle:
            TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 15),
            suffixIcon: Icon(Icons.search,
                color: Colors.black.withOpacity(0.35), size: 20),
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
        ),
      ),
    );
  }

  // ── Filter Tabs ───────────────────────────────────────────────────────
  Widget _buildFilterTabs() {
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? activeColor : const Color(0xFFF0F4F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEvent) ...[
                        Icon(Icons.campaign_rounded,
                            size: 13,
                            color: selected
                                ? Colors.white
                                : Colors.black.withOpacity(0.45)),
                        const SizedBox(width: 4),
                      ],
                      Text(label,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : Colors.black.withOpacity(0.45))),
                      if (isEvent && _filteredEventItems.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withOpacity(0.25)
                                : const Color(0xFFFF9933).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${_filteredEventItems.length}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFFFF9933))),
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
  Widget _buildBody() {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5));
    }

    // Events tab: full list of event channels
    if (_filter == 'Events') {
      final evs = _filteredEventItems;
      if (evs.isEmpty) {
        return _buildScrollableEmpty('No event channels yet');
      }
      return ListView.builder(
        itemCount: evs.length,
        itemBuilder: (_, i) => Column(children: [
          _buildEventTile(evs[i]),
          if (i < evs.length - 1)
            const Divider(
                height: 1, indent: 76, endIndent: 20, color: Color(0xFFF0F0F0)),
        ]),
      );
    }

    // All / Unread / Groups tabs
    final items = _mergedItems;
    final evs = _filteredEventItems;

    if (items.isEmpty && (_filter == 'Events' || evs.isEmpty)) {
      return _buildScrollableEmpty(_filter == 'Unread'
          ? 'No unread messages'
          : _filter == 'Groups'
          ? 'No group chats yet'
          : 'No chats yet');
    }

    return ListView(children: [
      // ── Event Channels section (max 2 preview, only in All/Unread) ──
      if ((_filter == 'All' || _filter == 'Unread') && evs.isNotEmpty) ...[
        _buildEventSection(evs),
        if (items.isNotEmpty)
          Divider(
              height: 1,
              indent: 0,
              endIndent: 0,
              color: Colors.black.withOpacity(0.04)),
      ],

      // ── Regular chats ──────────────────────────────────────────────
      ...List.generate(items.length, (i) {
        return Column(children: [
          _buildChatTile(items[i]),
          if (i < items.length - 1)
            const Divider(
                height: 1,
                indent: 76,
                endIndent: 20,
                color: Color(0xFFF0F0F0)),
        ]);
      }),
    ]);
  }

  // ── Scrollable empty state (needed so RefreshIndicator triggers on empty lists) ──
  Widget _buildScrollableEmpty(String message) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_bubble_outline,
                  size: 52, color: Colors.black.withOpacity(0.12)),
              const SizedBox(height: 14),
              Text(message,
                  style: TextStyle(
                      color: Colors.black.withOpacity(0.35),
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Event Channels Section Header ─────────────────────────────────────
  Widget _buildEventSection(List<_ChatItem> evs) {
    final hasUnread = evs.any((e) => e.hasUnread);
    final preview = evs.take(2).toList();
    final extras = evs.length - 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                  color: const Color(0xFFFF9933).withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.campaign_rounded,
                  size: 13, color: Color(0xFFFF9933)),
            ),
            const SizedBox(width: 8),
            const Text('EVENT CHANNELS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF9933),
                    letterSpacing: 0.8)),
            if (hasUnread) ...[
              const SizedBox(width: 6),
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: Color(0xFFf44336), shape: BoxShape.circle),
              ),
            ],
            const Spacer(),
            if (extras > 0)
              GestureDetector(
                onTap: () => setState(() => _filter = 'Events'),
                child: Text('+$extras more',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF9933))),
              ),
          ]),
        ),
        // Preview tiles (up to 2)
        ...preview.map(_buildEventTile),
        // See all button if more than 2
        if (extras > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
            child: GestureDetector(
              onTap: () => setState(() => _filter = 'Events'),
              child: Container(
                padding:
                const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFFF9933).withOpacity(0.3),
                      width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.campaign_rounded,
                        size: 13, color: Color(0xFFFF9933)),
                    const SizedBox(width: 6),
                    Text('See all ${evs.length} event channels',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF9933))),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Event Channel Tile ────────────────────────────────────────────────
  Widget _buildEventTile(_ChatItem item) {
    final avatarImage = _resolveImage(item.avatarUrl);
    return InkWell(
      onTap: () => _openChat(item),
      splashColor: const Color(0xFFFF9933).withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(children: [
          // Avatar
          Stack(children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: const Color(0xFFFF9933).withOpacity(0.12),
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Text(
                  item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9933)))
                  : null,
            ),
            // Event badge overlay
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9933),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.campaign_rounded,
                    size: 9, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(item.name,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: item.hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: const Color(0xFF1C1C1E),
                            letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(_formatTime(item.lastMessageAt),
                      style: TextStyle(
                          fontSize: 12,
                          color: item.hasUnread
                              ? const Color(0xFFFF9933)
                              : Colors.black.withOpacity(0.35),
                          fontWeight: item.hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  // Announce-only badge
                  if (item.repliesAllowed == false) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9933).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ANNOUNCE ONLY',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF9933),
                              letterSpacing: 0.4)),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      item.lastMessage.isEmpty
                          ? 'No messages yet'
                          : item.lastMessage,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: item.hasUnread
                              ? const Color(0xFF1C1C1E)
                              : Colors.black.withOpacity(0.38),
                          fontWeight: item.hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.hasUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 9, height: 9,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFF9933), shape: BoxShape.circle),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Regular Chat Tile ─────────────────────────────────────────────────
  Widget _buildChatTile(_ChatItem item) {
    final avatarImage = _resolveImage(item.avatarUrl);
    return InkWell(
      onTap: () => _openChat(item),
      splashColor: AppColors.primary.withOpacity(0.05),
      highlightColor: AppColors.primary.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Text(
                  item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary))
                  : null,
            ),
            if (item.isGroup)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.group, size: 10, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                        item.hasUnread ? FontWeight.w700 : FontWeight.w600,
                        color: const Color(0xFF1C1C1E),
                        letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  item.lastMessage.isEmpty ? 'No messages yet' : item.lastMessage,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: item.hasUnread
                          ? const Color(0xFF1C1C1E)
                          : Colors.black.withOpacity(0.38),
                      fontWeight: item.hasUnread
                          ? FontWeight.w600
                          : FontWeight.normal),
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
              Text(_formatTime(item.lastMessageAt),
                  style: TextStyle(
                      fontSize: 12,
                      color: item.hasUnread
                          ? AppColors.primary
                          : Colors.black.withOpacity(0.35),
                      fontWeight: item.hasUnread
                          ? FontWeight.w600
                          : FontWeight.normal)),
              if (item.hasUnread) ...[
                const SizedBox(height: 6),
                Container(
                    width: 9, height: 9,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
              ],
            ],
          ),
        ]),
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────
  void _openChat(_ChatItem item) {
    if (item.isEvent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventChatScreen(
            chatId: item.id,
            eventData: item.raw,
          ),
        ),
      );
    } else if (item.isGroup) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => GroupChatScreen(group: item.raw)));
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
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.chat_bubble_outline,
          size: 52, color: Colors.black.withOpacity(0.12)),
      const SizedBox(height: 14),
      Text(message,
          style: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontSize: 15,
              fontWeight: FontWeight.w500)),
    ]),
  );

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) {
      final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? 'pm' : 'am'}';
    } else if (diff == 1) {
      return 'Yesterday';
    } else if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    }
  }
}