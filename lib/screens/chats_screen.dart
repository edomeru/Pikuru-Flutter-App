import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/group_chat_screen.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';

class _ChatItem {
  final String id;
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool hasUnread;
  final bool isGroup;
  final Map<String, dynamic> raw;

  const _ChatItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.hasUnread,
    required this.isGroup,
    required this.raw,
  });
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _searchController = TextEditingController();
  final _me = FirebaseAuth.instance.currentUser;
  String _filter = 'All';
  String _searchQuery = '';

  List<_ChatItem> _groupItems = [];
  List<_ChatItem> _individualItems = [];
  bool _loading = true;

  StreamSubscription? _groupSub;
  StreamSubscription? _individualSub;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
            () => setState(() => _searchQuery = _searchController.text.toLowerCase()));
    _subscribeGroupChats();
    _subscribeIndividualChats();
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _individualSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

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
        // Check if user is a participant
        final participantDoc = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(doc.id)
            .collection('participants')
            .doc(me.uid)
            .get();
        if (!participantDoc.exists) continue;

        final data = doc.data();
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
            // ── STEP 1: Try document ID directly (matches web app's first attempt) ──
            final orgDoc = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(orgId)
                .get();

            if (orgDoc.exists) {
              final org = orgDoc.data()!;
              name = (org['org_name'] ?? 'Group Chat').toString();
              avatarUrl = (org['org_image'] ?? '').toString();
            } else {
              // ── STEP 2: Fallback — query by org_id field ──
              final orgSnap = await FirebaseFirestore.instance
                  .collection('organizations')
                  .where('org_id', isEqualTo: orgId)
                  .limit(1)
                  .get();

              if (orgSnap.docs.isNotEmpty) {
                final org = orgSnap.docs.first.data();
                name = (org['org_name'] ?? 'Group Chat').toString();
                avatarUrl = (org['org_image'] ?? '').toString();
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
          raw: {
            ...data,
            '_doc_id': doc.id,
            'org_name': name,
            'org_image': avatarUrl,
          },
        ));
      }

      if (mounted) {
        setState(() {
          _groupItems = items;
          _loading = false;
        });
      }
    });
  }

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

        final names = Map<String, dynamic>.from(data['participant_names'] ?? {});
        final avatars =
        Map<String, dynamic>.from(data['participant_avatars'] ?? {});
        final lastMsgAt = (data['last_message_at'] as Timestamp?)?.toDate();

        final lastReadMap = data['last_read'] as Map<String, dynamic>?;
        final myLastRead = lastReadMap != null
            ? (lastReadMap[me.uid] as Timestamp?)?.toDate()
            : null;
        final hasUnread = (data['last_message_by'] ?? '') != me.uid &&
            (data['last_message'] ?? '').toString().isNotEmpty &&
            lastMsgAt != null &&
            (myLastRead == null || lastMsgAt.isAfter(myLastRead));

        items.add(_ChatItem(
          id: doc.id,
          name: (names[otherId] ?? 'Unknown').toString(),
          avatarUrl: (avatars[otherId] ?? '').toString(),
          lastMessage: (data['last_message'] ?? '').toString(),
          lastMessageAt: lastMsgAt,
          hasUnread: hasUnread,
          isGroup: false,
          raw: {
            ...data,
            '_other_user_id': otherId,
            '_other_user_name': (names[otherId] ?? 'Unknown').toString(),
            '_other_user_avatar': (avatars[otherId] ?? '').toString(),
          },
        ));
      }

      if (mounted) {
        setState(() {
          _individualItems = items;
          _loading = false;
        });
      }
    });
  }

  List<_ChatItem> get _mergedItems {
    List<_ChatItem> all = [];

    if (_filter != 'Groups') all.addAll(_individualItems);
    if (_filter != 'Unread') all.addAll(_groupItems);
    if (_filter == 'Unread') all = [..._individualItems, ..._groupItems];

    if (_searchQuery.isNotEmpty) {
      all = all
          .where((c) => c.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    if (_filter == 'Unread') {
      all = all.where((c) => c.hasUnread).toList();
    }

    all.sort((a, b) {
      final ta = a.lastMessageAt ?? DateTime(2000);
      final tb = b.lastMessageAt ?? DateTime(2000);
      return tb.compareTo(ta);
    });

    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 14),
            _buildFilterTabs(),
            const SizedBox(height: 6),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child:
            const Icon(Icons.arrow_back, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          const Text('chats',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _searchController,
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

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: ['All', 'Unread', 'Groups'].map((label) {
          final selected = _filter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _filter = label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                decoration: BoxDecoration(
                  color:
                  selected ? AppColors.primary : const Color(0xFFF0F4F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : Colors.black.withOpacity(0.45))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5));
    }

    final items = _mergedItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 52, color: Colors.black.withOpacity(0.12)),
            const SizedBox(height: 14),
            Text(
              _filter == 'Unread'
                  ? 'No unread messages'
                  : _filter == 'Groups'
                  ? 'No group chats yet'
                  : 'No chats yet',
              style: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          children: [
            _buildChatTile(item),
            if (index < items.length - 1)
              const Divider(
                  height: 1,
                  indent: 76,
                  endIndent: 20,
                  color: Color(0xFFF0F0F0)),
          ],
        );
      },
    );
  }

  Widget _buildChatTile(_ChatItem item) {
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
                  backgroundImage: item.avatarUrl.isNotEmpty
                      ? NetworkImage(item.avatarUrl)
                      : null,
                  child: item.avatarUrl.isEmpty
                      ? Text(
                    item.name.isNotEmpty
                        ? item.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
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
                          border: Border.all(color: Colors.white, width: 2)),
                      child:
                      const Icon(Icons.group, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: item.hasUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: const Color(0xFF1C1C1E),
                          letterSpacing: -0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
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
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(_ChatItem item) {
    if (item.isGroup) {
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
              )));
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) {
      final h = dt.hour > 12
          ? dt.hour - 12
          : dt.hour == 0
          ? 12
          : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final p = dt.hour >= 12 ? 'pm' : 'am';
      return '$h:$m $p';
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