import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/services/chat_service.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';
import 'package:pikuru/providers/app_language_provider.dart';

// ── i18n ──────────────────────────────────────────────────────────────────────
class _T {
  final String members;
  final String people;
  final String all;
  final String groupCreator;
  final String noMembers;
  final String noCreator;
  final String you;

  const _T({
    required this.members,
    required this.people,
    required this.all,
    required this.groupCreator,
    required this.noMembers,
    required this.noCreator,
    required this.you,
  });

  static const en = _T(
    members:      'Members',
    people:       'people',
    all:          'All',
    groupCreator: 'Group Creator',
    noMembers:    'No members found',
    noCreator:    'No group creator found',
    you:          'You',
  );

  static const ja = _T(
    members:      'メンバー',
    people:       '人',
    all:          'すべて',
    groupCreator: 'グループ作成者',
    noMembers:    'メンバーが見つかりません',
    noCreator:    'グループ作成者が見つかりません',
    you:          'あなた',
  );
}

// ── Avatar helpers ─────────────────────────────────────────────────────────────
String _toImgSrc(String raw) {
  if (raw.isEmpty)             return '';
  if (raw.startsWith('data:')) return raw;
  if (raw.startsWith('http'))  return raw;
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

// ── Reusable avatar widget ────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String avatarSrc;
  final String name;
  final double radius;
  final double fontSize;

  const _Avatar({
    required this.avatarSrc,
    required this.name,
    required this.radius,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final image = _resolveImage(avatarSrc);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.10),
      backgroundImage: image,
      child: image == null
          ? Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
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

// ─────────────────────────────────────────────────────────────────────────────
class ChatMembersScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String groupName;

  const ChatMembersScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  ConsumerState<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends ConsumerState<ChatMembersScreen> {
  String _selectedFilter = 'all';
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Real-time profile cache: userId → {name, avatar} ─────────────────────
  final Map<String, Map<String, String>> _profileCache = {};
  final Map<String, StreamSubscription>  _profileSubs  = {};

  // For event chats: the set of uids allowed to be members (approved registrants
  // + creator). null = no restriction (regular group chat, not yet resolved).
  Set<String>? _allowedIds;

  @override
  void initState() {
    super.initState();
    _resolveAllowedMembers();
  }

  // Resolve event-chat membership: approved registrants + creator. Leaves
  // _allowedIds null for regular group chats (no filtering).
  Future<void> _resolveAllowedMembers() async {
    try {
      final chatSnap = await FirebaseFirestore.instance
          .collection('group_chats').doc(widget.chatId).get();
      final data = chatSnap.data() ?? {};
      final isEvent = (data['type'] ?? '') == 'event' ||
          widget.chatId.startsWith('event_');
      if (!isEvent) return;
      final createdBy = (data['created_by'] ?? '').toString();
      final eventId = (data['event_id'] ??
              (widget.chatId.startsWith('event_')
                  ? widget.chatId.substring('event_'.length)
                  : ''))
          .toString();
      final allowed = <String>{};
      if (createdBy.isNotEmpty) allowed.add(createdBy);
      if (eventId.isNotEmpty) {
        final regSnap = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: eventId)
            .where('status', isEqualTo: 'approved')
            .get();
        for (final r in regSnap.docs) {
          final uid = (r.data()['user_id'] ?? '').toString();
          if (uid.isNotEmpty) allowed.add(uid);
        }
      }
      if (mounted) setState(() => _allowedIds = allowed);
    } catch (e) {
      debugPrint('[ChatMembersScreen] resolve allowed members failed: $e');
    }
  }

  @override
  void dispose() {
    for (final sub in _profileSubs.values) sub.cancel();
    super.dispose();
  }

  // ── Subscribe to registration/{userId} in real-time ───────────────────────
  void _ensureProfileSubscription(String userId) {
    if (_profileSubs.containsKey(userId)) return;

    final sub = FirebaseFirestore.instance
        .collection('registration')
        .doc(userId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final d      = snap.data()!;
      final rawImg = (d['profile_img'] ?? '').toString();
      final nick   = (d['nickname']   ?? '').toString().trim();
      final first  = (d['firstName']  ?? '').toString().trim();
      final last   = (d['lastName']   ?? '').toString().trim();
      final name   = nick.isNotEmpty
          ? nick
          : (first.isNotEmpty && last.isNotEmpty)
          ? '$first $last'
          : first.isNotEmpty
          ? first
          : (_profileCache[userId]?['name'] ?? '');

      setState(() {
        _profileCache[userId] = {
          'name':   name,
          'avatar': _toImgSrc(rawImg),
        };
      });
    }, onError: (e) {
      debugPrint('[ChatMembersScreen] profile sub error for $userId: $e');
    });

    _profileSubs[userId] = sub;
  }

  /// Live name for a member, falling back to the subcollection field
  String _liveName(String userId, String fallback) {
    final cached = (_profileCache[userId]?['name'] ?? '');
    return cached.isNotEmpty ? cached : fallback;
  }

  /// Live avatar for a member, falling back to the subcollection field
  String _liveAvatar(String userId, String fallback) {
    final cached = (_profileCache[userId]?['avatar'] ?? '');
    return cached.isNotEmpty ? cached : _toImgSrc(fallback);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);
    final t    = lang == kLangJa ? _T.ja : _T.en;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<String>(
          stream: ChatService.creatorIdStream(widget.chatId),
          builder: (context, creatorSnap) {
            final creatorId = creatorSnap.data ?? '';
            return Column(
              children: [
                _buildHeader(t),
                _buildFilterTabs(t),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                Expanded(child: _buildMembersList(creatorId, t)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(_T t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 20, color: Color(0xFF1C1C1E)),
            ),
          ),
          const SizedBox(width: 16),
          StreamBuilder<QuerySnapshot>(
            stream: ChatService.membersStream(widget.chatId),
            builder: (context, snapshot) {
              // For event chats, count only approved registrants + creator.
              final allDocs = snapshot.data?.docs ?? [];
              final count = _allowedIds != null
                  ? allDocs.where((d) => _allowedIds!.contains(d.id)).length
                  : allDocs.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.members,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    t == _T.ja
                        ? '$count${t.people}'
                        : '$count ${t.people}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Filter tabs ───────────────────────────────────────────────────────────
  Widget _buildFilterTabs(_T t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _filterTab(label: t.all,          key: 'all',     t: t),
          const SizedBox(width: 10),
          _filterTab(label: t.groupCreator, key: 'creator', t: t),
        ],
      ),
    );
  }

  Widget _filterTab({
    required String label,
    required String key,
    required _T t,
  }) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.primary : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  // ── Members list ──────────────────────────────────────────────────────────
  Widget _buildMembersList(String creatorId, _T t) {
    return StreamBuilder<QuerySnapshot>(
      stream: ChatService.membersStream(widget.chatId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2.5),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Text(
              t.noMembers,
              style: TextStyle(
                  color: Colors.black.withOpacity(0.35), fontSize: 15),
            ),
          );
        }

        var docs = snap.data!.docs;

        // For event chats, restrict to approved registrants + creator (drops
        // stale participant docs from users who are no longer / never were members).
        if (_allowedIds != null) {
          docs = docs.where((d) => _allowedIds!.contains(d.id)).toList();
        }

        // ── Start a real-time registration subscription for every member ───
        for (final doc in docs) {
          _ensureProfileSubscription(doc.id);
        }

        // Filter by Group Creator tab
        if (_selectedFilter == 'creator') {
          docs = docs.where((d) => d.id == creatorId).toList();
          if (docs.isEmpty) {
            return Center(
              child: Text(
                t.noCreator,
                style: TextStyle(
                    color: Colors.black.withOpacity(0.35), fontSize: 15),
              ),
            );
          }
        }

        // Creator always first
        docs.sort((a, b) {
          if (a.id == creatorId) return -1;
          if (b.id == creatorId) return 1;
          return 0;
        });

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            color: Color(0xFFF0F0F0),
            indent: 64,
          ),
          itemBuilder: (context, index) {
            final data          = docs[index].data() as Map<String, dynamic>;
            final userId        = docs[index].id;
            final isCreator     = userId == creatorId;
            final isCurrentUser = userId == currentUserId;

            // Subcollection fields — used only as fallback
            final fallbackName   = (data['display_name'] ?? '').toString();
            final fallbackAvatar = (data['avatar_url']   ?? '').toString();

            // Always prefer live registration data
            final liveName   = _liveName(userId, fallbackName);
            final liveAvatar = _liveAvatar(userId, fallbackAvatar);

            final displayName = isCurrentUser
                ? '$liveName (${t.you})'
                : liveName;

            return _buildMemberTile(
              userId:      userId,
              name:        displayName,
              avatarSrc:   liveAvatar,
              isCreator:   isCreator,
              isCurrentUser: isCurrentUser,
              t:           t,
            );
          },
        );
      },
    );
  }

  // ── Member tile ───────────────────────────────────────────────────────────
  Widget _buildMemberTile({
    required String userId,
    required String name,
    required String avatarSrc,
    required bool   isCreator,
    required bool   isCurrentUser,
    required _T     t,
  }) {
    // Strip the "(You)" suffix before navigating to chat
    final rawName = name
        .replaceAll(' (${_T.en.you})', '')
        .replaceAll('(${_T.ja.you})', '')
        .trim();

    return GestureDetector(
      onTap: isCurrentUser
          ? null
          : () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IndividualChatScreen(
            otherUserId:     userId,
            otherUserName:   rawName,
            otherUserAvatar: avatarSrc,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // ── Avatar + creator badge ──────────────────────────────────
            Stack(
              children: [
                _Avatar(
                  avatarSrc: avatarSrc,
                  name:      name,
                  radius:    24,
                  fontSize:  16,
                ),
                if (isCreator)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.star_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // ── Name + role label ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (isCreator) ...[
                    const SizedBox(height: 2),
                    Text(
                      t.groupCreator,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}