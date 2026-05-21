import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/services/chat_service.dart';
import 'package:pikuru/screens/chat_members_screen.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:pikuru/screens/event_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// i18n strings
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  final String today;
  final String yesterday;
  final String groupChat;
  final String members;
  final String noMessages;
  final String firstHello;
  final String unknown;
  final String untitledEvent;
  final String viewEventTap;
  final String viewEventBtn;
  final String unknownGroup;
  final String viewGroupTap;
  final String viewGroupBtn;
  final String messagePh;
  final String notifSilenced;
  final String notifEnabled;

  const _T({
    required this.today,
    required this.yesterday,
    required this.groupChat,
    required this.members,
    required this.noMessages,
    required this.firstHello,
    required this.unknown,
    required this.untitledEvent,
    required this.viewEventTap,
    required this.viewEventBtn,
    required this.unknownGroup,
    required this.viewGroupTap,
    required this.viewGroupBtn,
    required this.messagePh,
    required this.notifSilenced,
    required this.notifEnabled,
  });
}

const _en = _T(
  today:         'Today',
  yesterday:     'Yesterday',
  groupChat:     'Group Chat',
  members:       'members',
  noMessages:    'No messages yet',
  firstHello:    'Be the first to say hello! 👋',
  unknown:       'Unknown',
  untitledEvent: 'Untitled Event',
  viewEventTap:  'Tap to view event',
  viewEventBtn:  'View Event',
  unknownGroup:  'Unknown Group',
  viewGroupTap:  'Tap to view group',
  viewGroupBtn:  'View Group',
  messagePh:     'Message...',
  notifSilenced: 'Notifications silenced',
  notifEnabled:  'Notifications enabled',
);

const _ja = _T(
  today:         '今日',
  yesterday:     '昨日',
  groupChat:     'グループチャット',
  members:       'メンバー',
  noMessages:    'メッセージはまだありません',
  firstHello:    '最初に挨拶メッセージを送りましょう！ 👋',
  unknown:       '不明',
  untitledEvent: '無題のイベント',
  viewEventTap:  'タップしてイベントを表示',
  viewEventBtn:  'イベントを表示',
  unknownGroup:  '不明なグループ',
  viewGroupTap:  'タップしてグループを表示',
  viewGroupBtn:  'グループを表示',
  messagePh:     'メッセージ...',
  notifSilenced: '通知をミュートにしました',
  notifEnabled:  '通知を有効にしました',
);

_T _strings(String lang) => lang == kLangJa ? _ja : _en;

// ─────────────────────────────────────────────────────────────────────────────
// Avatar helpers — shared across the whole file
// ─────────────────────────────────────────────────────────────────────────────

/// Normalise profile_img: raw base64 → data URL, http → as-is, empty → ''
String _toImgSrc(String raw) {
  if (raw.isEmpty)             return '';
  if (raw.startsWith('data:')) return raw;
  if (raw.startsWith('http'))  return raw;
  return 'data:image/jpeg;base64,$raw';
}

/// Decode any avatar string → ImageProvider (http, data:base64, raw base64)
ImageProvider? _resolveImage(String av) {
  if (av.isEmpty) return null;
  try {
    if (av.startsWith('http'))  return NetworkImage(av);
    if (av.startsWith('data:')) {
      final comma = av.indexOf(',');
      if (comma != -1) return MemoryImage(base64Decode(av.substring(comma + 1)));
    }
    return MemoryImage(base64Decode(av)); // raw base64
  } catch (_) {
    return null;
  }
}

/// Small reusable avatar widget that handles all three formats
class _Avatar extends StatelessWidget {
  final String avatarSrc; // already normalised via _toImgSrc
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
      backgroundColor: AppColors.primary.withOpacity(0.12),
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
// GroupChatScreen
// ─────────────────────────────────────────────────────────────────────────────
class GroupChatScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> group;

  const GroupChatScreen({super.key, required this.group});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController      _scrollController  = ScrollController();
  final FocusNode             _focusNode         = FocusNode();
  final currentUser = FirebaseAuth.instance.currentUser;

