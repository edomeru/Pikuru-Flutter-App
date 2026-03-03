import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/services/individual_chat_service.dart';

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

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final currentUser = FirebaseAuth.instance.currentUser;

  String? _chatId;
  bool _isLoading = true;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();

    _messageController.addListener(() {
      final typing = _messageController.text.trim().isNotEmpty;
      if (typing != _isTyping) setState(() => _isTyping = typing);
    });

    _focusNode.addListener(() => setState(() {}));
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5))
                : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
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
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Color(0xFF1C1C1E)),
              ),

              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: widget.otherUserAvatar.isNotEmpty
                    ? NetworkImage(widget.otherUserAvatar)
                    : null,
                child: widget.otherUserAvatar.isEmpty
                    ? Text(
                  widget.otherUserName.isNotEmpty
                      ? widget.otherUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
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
      stream: IndividualChatService.messagesStream(_chatId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5));
        }

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
                _buildMessageBubble(msg, isMe, isFirstInGroup, isLastInGroup),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          // Other user avatar (only shown on last bubble in a group)
          if (!isMe) ...[
            SizedBox(
              width: 34,
              child: isLastInGroup
                  ? CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                backgroundImage: widget.otherUserAvatar.isNotEmpty
                    ? NetworkImage(widget.otherUserAvatar)
                    : null,
                child: widget.otherUserAvatar.isEmpty
                    ? Text(
                  widget.otherUserName.isNotEmpty
                      ? widget.otherUserName[0].toUpperCase()
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
                // Bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
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

                // Timestamp
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
              // Text field
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
                      hintText: 'Aa',
                      hintStyle: TextStyle(
                        color: Color(0xFFAEAEB2),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Send button
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
                          : const [Color(0xFFD1D1D6), Color(0xFFD1D1D6)],
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
                  child: const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.primary.withOpacity(0.08),
            backgroundImage: widget.otherUserAvatar.isNotEmpty
                ? NetworkImage(widget.otherUserAvatar)
                : null,
            child: widget.otherUserAvatar.isEmpty
                ? Text(
              widget.otherUserName.isNotEmpty
                  ? widget.otherUserName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            widget.otherUserName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Say hi to start the conversation! 👋',
            style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.35)),
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