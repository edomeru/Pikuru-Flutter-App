import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/services/individual_chat_service.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:pikuru/modal/user_profile_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localised strings — mirrors the web app's T map in individual chat
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'today':            'Today',
    'yesterday':        'Yesterday',
    'noMessages':       'No messages yet',
    'firstHello':       'Say hi to start the conversation 👋',
    'tapToViewProfile': 'Tap to view profile',
    'tapToViewGroup':   'Tap to view group',
    'tapToViewEvent':   'Tap to view event',
    'messagePh':        'Message…',
    'unknown':          'Unknown',
    'untitledEvent':    'Untitled Event',
    'unknownGroup':     'Unknown Group',
  },
  kLangJa: {
    'today':            '今日',
    'yesterday':        '昨日',
    'noMessages':       'メッセージはまだありません',
    'firstHello':       '挨拶をして会話を始めましょう 👋',
    'tapToViewProfile': 'タップしてプロフィールを表示',
    'tapToViewGroup':   'タップしてグループを表示',
    'tapToViewEvent':   'タップしてイベントを表示',
    'messagePh':        'メッセージ...',
    'unknown':          '不明',
    'untitledEvent':    '無題のイベント',
    'unknownGroup':     '不明なグループ',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// IndividualChatScreen — ConsumerStatefulWidget
// ─────────────────────────────────────────────────────────────────────────────
class IndividualChatScreen extends ConsumerStatefulWidget {
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
  ConsumerState<IndividualChatScreen> createState() =>
      _IndividualChatScreenState();
}

class _IndividualChatScreenState extends ConsumerState<IndividualChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController      _scrollController  = ScrollController();
  final FocusNode             _focusNode         = FocusNode();
  final currentUser = FirebaseAuth.instance.currentUser;

  String? _chatId;
  bool _isLoading = true;
  bool _isTyping  = false;

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
      otherUserId:    widget.otherUserId,
      otherUserName:  widget.otherUserName,
      otherUserAvatar: widget.otherUserAvatar,
    );
    if (mounted) {
      setState(() {
        _chatId    = chatId;
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
      UserProfileModal.route(
        userId:    widget.otherUserId,
        userName:  widget.otherUserName,
        avatarUrl: widget.otherUserAvatar,
        onChat:    () {},
        onGroupTap: (group) {
          final mapped = {
            ...group,
            'org_name':        group['group_name']  ?? group['org_name']  ?? '',
            'org_image':       group['group_image'] ?? group['org_image'] ?? '',
            'org_id':          group['group_id']    ?? group['org_id']    ?? '',
            'org_description': group['org_description'] ?? '',
          };
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

  // ── Localised group name — mirrors web app's org_name_jp fallback ──────────
  String _groupName(Map<String, dynamic> msg, String lang) {
    if (lang == kLangJa) {
      final jp = (msg['group_name_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (msg['group_name'] ?? '').toString();
  }

  // ── Localised event title — mirrors web app's event_title_jp fallback ──────
  String _eventTitle(Map<String, dynamic> msg, String lang) {
    if (lang == kLangJa) {
      final jp = (msg['event_title_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (msg['event_title'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch global lang provider — rebuilds when lang changes anywhere
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF7F7F9),
      body: Column(
        children: [
          SafeArea(bottom: false, child: _buildAppBar(lang)),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _isLoading
                  ? Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
                  : _buildMessageList(lang),
            ),
          ),
          SafeArea(top: false, child: _buildInputBar(lang)),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar(String lang) {
    final hiResAvatar = hiRes(widget.otherUserAvatar);
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
                        UserAvatar(
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
                              // Localised "Tap to view profile"
                              Text(
                                _t(lang, 'tapToViewProfile'),
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

  // ── Message List ──────────────────────────────────────────────────────────
  Widget _buildMessageList(String lang) {
    return StreamBuilder<QuerySnapshot>(
      stream: IndividualChatService.messagesStream(_chatId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2));
        }
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) return _buildEmptyState(lang);
        _scrollToBottom();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg    = messages[index].data() as Map<String, dynamic>;
            final isMe   = msg['sender_id'] == currentUser?.uid;
            final prevSenderId = index > 0
                ? (messages[index - 1].data()
            as Map<String, dynamic>)['sender_id']
                : null;
            final nextSenderId = index < messages.length - 1
                ? (messages[index + 1].data()
            as Map<String, dynamic>)['sender_id']
                : null;
            final isFirstInGroup = prevSenderId != msg['sender_id'];
            final isLastInGroup  = nextSenderId != msg['sender_id'];
            final showDate = index == 0 ||
                _isDifferentDay(
                  (messages[index - 1].data()
                  as Map<String, dynamic>)['sent_at'],
                  msg['sent_at'],
                );
            return Column(
              children: [
                if (showDate) _buildDateDivider(msg['sent_at'], lang),
                _buildMessageBubble(
                    msg, isMe, isFirstInGroup, isLastInGroup, lang),
              ],
            );
          },
        );
      },
    );
  }

  // ── Date divider — localised Today / Yesterday ────────────────────────────
  Widget _buildDateDivider(dynamic timestamp, String lang) {
    String label = _t(lang, 'today');
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now  = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (diff == 0)      label = _t(lang, 'today');
      else if (diff == 1) label = _t(lang, 'yesterday');
      else                label = '${date.day}/${date.month}/${date.year}';
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

  // ── Message Bubble ────────────────────────────────────────────────────────
  Widget _buildMessageBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isFirstInGroup,
      bool isLastInGroup,
      String lang,
      ) {
    final Timestamp? sentAt   = msg['sent_at'];
    final time                = sentAt != null ? _formatTime(sentAt.toDate()) : '';
    final hiResAvatar         = hiRes(widget.otherUserAvatar);

    if ((msg['type'] ?? '') == 'group_share') {
      return _buildGroupShareBubble(
          msg, isMe, isLastInGroup, time, hiResAvatar, lang);
    }
    if ((msg['type'] ?? '') == 'event_share') {
      return _buildEventShareBubble(
          msg, isMe, isLastInGroup, time, hiResAvatar, lang);
    }

    final text = msg['text'] ?? '';
    final bubbleRadius = BorderRadius.only(
      topLeft:     Radius.circular(!isMe && !isFirstInGroup ? 5 : 22),
      topRight:    Radius.circular(isMe  && !isFirstInGroup ? 5 : 22),
      bottomLeft:  Radius.circular(!isMe && !isLastInGroup  ? 5 : 22),
      bottomRight: Radius.circular(isMe  && !isLastInGroup  ? 5 : 22),
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
                child: UserAvatar(
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
                      color: isMe ? Colors.white : const Color(0xFF1A1A1A),
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

  // ── Group share bubble — localised name via org_name_jp ───────────────────
  Widget _buildGroupShareBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isLastInGroup,
      String time,
      String hiResAvatar,
      String lang,
      ) {
    // Use localised group name — mirrors web app's group_name_jp field
    final groupName  = _groupName(msg, lang).isNotEmpty
        ? _groupName(msg, lang)
        : _t(lang, 'unknownGroup');
    final groupImage = (msg['group_image'] ?? '').toString();
    final groupType  = (msg['group_type']  ?? '').toString();

    final groupData = Map<String, dynamic>.from(msg['group_data'] as Map? ?? {});
    if (groupData.isEmpty) {
      groupData['org_name']  = groupName;
      groupData['org_image'] = groupImage;
      groupData['org_type']  = groupType;
      groupData['org_id']    = (msg['group_id'] ?? '').toString();
    }

    return Padding(
      padding: EdgeInsets.only(
          bottom: isLastInGroup ? 12 : 2,
          left:  isMe ? 60 : 38,
          right: isMe ? 4  : 60),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(children: [
                UserAvatar(
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
              ]),
            ),

          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(group: groupData)),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Row(children: [
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
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(groupType,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                            Text(
                              groupName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A)),
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
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      _t(lang, 'tapToViewGroup'),
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
                    letterSpacing: 0.2),
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

  // ── Event share bubble — localised title via event_title_jp ──────────────
  Widget _buildEventShareBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isLastInGroup,
      String time,
      String hiResAvatar,
      String lang,
      ) {
    // Use localised event title — mirrors web app's event_title_jp field
    final eventTitle = _eventTitle(msg, lang).isNotEmpty
        ? _eventTitle(msg, lang)
        : _t(lang, 'untitledEvent');
    final eventImage = (msg['event_image'] ?? '').toString();
    final eventDate  = (msg['event_date']  ?? '').toString();
    final eventType  = (msg['event_type']  ?? '').toString();

    final eventData = Map<String, dynamic>.from(msg['event_data'] as Map? ?? {});
    if (eventData.isEmpty) {
      eventData['event_title'] = eventTitle;
      eventData['event_pic']   = eventImage;
      eventData['event_type']  = eventType;
      eventData['event_id']    = (msg['event_id'] ?? '').toString();
    }

    return Padding(
      padding: EdgeInsets.only(
          bottom: isLastInGroup ? 12 : 2,
          left:  isMe ? 60 : 38,
          right: isMe ? 4  : 60),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(children: [
                UserAvatar(
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
              ]),
            ),

          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: eventData)),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Row(children: [
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
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(eventType,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                            Text(
                              eventTitle,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (eventDate.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 11,
                                      color: AppColors.primary.withOpacity(0.7)),
                                  const SizedBox(width: 3),
                                  Text(
                                    eventDate,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ]),
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
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      _t(lang, 'tapToViewEvent'),
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
                    letterSpacing: 0.2),
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

  // ── Input Bar — localised placeholder ────────────────────────────────────
  Widget _buildInputBar(String lang) {
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
                  hintText: _t(lang, 'messagePh'),
                  hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.28), fontSize: 15.5),
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

  // ── Empty State — localised ────────────────────────────────────────────────
  Widget _buildEmptyState(String lang) {
    final hiResAvatar = hiRes(widget.otherUserAvatar, size: 200);
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
              child: UserAvatar(
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
            _t(lang, 'firstHello'),
            style: TextStyle(
                fontSize: 14, color: Colors.black.withOpacity(0.35)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _isDifferentDay(dynamic a, dynamic b) {
    if (a is! Timestamp || b is! Timestamp) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year || da.month != db.month || da.day != db.day;
  }

  String _formatTime(DateTime dt) {
    final hour =
    dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}