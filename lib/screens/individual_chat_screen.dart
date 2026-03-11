import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/services/individual_chat_service.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:pikuru/screens/event_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UTILITY — upgrades Google profile photo URLs to full resolution
// Google returns tiny 96px images by default. Replace =s96-c with =s400-c.
// For Firebase Storage URLs this is a no-op (returned unchanged).
// ─────────────────────────────────────────────────────────────────────────────
String _hiRes(String url, {int size = 400}) {
  if (url.isEmpty) return url;
  final hiRes = url
      .replaceAllMapped(RegExp(r'=s\d+-c'), (_) => '=s${size}-c')
      .replaceAllMapped(RegExp(r'=s\d+(?!-c)(?=[&?]|$)'), (_) => '=s$size');
  return hiRes;
}

// ════════════════════════════════════════════════════════════════════════════
// Individual Chat Screen
// ════════════════════════════════════════════════════════════════════════════

class IndividualChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;

  const IndividualChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final currentUser = FirebaseAuth.instance.currentUser;

  String? _chatId;
  bool _isLoading = true;
  bool _isTyping = false;

  late final AnimationController _sendBtnController;

  @override
  void initState() {
    super.initState();
    _sendBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _messageController.addListener(() {
      final typing = _messageController.text.trim().isNotEmpty;
      if (typing != _isTyping) {
        setState(() => _isTyping = typing);
        if (typing) {
          _sendBtnController.forward();
        } else {
          _sendBtnController.reverse();
        }
      }
    });
    _focusNode.addListener(() => setState(() {}));
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendBtnController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final chatId = await IndividualChatService.getOrCreateChat(
      otherUserId: widget.otherUserId,
      otherUserName: widget.otherUserName,
      otherUserAvatar: widget.otherUserAvatar,
    );
    if (mounted) {
      setState(() {
        _chatId = chatId;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_chatId == null || _messageController.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    final text = _messageController.text;
    _messageController.clear();
    _focusNode.requestFocus();
    await IndividualChatService.sendMessage(_chatId!, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _openProfile() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      _UserProfileScreen.route(
        userId: widget.otherUserId,
        userName: widget.otherUserName,
        avatarUrl: widget.otherUserAvatar,
        onChat: () {}, // unused — chat button just pops the profile
        onGroupTap: (group) {
          // Map user_groups field names to what GroupDetailScreen expects
          final mapped = {
            ...group,
            'org_name':        group['group_name']  ?? group['org_name']  ?? '',
            'org_image':       group['group_image'] ?? group['org_image'] ?? '',
            'org_id':          group['group_id']    ?? group['org_id']    ?? '',
            'org_description': group['org_description'] ?? '',
          };
          // Pop the profile screen first, then push GroupDetailScreen
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GroupDetailScreen(group: mapped),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF7F7F9),
      body: Column(
        children: [
          SafeArea(bottom: false, child: _buildAppBar()),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _isLoading
                  ? Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
                  : _buildMessageList(),
            ),
          ),
          SafeArea(top: false, child: _buildInputBar()),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final hiResAvatar = _hiRes(widget.otherUserAvatar);
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(50),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Color(0xFF1C1C1E)),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: GestureDetector(
                    onTap: _openProfile,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        _Avatar(
                          url: hiResAvatar,
                          name: widget.otherUserName,
                          radius: 21,
                          fontSize: 15,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.otherUserName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D0D0D),
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Tap to view profile',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.black.withOpacity(0.35),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(50),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.more_vert_rounded,
                          size: 22, color: Colors.black.withOpacity(0.4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Subtle green accent line under app bar
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.0),
                  AppColors.primary.withOpacity(0.2),
                  AppColors.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message List ─────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: IndividualChatService.messagesStream(_chatId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2));
        }
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) return _buildEmptyState();
        _scrollToBottom();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index].data() as Map<String, dynamic>;
            final isMe = msg['sender_id'] == currentUser?.uid;
            final prevSenderId = index > 0
                ? (messages[index - 1].data()
            as Map<String, dynamic>)['sender_id']
                : null;
            final nextSenderId = index < messages.length - 1
                ? (messages[index + 1].data()
            as Map<String, dynamic>)['sender_id']
                : null;
            final isFirstInGroup = prevSenderId != msg['sender_id'];
            final isLastInGroup = nextSenderId != msg['sender_id'];
            final showDate = index == 0 ||
                _isDifferentDay(
                  (messages[index - 1].data()
                  as Map<String, dynamic>)['sent_at'],
                  msg['sent_at'],
                );
            return Column(
              children: [
                if (showDate) _buildDateDivider(msg['sent_at']),
                _buildMessageBubble(msg, isMe, isFirstInGroup, isLastInGroup),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateDivider(dynamic timestamp) {
    String label = 'Today';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (diff == 0) label = 'Today';
      else if (diff == 1) label = 'Yesterday';
      else label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: Colors.black.withOpacity(0.07), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withOpacity(0.32),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
              child: Divider(
                  color: Colors.black.withOpacity(0.07), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isFirstInGroup,
      bool isLastInGroup,
      ) {
    final Timestamp? sentAt = msg['sent_at'];
    final time = sentAt != null ? _formatTime(sentAt.toDate()) : '';
    final hiResAvatar = _hiRes(widget.otherUserAvatar);

    // ── Group share card ──────────────────────────────────────────────────
    if ((msg['type'] ?? '') == 'group_share') {
      return _buildGroupShareBubble(msg, isMe, isLastInGroup, time, hiResAvatar);
    }

    // ── Event share card ──────────────────────────────────────────────────
    if ((msg['type'] ?? '') == 'event_share') {
      return _buildEventShareBubble(msg, isMe, isLastInGroup, time, hiResAvatar);
    }

    // ── Normal text bubble ────────────────────────────────────────────────
    final text = msg['text'] ?? '';

    final bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(!isMe && !isFirstInGroup ? 5 : 22),
      topRight: Radius.circular(isMe && !isFirstInGroup ? 5 : 22),
      bottomLeft: Radius.circular(!isMe && !isLastInGroup ? 5 : 22),
      bottomRight: Radius.circular(isMe && !isLastInGroup ? 5 : 22),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLastInGroup ? 12 : 2),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 32,
              child: isLastInGroup
                  ? GestureDetector(
                onTap: _openProfile,
                child: _Avatar(
                  url: hiResAvatar,
                  name: widget.otherUserName,
                  radius: 16,
                  fontSize: 12,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.70),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: bubbleRadius,
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? AppColors.primary.withOpacity(0.25)
                            : Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15.5,
                      color:
                      isMe ? Colors.white : const Color(0xFF1A1A1A),
                      height: 1.4,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (isLastInGroup)
                  Padding(
                    padding: EdgeInsets.only(
                        top: 4,
                        left: isMe ? 0 : 4,
                        right: isMe ? 4 : 0),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.black.withOpacity(0.28),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Group share card bubble ───────────────────────────────────────────────
  Widget _buildGroupShareBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isLastInGroup,
      String time,
      String hiResAvatar,
      ) {
    final groupName = (msg['group_name'] ?? 'Unknown Group').toString();
    final groupImage = (msg['group_image'] ?? '').toString();
    final groupType = (msg['group_type'] ?? '').toString();

    // Reconstruct the group map so GroupDetailScreen can receive it
    final groupData = Map<String, dynamic>.from(msg['group_data'] as Map? ?? {});
    if (groupData.isEmpty) {
      // Fallback: build minimal group map from message fields
      groupData['org_name'] = groupName;
      groupData['org_image'] = groupImage;
      groupData['org_type'] = groupType;
      groupData['org_id'] = (msg['group_id'] ?? '').toString();
    }

    return Padding(
      padding: EdgeInsets.only(
          bottom: isLastInGroup ? 12 : 2,
          left: isMe ? 60 : 38,
          right: isMe ? 4 : 60),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                children: [
                  _Avatar(
                    url: hiResAvatar,
                    name: widget.otherUserName,
                    radius: 10,
                    fontSize: 8,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          // ── Tappable card ───────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(group: groupData),
              ),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.15), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image banner
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15)),
                    child: groupImage.isNotEmpty
                        ? Image.network(
                      groupImage,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _groupSharePlaceholder(),
                    )
                        : _groupSharePlaceholder(),
                  ),

                  // Info row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (groupType.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                    AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    groupType,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              Text(
                                groupName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ],
                    ),
                  ),

                  // "Tap to view group" hint
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      'Tap to view group',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isLastInGroup)
            Padding(
              padding: EdgeInsets.only(
                  top: 4, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.black.withOpacity(0.28),
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _groupSharePlaceholder() => Container(
    height: 110,
    color: AppColors.primary.withOpacity(0.08),
    child: Center(
      child: Icon(Icons.group_rounded,
          size: 40, color: AppColors.primary.withOpacity(0.4)),
    ),
  );

  // ── Event share card bubble ───────────────────────────────────────────────
  Widget _buildEventShareBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isLastInGroup,
      String time,
      String hiResAvatar,
      ) {
    final eventTitle = (msg['event_title'] ?? 'Untitled Event').toString();
    final eventImage = (msg['event_image'] ?? '').toString();
    final eventDate = (msg['event_date'] ?? '').toString();
    final eventType = (msg['event_type'] ?? '').toString();

    final eventData =
    Map<String, dynamic>.from(msg['event_data'] as Map? ?? {});
    if (eventData.isEmpty) {
      eventData['event_title'] = eventTitle;
      eventData['event_pic'] = eventImage;
      eventData['event_type'] = eventType;
      eventData['event_id'] = (msg['event_id'] ?? '').toString();
    }

    return Padding(
      padding: EdgeInsets.only(
          bottom: isLastInGroup ? 12 : 2,
          left: isMe ? 60 : 38,
          right: isMe ? 4 : 60),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                children: [
                  _Avatar(
                    url: hiResAvatar,
                    name: widget.otherUserName,
                    radius: 10,
                    fontSize: 8,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(event: eventData),
              ),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.15), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15)),
                    child: eventImage.isNotEmpty
                        ? Image.network(
                      eventImage,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _eventSharePlaceholder(),
                    )
                        : _eventSharePlaceholder(),
                  ),

                  // Info + arrow
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (eventType.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                    AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    eventType,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              Text(
                                eventTitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (eventDate.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded,
                                          size: 11,
                                          color: AppColors.primary
                                              .withOpacity(0.7)),
                                      const SizedBox(width: 3),
                                      Text(
                                        eventDate,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary
                                              .withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      'Tap to view event',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isLastInGroup)
            Padding(
              padding: EdgeInsets.only(
                  top: 4, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.black.withOpacity(0.28),
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eventSharePlaceholder() => Container(
    height: 110,
    color: AppColors.primary.withOpacity(0.08),
    child: Center(
      child: Icon(Icons.event_rounded,
          size: 40, color: AppColors.primary.withOpacity(0.4)),
    ),
  );


  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F5),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppColors.primary.withOpacity(0.4)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(
                  fontSize: 15.5,
                  color: Color(0xFF1A1A1A),
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.28),
                      fontSize: 15.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1.0).animate(
              CurvedAnimation(
                  parent: _sendBtnController,
                  curve: Curves.easeOutBack),
            ),
            child: GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _isTyping
                      ? AppColors.primary
                      : const Color(0xFFE0E0E5),
                  shape: BoxShape.circle,
                  boxShadow: _isTyping
                      ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                      : [],
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: _isTyping
                      ? Colors.white
                      : Colors.black.withOpacity(0.28),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final hiResAvatar = _hiRes(widget.otherUserAvatar, size: 200);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _Avatar(
                url: hiResAvatar,
                name: widget.otherUserName,
                radius: 42,
                fontSize: 28,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.otherUserName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D0D0D),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Say hi to start the conversation 👋',
            style: TextStyle(
                fontSize: 14, color: Colors.black.withOpacity(0.35)),
          ),
        ],
      ),
    );
  }

  bool _isDifferentDay(dynamic a, dynamic b) {
    if (a is! Timestamp || b is! Timestamp) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year || da.month != db.month || da.day != db.day;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared Avatar widget — applies _hiRes and handles fallback initials
// ════════════════════════════════════════════════════════════════════════════

class _Avatar extends StatelessWidget {
  final String url;
  final String name;
  final double radius;
  final double fontSize;

  const _Avatar({
    required this.url,
    required this.name,
    required this.radius,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      onBackgroundImageError: url.isNotEmpty ? (_, __) {} : null,
      child: url.isEmpty
          ? Text(
        initial,
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

// ════════════════════════════════════════════════════════════════════════════
// User Profile Screen
// ════════════════════════════════════════════════════════════════════════════

class _UserProfileScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String avatarUrl;
  final VoidCallback onChat;
  final void Function(Map<String, dynamic> group)? onGroupTap;

  const _UserProfileScreen({
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.onChat,
    this.onGroupTap,
  });

  static PageRoute<void> route({
    required String userId,
    required String userName,
    required String avatarUrl,
    required VoidCallback onChat,
    void Function(Map<String, dynamic> group)? onGroupTap,
  }) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => _UserProfileScreen(
        userId: userId,
        userName: userName,
        avatarUrl: avatarUrl,
        onChat: onChat,
        onGroupTap: onGroupTap,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchRegistration() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('registration')
          .doc(userId)
          .get();
      if (doc.exists) return doc.data() ?? {};

      final q = await FirebaseFirestore.instance
          .collection('registration')
          .where('uid', isEqualTo: userId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first.data();
    } catch (_) {}
    return {};
  }

  Future<List<Map<String, dynamic>>> _fetchGroups() async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('user_groups')
          .where('user_id', isEqualTo: userId)
          .get();
      if (q.docs.isEmpty) return [];

      // Enrich each user_group entry with full org data from organizations
      final enriched = await Future.wait(q.docs.map((d) async {
        final ug = d.data();
        final groupId = (ug['group_id'] ?? '').toString();
        if (groupId.isEmpty) return ug;
        try {
          // Fetch org data by org_id
          final orgQ = await FirebaseFirestore.instance
              .collection('organizations')
              .where('org_id', isEqualTo: groupId)
              .limit(1)
              .get();
          if (orgQ.docs.isNotEmpty) {
            final org = orgQ.docs.first.data();
            // Also resolve location from locations collection
            final locId = (org['org_loc_id'] ?? '').toString();
            String city = '', prefecture = '';
            if (locId.isNotEmpty) {
              try {
                final locQ = await FirebaseFirestore.instance
                    .collection('locations')
                    .where('loc_id', isEqualTo: locId)
                    .limit(1)
                    .get();
                if (locQ.docs.isNotEmpty) {
                  final loc = locQ.docs.first.data();
                  city       = (loc['loc_city']       ?? '').toString();
                  prefecture = (loc['loc_prefecture']  ?? '').toString();
                }
              } catch (_) {}
            }
            return {
              ...ug,
              ...org,
              'loc_city': city,
              'loc_prefecture': prefecture,
            };
          }
        } catch (_) {}
        return ug;
      }));
      return enriched;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final hiResAvatar = _hiRes(avatarUrl, size: 600);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_fetchRegistration(), _fetchGroups()]),
      builder: (context, snapshot) {
        final data = snapshot.hasData
            ? snapshot.data![0] as Map<String, dynamic>
            : <String, dynamic>{};
        final groups = snapshot.hasData
            ? snapshot.data![1] as List<Map<String, dynamic>>
            : <Map<String, dynamic>>[];

        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        final resolvedName =
        (firstName.isNotEmpty || lastName.isNotEmpty)
            ? '$firstName $lastName'.trim()
            : userName;
        final firstNameOnly = firstName.isNotEmpty
            ? firstName
            : userName.split(' ').first;

        final bio = (data['description'] ?? '').toString().trim();
        final location = (data['address'] ?? '').toString().trim();

        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroHeader(
                  avatarUrl: hiResAvatar,
                  userName: resolvedName,
                  location: location,
                  onClose: () => Navigator.pop(context),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ChatButton(
                          label: 'Chat with $firstNameOnly',
                          onTap: () {
                            // Just pop the profile — chat screen is already underneath
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      _BellButton(),
                    ],
                  ),
                ),
              ),

              if (!snapshot.hasData)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                  ),
                ),

              if (snapshot.hasData && bio.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meet $firstNameOnly',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D0D0D),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          bio,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF3A3A3C),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (snapshot.hasData && groups.isNotEmpty)
                SliverToBoxAdapter(
                  child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.black.withOpacity(0.06)),
                ),

              if (snapshot.hasData && groups.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: Text(
                      'Groups Joined',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D0D0D),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _GroupCard(
                      group: groups[index],
                      onTap: onGroupTap != null
                          ? () => onGroupTap!(groups[index])
                          : null,
                    ),
                    childCount: groups.length,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        );
      },
    );
  }
}

