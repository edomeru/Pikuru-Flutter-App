import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/services/chat_service.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';
import 'package:pikuru/providers/app_language_provider.dart';

// ── i18n — mirrors web app T object exactly ───────────────────────────────────
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
  String _selectedFilter = 'all'; // internal key — not displayed directly
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    // ── Watch global language — rebuilds automatically on lang change ──────────
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

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(_T t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 20, color: Color(0xFF1C1C1E)),
            ),
          ),
          const SizedBox(width: 16),
          StreamBuilder<int>(
            stream: ChatService.memberCountStream(widget.chatId),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
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
                    // JP: "3人"  EN: "3 people"
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

  // ── Filter tabs ──────────────────────────────────────────────────────────────
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

  // ── Members list ─────────────────────────────────────────────────────────────
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

        // Sort: creator always appears first
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
            final data     = docs[index].data() as Map<String, dynamic>;
            final userId   = docs[index].id;
            final isCreator      = userId == creatorId;
            final isCurrentUser  = userId == currentUserId;

            // display_name is stored on the members subcollection by joinChat()
            // No _jp variant exists for member names — same as web app.
            final name      = (data['display_name'] ?? 'Unknown').toString();
            final avatarUrl = (data['avatar_url']   ?? '').toString();

            // "(You)" / "(あなた)"
            final displayName = isCurrentUser
                ? '$name (${t.you})'
                : name;

            return _buildMemberTile(
              userId:      userId,
              name:        displayName,
              avatarUrl:   avatarUrl,
              isCreator:   isCreator,
              t:           t,
            );
          },
        );
      },
    );
  }

  // ── Member tile ──────────────────────────────────────────────────────────────
  Widget _buildMemberTile({
    required String userId,
    required String name,
    required String avatarUrl,
    required bool   isCreator,
    required _T     t,
  }) {
    final isCurrentUser = userId == currentUserId;
    // Strip the "(You)" / "(あなた)" suffix before passing to IndividualChatScreen
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
            otherUserId:    userId,
            otherUserName:  rawName,
            otherUserAvatar: avatarUrl,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // ── Avatar + creator badge ──────────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                      : null,
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

            // ── Name + role label ───────────────────────────────────────────
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