  String? _chatId;
  bool _isLoading  = true;
  bool _isTyping   = false;
  bool _isSilenced = false;

  Map<String, dynamic>? _groupData;

  // ── Real-time sender profile cache: senderId → {name, avatar} ──────────
  final Map<String, Map<String, String>> _senderCache = {};
  final Map<String, StreamSubscription>  _senderSubs  = {};

  AnimationController? _sendBtnController;
  Animation<double>?   _sendBtnAnim;

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
    for (final sub in _senderSubs.values) sub.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendBtnController?.dispose();
    super.dispose();
  }

  // ── Subscribe to a sender's registration doc in real-time ──────────────
  void _ensureSenderSubscription(String uid) {
    if (_senderSubs.containsKey(uid)) return;

    final sub = FirebaseFirestore.instance
        .collection('registration')
        .doc(uid)
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
          : (_senderCache[uid]?['name'] ?? '');

      setState(() {
        _senderCache[uid] = {
          'name':   name,
          'avatar': _toImgSrc(rawImg),
        };
      });
    }, onError: (e) {
      debugPrint('[GroupChatScreen] sender sub error for $uid: $e');
    });

    _senderSubs[uid] = sub;
  }

  /// Get the live name for a sender, falling back to the message field
  String _senderName(String uid, String fallback) =>
      (_senderCache[uid]?['name'] ?? '').isNotEmpty
          ? _senderCache[uid]!['name']!
          : fallback;

  /// Get the live avatar for a sender, falling back to the message field
  String _senderAvatar(String uid, String fallback) =>
      (_senderCache[uid]?['avatar'] ?? '').isNotEmpty
          ? _senderCache[uid]!['avatar']!
          : _toImgSrc(fallback);

  // ── Init ──────────────────────────────────────────────────────────────
  Future<void> _initChat() async {
    final orgId = widget.group['_doc_id'] ??
        widget.group['doc_id'] ??
        widget.group['org_id'] ??
        widget.group['org_handle_name'] ??
        '';
    if (orgId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    _fetchGroupData(orgId);

    final chatId = await ChatService.getOrCreateChatId(orgId);

    final user = currentUser;
    if (user != null) {
      // Subscribe to current user's own profile too (for send avatar)
      _ensureSenderSubscription(user.uid);

      final participantRef = FirebaseFirestore.instance
          .collection('group_chats')
          .doc(chatId)
          .collection('participants')
          .doc(user.uid);

      final pDoc = await participantRef.get();
      if (!pDoc.exists) {
        await participantRef.set({
          'user_id':      user.uid,
          'display_name': user.displayName ?? 'Anonymous',
          'avatar_url':   user.photoURL ?? '',
          'joined_at':    FieldValue.serverTimestamp(),
          'last_read_at': FieldValue.serverTimestamp(),
          'is_silenced':  false,
        });
        if (mounted) setState(() => _isSilenced = false);
      } else {
        await participantRef.set(
          {'last_read_at': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        if (mounted) {
          setState(() => _isSilenced = pDoc.data()?['is_silenced'] == true);
        }
      }
    }

    await ChatService.markAsRead(chatId);
    if (mounted) {
      setState(() {
        _chatId    = chatId;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGroupData(String orgId) async {
    try {
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      if (orgDoc.exists) {
        final data = orgDoc.data()!;
        data['_doc_id'] = orgDoc.id;
        if (mounted) setState(() => _groupData = data);
        return;
      }

      final q = await FirebaseFirestore.instance
          .collection('organizations')
          .where('org_id', isEqualTo: orgId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        data['_doc_id'] = q.docs.first.id;
        if (mounted) setState(() => _groupData = data);
        return;
      }
    } catch (e) {
      debugPrint('[GroupChatScreen] _fetchGroupData error: $e');
    }
    if (mounted) setState(() => _groupData = widget.group);
  }

  Future<void> _toggleSilence() async {
    if (_chatId == null || currentUser == null) return;
    final t        = _strings(ref.read(appLangProvider));
    final newValue = !_isSilenced;
    HapticFeedback.lightImpact();
    setState(() => _isSilenced = newValue);

    try {
      await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(_chatId!)
          .collection('participants')
          .doc(currentUser!.uid)
          .set({'is_silenced': newValue}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(
                newValue
                    ? Icons.notifications_off_rounded
                    : Icons.notifications_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                newValue ? t.notifSilenced : t.notifEnabled,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ]),
            backgroundColor:
            newValue ? const Color(0xFF3A3A3C) : AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSilenced = !newValue);
      debugPrint('[GroupChatScreen] _toggleSilence error: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_chatId == null || _messageController.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    final text = _messageController.text;
    _messageController.clear();
    _focusNode.requestFocus();
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

  void _openMembersScreen() {
    if (_chatId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatMembersScreen(
          chatId:    _chatId!,
          groupName: (_groupData ?? widget.group)['org_name'] ?? 'Group Chat',
        ),
      ),
    );
  }

  void _openGroupDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(group: _groupData ?? widget.group),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang    = ref.watch(appLangProvider);
    final t       = _strings(lang);
    final orgName  = (_groupData ?? widget.group)['org_name']  ?? t.groupChat;
    final orgImage = (_groupData ?? widget.group)['org_image'] ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _buildAppBar(orgName, orgImage, t),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _isLoading
                  ? _buildLoader()
                  : _chatId == null
                  ? _buildError()
                  : _buildMessageList(t),
            ),
          ),
          SafeArea(top: false, child: _buildInputBar(t)),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────
  Widget _buildAppBar(String orgName, String orgImage, _T t) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 24,
              offset: Offset(0, 6)),
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Color(0xFF1C1C1E)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _openGroupDetail,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 46, height: 46,
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
                                    size: 22),
                              ),
                            )
                                : const Icon(Icons.group_rounded,
                                color: Colors.white, size: 22),
                          ),
                          Positioned(
                            right: 1, bottom: 1,
                            child: Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: Colors.white, width: 2),
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
                                  letterSpacing: -0.4),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            if (_chatId != null)
                              StreamBuilder<int>(
                                stream:
                                ChatService.memberCountStream(_chatId!),
                                builder: (context, snapshot) {
                                  final count = snapshot.data ?? 0;
                                  return Row(children: [
                                    Container(
                                      width: 6, height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF34C759),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '$count ${t.members}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ]);
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _SilenceButton(
                  isSilenced: _isSilenced, onTap: _toggleSilence),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openMembersScreen,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.people_alt_rounded,
                      size: 19, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Message List ───────────────────────────────────────────────────────
  Widget _buildMessageList(_T t) {
    return StreamBuilder<QuerySnapshot>(
      stream: ChatService.messagesStream(_chatId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoader();
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) return _buildEmptyState(t);
        _scrollToBottom();

        // ── Subscribe to every unique sender in real-time ──────────────
        for (final doc in messages) {
          final msg      = doc.data() as Map<String, dynamic>;
          final senderId = (msg['sender_id'] ?? '').toString();
          if (senderId.isNotEmpty) _ensureSenderSubscription(senderId);
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
                if (showDate) _buildDateDivider(msg['sent_at'], t),
                _buildMessageBubble(
                    msg, isMe, isFirstInGroup, isLastInGroup, t),
              ],
            );
          },
        );
      },
    );
  }

  // ── Date Divider ───────────────────────────────────────────────────────
  Widget _buildDateDivider(dynamic timestamp, _T t) {
    String label = t.today;
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now  = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (diff == 0)      label = t.today;
      else if (diff == 1) label = t.yesterday;
      else                label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: Colors.black.withOpacity(0.08))),
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
              child: Divider(color: Colors.black.withOpacity(0.08))),
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
      _T t,
      ) {
    final Timestamp? sentAt = msg['sent_at'];
    final time              = sentAt != null ? _formatTime(sentAt.toDate()) : '';

    if ((msg['type'] ?? '') == 'group_share') {
      return _buildGroupShareBubble(
          msg, isMe, isFirstInGroup, isLastInGroup, time, t);
    }
    if ((msg['type'] ?? '') == 'event_share') {
      return _buildEventShareBubble(
          msg, isMe, isFirstInGroup, isLastInGroup, time, t);
    }

    final text       = msg['text'] ?? '';
    final senderId   = (msg['sender_id']     ?? '').toString();
    final msgName    = (msg['sender_name']   ?? '').toString();
    final msgAvatar  = (msg['sender_avatar'] ?? '').toString();

    // ── Use live registration data, fall back to message fields ──────────
    final liveName   = _senderName(senderId, msgName);
    final liveAvatar = _senderAvatar(senderId, msgAvatar);

    final bubbleRadius = BorderRadius.only(
      topLeft:     Radius.circular(!isMe && !isFirstInGroup ? 6 : 20),
      topRight:    Radius.circular(isMe  && !isFirstInGroup ? 6 : 20),
      bottomLeft:  Radius.circular(!isMe && !isLastInGroup  ? 6 : 20),
      bottomRight: Radius.circular(isMe  && !isLastInGroup  ? 6 : 20),
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
                  ? _Avatar(
                avatarSrc: liveAvatar,
                name:      liveName,
                radius:    17,
                fontSize:  13,
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
                      liveName,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.1),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.66),
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
                        color:
                        isMe ? Colors.white : const Color(0xFF1C1C1E),
                        height: 1.45,
                        letterSpacing: -0.1),
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
                          letterSpacing: 0.1),
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

  // ── Group Share Bubble ─────────────────────────────────────────────────
  Widget _buildGroupShareBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isFirstInGroup,
      bool isLastInGroup,
      String time,
      _T t,
      ) {
    final groupName  = (msg['group_name']    ?? t.unknownGroup).toString();
    final groupImage = (msg['group_image']   ?? '').toString();
    final groupType  = (msg['group_type']    ?? '').toString();
    final senderId   = (msg['sender_id']     ?? '').toString();
    final msgName    = (msg['sender_name']   ?? '').toString();
    final msgAvatar  = (msg['sender_avatar'] ?? '').toString();

    final liveName   = _senderName(senderId, msgName);
    final liveAvatar = _senderAvatar(senderId, msgAvatar);

    final groupData =
    Map<String, dynamic>.from(msg['group_data'] as Map? ?? {});
    if (groupData.isEmpty) {
      groupData['org_name']  = groupName;
      groupData['org_image'] = groupImage;
      groupData['org_type']  = groupType;
      groupData['org_id']    = (msg['group_id'] ?? '').toString();
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInGroup ? 10 : 2,
        left:  isMe ? 60 : 42,
        right: isMe ? 4  : 60,
      ),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && isFirstInGroup)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Avatar(
                      avatarSrc: liveAvatar,
                      name:      liveName,
                      radius:    10,
                      fontSize:  8),
                  const SizedBox(width: 5),
                  Text(liveName,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.1)),
                ],
              ),
            ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(group: groupData)),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.66,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.15), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15)),
                    child: groupImage.isNotEmpty
                        ? Image.network(groupImage,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _groupSharePlaceholder())
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
                                    color:
                                    AppColors.primary.withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(20)),
                                child: Text(groupType,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                            Text(groupName,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1A)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 13),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(t.viewGroupTap,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary.withOpacity(0.6),
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
          if (isLastInGroup)
            Padding(
              padding: EdgeInsets.only(
                  top: 5, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
              child: Text(time,
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFFAEAEB2),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1)),
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
            size: 40, color: AppColors.primary.withOpacity(0.4))),
  );

  // ── Event Share Bubble ─────────────────────────────────────────────────
  Widget _buildEventShareBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isFirstInGroup,
      bool isLastInGroup,
      String time,
      _T t,
      ) {
    final eventTitle = (msg['event_title']   ?? t.untitledEvent).toString();
    final eventImage = (msg['event_image']   ?? '').toString();
    final eventDate  = (msg['event_date']    ?? '').toString();
    final eventType  = (msg['event_type']    ?? '').toString();
    final senderId   = (msg['sender_id']     ?? '').toString();
    final msgName    = (msg['sender_name']   ?? '').toString();
    final msgAvatar  = (msg['sender_avatar'] ?? '').toString();

    final liveName   = _senderName(senderId, msgName);
    final liveAvatar = _senderAvatar(senderId, msgAvatar);

    final eventData =
    Map<String, dynamic>.from(msg['event_data'] as Map? ?? {});
    if (eventData.isEmpty) {
      eventData['event_title'] = eventTitle;
      eventData['event_pic']   = eventImage;
      eventData['event_type']  = eventType;
      eventData['event_id']    = (msg['event_id'] ?? '').toString();
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInGroup ? 10 : 2,
        left:  isMe ? 60 : 42,
        right: isMe ? 4  : 60,
      ),
      child: Column(
        crossAxisAlignment:
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && isFirstInGroup)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Avatar(
                      avatarSrc: liveAvatar,
                      name:      liveName,
                      radius:    10,
                      fontSize:  8),
                  const SizedBox(width: 5),
                  Text(liveName,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          letterSpacing: 0.1)),
                ],
              ),
            ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: eventData)),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.66,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.15), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15)),
                    child: eventImage.isNotEmpty
                        ? Image.network(eventImage,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _eventSharePlaceholder())
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
                                    color:
                                    AppColors.primary.withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(20)),
                                child: Text(eventType,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                            Text(eventTitle,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1A)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            if (eventDate.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 11,
                                      color:
                                      AppColors.primary.withOpacity(0.7)),
                                  const SizedBox(width: 3),
                                  Text(eventDate,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary
                                              .withOpacity(0.8),
                                          fontWeight: FontWeight.w500)),
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
                            borderRadius: BorderRadius.circular(9)),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 13),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(t.viewEventTap,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary.withOpacity(0.6),
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
          if (isLastInGroup)
            Padding(
              padding: EdgeInsets.only(
                  top: 5, left: isMe ? 0 : 4, right: isMe ? 4 : 0),
              child: Text(time,
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFFAEAEB2),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1)),
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
            size: 40, color: AppColors.primary.withOpacity(0.4))),
  );

  // ── Input Bar ──────────────────────────────────────────────────────────
  Widget _buildInputBar(_T t) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 24,
              offset: Offset(0, -6))
        ],
      ),
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
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1C1C1E),
                    height: 1.4),
                decoration: InputDecoration(
                  hintText: t.messagePh,
                  hintStyle: const TextStyle(
                      color: Color(0xFFAEAEB2), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
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
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isTyping
                      ? [
                    AppColors.primary,
                    Color.lerp(AppColors.primary,
                        const Color(0xFF1A6B4A), 0.35)!
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
                      offset: const Offset(0, 5))
                ]
                    : [],
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  Widget _buildLoader() => Center(
      child: CircularProgressIndicator(
          color: AppColors.primary, strokeWidth: 2.5));

  Widget _buildError() => const Center(
      child: Text('Could not load chat',
          style: TextStyle(color: Color(0xFFAEAEB2))));

  Widget _buildEmptyState(_T t) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle),
          child: Icon(Icons.chat_bubble_outline_rounded,
              size: 34, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        Text(t.noMessages,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(t.firstHello,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFFAEAEB2))),
      ],
    ),
  );

  bool _isDifferentDay(dynamic a, dynamic b) {
    if (a is! Timestamp || b is! Timestamp) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year ||
        da.month != db.month ||
        da.day != db.day;
  }

  String _formatTime(DateTime dt) {
    final hour   = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ── Silence Button ─────────────────────────────────────────────────────────────
class _SilenceButton extends StatefulWidget {
  final bool isSilenced;
  final VoidCallback onTap;

  const _SilenceButton({required this.isSilenced, required this.onTap});

  @override
  State<_SilenceButton> createState() => _SilenceButtonState();
}

class _SilenceButtonState extends State<_SilenceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: widget.isSilenced
                ? AppColors.primary.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSilenced
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              widget.isSilenced
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_rounded,
              key: ValueKey(widget.isSilenced),
              size: 19,
              color: widget.isSilenced
                  ? AppColors.primary
                  : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }
}