// ── Hero Header ───────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final String avatarUrl;
  final String userName;
  final String location;
  final VoidCallback onClose;

  const _HeroHeader({
    required this.avatarUrl,
    required this.userName,
    required this.location,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final heroHeight = MediaQuery.of(context).size.height * 0.42;
    final initials = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          avatarUrl.isNotEmpty
              ? Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _gradientBox(initials),
          )
              : _gradientBox(initials),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.12),
                    Colors.black.withOpacity(0.65),
                  ],
                  stops: const [0.0, 0.42, 0.68, 1.0],
                ),
              ),
            ),
          ),

          Positioned(
            top: topPadding + 12,
            left: 16,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.close_rounded,
                    size: 19, color: AppColors.primary),
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    shadows: [
                      Shadow(
                          color: Colors.black38,
                          blurRadius: 10,
                          offset: Offset(0, 2))
                    ],
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 1))
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBox(String initials) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, const Color(0xFF1A6B4A), 0.5)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Chat Button ───────────────────────────────────────────────────────────────
class _ChatButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ChatButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bell Button ───────────────────────────────────────────────────────────────
class _BellButton extends StatefulWidget {
  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _active = !_active);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _active
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Icon(
          _active
              ? Icons.notifications_rounded
              : Icons.notifications_outlined,
          color: AppColors.primary,
          size: 23,
        ),
      ),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback? onTap;

  const _GroupCard({required this.group, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Field names — try all known variants from organizations + user_groups
    final name = (group['org_name'] ?? group['group_name'] ?? group['name'] ?? '').toString();
    final imageUrl = (group['org_image'] ?? group['group_image'] ?? group['image'] ?? '').toString();
    final hiResImage = _hiRes(imageUrl, size: 300);

    // Location resolved by _fetchGroups via locations collection
    final city       = (group['loc_city']       ?? '').toString();
    final prefecture = (group['loc_prefecture']  ?? '').toString();
    final location   = [city, prefecture].where((s) => s.isNotEmpty).join(', ');

    // Skill / schedule / age — organizations uses org_skill_level, org_schedule, org_age_groups
    final level    = (group['org_skill_level']  ?? group['level']      ?? '').toString();
    final schedule = (group['org_schedule']     ?? group['schedule']   ?? '').toString();
    final ageGroup = (group['org_age_groups']   ?? group['age_group']  ?? '').toString();
    final booking  = (group['org_booking']      ?? '').toString();

    // Build non-empty detail lines — same style as the reference screenshot
    final details = <String>[
      if (level.isNotEmpty)    level,
      if (schedule.isNotEmpty) schedule,
      if (ageGroup.isNotEmpty) ageGroup,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.10), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Thumbnail ──────────────────────────────────────
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(17),
                    bottomLeft: Radius.circular(17),
                  ),
                  child: SizedBox(
                    width: 90,
                    child: hiResImage.isNotEmpty
                        ? Image.network(
                      hiResImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                        : _placeholder(),
                  ),
                ),

                // ── Details ────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Group name
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D0D0D),
                            letterSpacing: -0.3,
                          ),
                        ),

                        // Location row
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 13, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Detail lines (level / schedule / age) — plain text like reference
                        ...details.map((d) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.black.withOpacity(0.5),
                              height: 1.3,
                            ),
                          ),
                        )),

                        // Booking chip (green accent)
                        if (booking.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _chip(booking, isGreen: true),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Chevron ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary.withOpacity(0.6),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {bool isGreen = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isGreen
            ? AppColors.primary.withOpacity(0.10)
            : const Color(0xFFEEEEF2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: isGreen ? AppColors.primary : const Color(0xFF3A3A3C),
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.08),
      child: Center(
        child: Icon(Icons.group_rounded,
            color: AppColors.primary.withOpacity(0.4), size: 32),
      ),
    );
  }
}