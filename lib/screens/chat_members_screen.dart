import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/services/chat_service.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';

class ChatMembersScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const ChatMembersScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  State<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends State<ChatMembersScreen> {
  String _selectedFilter = 'All';
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<String>(
          stream: ChatService.creatorIdStream(widget.chatId),
          builder: (context, creatorSnap) {
            final creatorId = creatorSnap.data ?? '';
            return Column(
              children: [
                _buildHeader(),
                _buildFilterTabs(),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                Expanded(child: _buildMembersList(creatorId)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    '$count people',
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

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _filterTab('All'),
          const SizedBox(width: 10),
          _filterTab('Group Creator'),
        ],
      ),
    );
  }

  Widget _filterTab(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
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

  Widget _buildMembersList(String creatorId) {
    return StreamBuilder<QuerySnapshot>(
      // ✅ Reads directly from members subcollection — no extra user doc fetch needed
      // because joinChat() already stores display_name and avatar_url
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
              'No members yet',
              style: TextStyle(
                  color: Colors.black.withOpacity(0.35), fontSize: 15),
            ),
          );
        }

        var docs = snap.data!.docs;

        // Filter by Group Creator tab
        if (_selectedFilter == 'Group Creator') {
          docs = docs.where((d) => d.id == creatorId).toList();
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No group creator found',
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
            final data = docs[index].data() as Map<String, dynamic>;
            final userId = docs[index].id;
            final isCreator = userId == creatorId;
            final isCurrentUser = userId == currentUserId;

            // Data comes from members subcollection (set in ChatService.joinChat)
            final name = (data['display_name'] ?? 'Unknown').toString();
            final avatarUrl = (data['avatar_url'] ?? '').toString();

            return _buildMemberTile(
              userId: userId,
              name: isCurrentUser ? '$name (You)' : name,
              avatarUrl: avatarUrl,
              isCreator: isCreator,
            );
          },
        );
      },
    );
  }

  Widget _buildMemberTile({
    required String name,
    required String avatarUrl,
    required bool isCreator,
    required String userId,
  }) {
    final isCurrentUser = userId == currentUserId;
    return GestureDetector(
      onTap: isCurrentUser
          ? null
          : () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IndividualChatScreen(
            otherUserId: userId,
            otherUserName: name.replaceAll(' (You)', ''),
            otherUserAvatar: avatarUrl,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
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
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
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
                      'Group Creator',
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