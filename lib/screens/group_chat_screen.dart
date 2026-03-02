import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/services/chat_service.dart';
import 'package:pikuru/screens/chat_members_screen.dart'; // ← add this import

class GroupChatScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final currentUser = FirebaseAuth.instance.currentUser;

  String? _chatId;
  bool _isLoading = true;
  bool _isTyping = false;

  AnimationController? _sendBtnController;
  Animation<double>? _sendBtnAnim;

  @override
  void initState() {
    super.initState();

    _sendBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sendBtnAnim = CurvedAnimation(
      parent: _sendBtnController!,
      curve: Curves.easeOut,
    );

    _messageController.addListener(() {
      final typing = _messageController.text.trim().isNotEmpty;
      if (typing != _isTyping) {
        setState(() => _isTyping = typing);
        typing
            ? _sendBtnController?.forward()
            : _sendBtnController?.reverse();
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
    _sendBtnController?.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final orgId = widget.group['doc_id'] ??
        widget.group['org_id'] ??
        widget.group['org_handle_name'] ??
        '';
    if (orgId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    final chatId = await ChatService.getOrCreateChatId(orgId);
    await ChatService.joinChat(chatId);
    await ChatService.markAsRead(chatId);
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
    await ChatService.sendMessage(_chatId!, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ── Open Members Screen ────────────────────────────────────────────────
  void _openMembersScreen() {
    if (_chatId == null) return;
    final orgName = widget.group['org_name'] ?? 'Group Chat';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatMembersScreen(
          chatId: _chatId!,
          groupName: orgName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgName = widget.group['org_name'] ?? 'Group Chat';
    final orgImage = widget.group['org_image'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _buildAppBar(orgName, orgImage),
          Expanded(
            child: _isLoading
                ? _buildLoader()
                : _chatId == null
                ? _buildError()
                : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────
  Widget _buildAppBar(String orgName, String orgImage) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Color(0xFF1C1C1E),
                ),
              ),

              // Avatar with online dot
              Stack(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.7),
                          AppColors.primary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: orgImage.isNotEmpty
                        ? ClipOval(
                      child: Image.network(
                        orgImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.group_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    )
                        : const Icon(
                      Icons.group_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      orgName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    if (_chatId != null)
                      StreamBuilder<int>(
                        stream: ChatService.memberCountStream(_chatId!),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$count members',
                                style: TextStyle(
                                  fontSize: 12,
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
              ),

              // ✅ Members icon — now opens ChatMembersScreen
              GestureDetector(
                onTap: _openMembersScreen,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Message List ───────────────────────────────────────────────────────
  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: ChatService.messagesStream(_chatId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoader();
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) return _buildEmptyState();
        _scrollToBottom();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
                _buildMessageBubble(
                    msg, isMe, isFirstInGroup, isLastInGroup),
              ],
            );
          },
        );
      },
    );
  }

  // ── Date Divider ───────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.black.withOpacity(0.08))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 8),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.black.withOpacity(0.08))),
        ],
      ),
    );
  }

  // ── Message Bubble ─────────────────────────────────────────────────────
  Widget _buildMessageBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isFirstInGroup,
      bool isLastInGroup,
      ) {
    final text = msg['text'] ?? '';
    final senderName = msg['sender_name'] ?? '';
    final avatarUrl = msg['sender_avatar'] ?? '';
    final Timestamp? sentAt = msg['sent_at'];
    final time = sentAt != null ? _formatTime(sentAt.toDate()) : '';

    final bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(!isMe && !isFirstInGroup ? 6 : 20),
      topRight: Radius.circular(isMe && !isFirstInGroup ? 6 : 20),
      bottomLeft: Radius.circular(!isMe && !isLastInGroup ? 6 : 20),
      bottomRight: Radius.circular(isMe && !isLastInGroup ? 6 : 20),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLastInGroup ? 10 : 2),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 34,
              child: isLastInGroup
                  ? CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? Text(
                  senderName.isNotEmpty
                      ? senderName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isFirstInGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 5),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),

                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.66,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(
                      colors: [
                        AppColors.primary,
                        Color.lerp(AppColors.primary,
                            const Color(0xFF1A6B4A), 0.4)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: bubbleRadius,
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? AppColors.primary.withOpacity(0.22)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: isMe ? 14 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                      height: 1.45,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),

                if (isLastInGroup)
                  Padding(
                    padding:
                    const EdgeInsets.only(top: 5, left: 4, right: 4),
                    child: Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFAEAEB2),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
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

  // ── Input Bar ──────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? AppColors.primary.withOpacity(0.35)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1C1C1E),
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(
                        color: Color(0xFFAEAEB2),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isTyping
                          ? [
                        AppColors.primary,
                        Color.lerp(AppColors.primary,
                            const Color(0xFF1A6B4A), 0.35)!,
                      ]
                          : const [
                        Color(0xFFD1D1D6),
                        Color(0xFFD1D1D6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: _isTyping
                        ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.38),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                        : [],
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  Widget _buildLoader() => Center(
    child: CircularProgressIndicator(
        color: AppColors.primary, strokeWidth: 2.5),
  );

  Widget _buildError() => const Center(
    child: Text('Could not load chat',
        style: TextStyle(color: Color(0xFFAEAEB2))),
  );

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.chat_bubble_outline_rounded,
              size: 34, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        const Text(
          'No messages yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Be the first to say hello! 👋',
          style: TextStyle(fontSize: 14, color: Color(0xFFAEAEB2)),
        ),
      ],
    ),
  );

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