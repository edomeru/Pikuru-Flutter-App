import 'dart:async';
import 'dart:convert';
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
import 'package:pikuru/screens/user_profile_screen.dart';
import 'package:pikuru/services/block_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localised strings
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
    'block':            'Block User',
    'unblock':          'Unblock User',
    'blockedBanner':    "You've blocked this user. Unblock to chat.",
    'blockedByBanner':  'This user is currently unavailable.',
    'blockedBadge':     'Blocked',
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
    'block':            'ユーザーをブロックする',
    'unblock':          'ユーザーのブロックを解除する',
    'blockedBanner':    'このユーザーをブロックしています。会話するには解除してください。',
    'blockedByBanner':  'このユーザーは現在利用できません。',
    'blockedBadge':     'ブロック中',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// IndividualChatScreen
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

  // ── Live profile state — updated by real-time registration listener ──────
  String _liveOtherName   = '';
  String _liveOtherAvatar = '';

  // ── Decoded avatar bytes cache — avoids re-decoding base64 on every build ──
  // Key: the normalised avatar string; Value: decoded bytes (null = use NetworkImage)
  Uint8List? _cachedAvatarBytes;
  String     _cachedAvatarSrc = '';

  StreamSubscription? _profileSub;

  String? _chatId;
  bool _isLoading = true;
  bool _isTyping  = false;

  late final AnimationController _sendBtnController;

  // ── Avatar normalisation — mirrors web app's toImgSrc() exactly ──────────
  // Handles: http URLs, data: URIs, raw base64 strings
  String _toImgSrc(String raw) {
    if (raw.isEmpty)             return '';
    if (raw.startsWith('data:')) return raw;
    if (raw.startsWith('http'))  return raw;
    return 'data:image/jpeg;base64,$raw';
  }

  // ── Extract raw base64 bytes from a normalised avatar string ─────────────
  // Returns null if the source is a plain http URL (use NetworkImage instead).
  Uint8List? _extractBytes(String src) {
    if (src.isEmpty) return null;
    try {
      if (src.startsWith('data:')) {
        final comma = src.indexOf(',');
        if (comma != -1) {
          final bytes = base64Decode(src.substring(comma + 1));
          if (bytes.isNotEmpty) return bytes;
        }
        return null;
      }
      // Raw base64 (shouldn't reach here after _toImgSrc, but guard anyway)
      if (!src.startsWith('http')) {
        final bytes = base64Decode(src);
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {
      // Silently fall through
    }
    return null;
  }

  // ── Update avatar cache whenever _liveOtherAvatar changes ────────────────
  void _updateAvatarCache(String newSrc) {
    if (newSrc == _cachedAvatarSrc) return; // nothing changed
    _cachedAvatarSrc = newSrc;
    if (newSrc.isEmpty) {
      _cachedAvatarBytes = null;
      return;
    }
    if (newSrc.startsWith('http')) {
      // HTTP URL — no bytes to cache; NetworkImage handles it
      _cachedAvatarBytes = null;
      return;
    }
    // base64 / data: URI — decode once and cache
    _cachedAvatarBytes = _extractBytes(newSrc);
  }

  // ── Resolve cached avatar → ImageProvider ────────────────────────────────
  // Uses the pre-decoded bytes when available; falls back to NetworkImage.
  ImageProvider? _resolveImage(String src) {
    if (src.isEmpty) return null;
    // Prefer cached bytes for base64 avatars
    if (src == _cachedAvatarSrc) {
      if (_cachedAvatarBytes != null) return MemoryImage(_cachedAvatarBytes!);
      if (src.startsWith('http'))     return NetworkImage(src);
      return null;
    }
    // Fallback (e.g. a bubble avatar that differs from the cached value)
    try {
      if (src.startsWith('http')) return NetworkImage(src);
      if (src.startsWith('data:')) {
        final comma = src.indexOf(',');
        if (comma != -1) {
          final bytes = base64Decode(src.substring(comma + 1));
          if (bytes.isNotEmpty) return MemoryImage(bytes);
        }
      }
      final bytes = base64Decode(src);
      if (bytes.isNotEmpty) return MemoryImage(bytes);
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();

    // Seed with passed-in values, normalising through _toImgSrc so that a raw
    // base64 or http URL passed by the caller is immediately usable.
    _liveOtherName   = widget.otherUserName;
    final initialSrc  = _toImgSrc(widget.otherUserAvatar);
    _liveOtherAvatar = initialSrc;
    _updateAvatarCache(initialSrc);

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

    // Do a one-shot fetch first (same pattern as web app's init()) so the
    // avatar is populated before the stream's first event arrives.
    _fetchOtherProfileOnce();
    _subscribeOtherProfile();
    _initChat();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendBtnController.dispose();
    super.dispose();
  }

  // ── Parse name + avatar from a registration document map ─────────────────
  // Mirrors the web app's onSnapshot handler logic exactly.
  ({String name, String avatar}) _parseProfile(
      Map<String, dynamic> d, String fallbackName) {
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
        : fallbackName;
    return (name: name, avatar: _toImgSrc(rawImg));
  }

  // ── One-shot fetch from registration/{otherUserId} ────────────────────────
  // Mirrors the web app's getDoc(doc(db, 'registration', otherUserId)) call
  // inside init(). Ensures avatar is shown even before the stream fires.
  Future<void> _fetchOtherProfileOnce() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('registration')
          .doc(widget.otherUserId)
          .get();
      if (!snap.exists || !mounted) return;
      final p = _parseProfile(snap.data()!, _liveOtherName);
      if (mounted) {
        setState(() {
          if (p.name.isNotEmpty)   _liveOtherName   = p.name;
          if (p.avatar.isNotEmpty) {
            _liveOtherAvatar = p.avatar;
            _updateAvatarCache(p.avatar);
          }
        });
      }
    } catch (e) {
      debugPrint('[IndividualChatScreen] one-shot profile fetch error: $e');
    }
  }

  // ── Real-time listener on registration/{otherUserId} ─────────────────────
  void _subscribeOtherProfile() {
    _profileSub = FirebaseFirestore.instance
        .collection('registration')
        .doc(widget.otherUserId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final p = _parseProfile(snap.data()!, _liveOtherName);
      setState(() {
        _liveOtherName   = p.name;
        _liveOtherAvatar = p.avatar;
        _updateAvatarCache(p.avatar);
      });
    }, onError: (e) {
      debugPrint('[IndividualChatScreen] profile sub error: $e');
    });
  }

  Future<void> _initChat() async {
    final chatId = await IndividualChatService.getOrCreateChat(
      otherUserId:     widget.otherUserId,
      otherUserName:   widget.otherUserName,
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

  // ── Navigate to full UserProfileScreen (replaces modal) ──────────────────
  void _openProfile() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId:        widget.otherUserId,
          initialName:   _liveOtherName,
          initialAvatar: _liveOtherAvatar,
        ),
      ),
    );
  }

  String _groupName(Map<String, dynamic> msg, String lang) {
    if (lang == kLangJa) {
      final jp = (msg['group_name_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (msg['group_name'] ?? '').toString();
  }

  String _eventTitle(Map<String, dynamic> msg, String lang) {
    if (lang == kLangJa) {
      final jp = (msg['event_title_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (msg['event_title'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return StreamBuilder<bool>(
      stream: BlockService.streamIsBlocked(widget.otherUserId),
      builder: (context, blockSnap) {
        final isBlocked = blockSnap.data ?? false;

        return StreamBuilder<bool>(
          stream: BlockService.streamIsBlockedBy(widget.otherUserId),
          builder: (context, blockBySnap) {
            final isBlockedBy = blockBySnap.data ?? false;

            return Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: const Color(0xFFF7F7F9),
              body: Column(
                children: [
                  SafeArea(bottom: false, child: _buildAppBar(lang, isBlocked, isBlockedBy)),
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
                  SafeArea(top: false, child: _buildInputBar(lang, isBlocked, isBlockedBy)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar(String lang, bool isBlocked, bool isBlockedBy) {
    final avatarImage = _resolveImage(_liveOtherAvatar);
    final isAnyBlocked = isBlocked || isBlockedBy;

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
            child: Row(
              children: [
                // Back button
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

                // Avatar + name (tappable) → opens UserProfileScreen
                Expanded(
                  child: GestureDetector(
                    onTap: _openProfile,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        _buildAvatar(avatarImage, radius: 21, fontSize: 15),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _liveOtherName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0D0D0D),
                                        letterSpacing: -0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isAnyBlocked) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(color: Colors.red.withOpacity(0.18)),
                                      ),
                                      child: Text(
                                        _t(lang, 'blockedBadge'),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 1),
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

                // More button
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: Colors.white,
                  offset: const Offset(0, 48),
                  onSelected: (value) async {
                    if (value == 'block') {
                      if (isBlocked) {
                        await BlockService.unblockUser(widget.otherUserId);
                      } else {
                        final confirmBlock = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(lang == kLangJa ? 'ユーザーをブロックする' : 'Block User'),
                            content: Text(lang == kLangJa
                                ? 'このユーザーをブロックしますか？'
                                : 'Are you sure you want to block this user?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(lang == kLangJa ? 'キャンセル' : 'Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(lang == kLangJa ? 'ブロック' : 'Block'),
                              ),
                            ],
                          ),
                        );
                        if (confirmBlock == true) {
                          await BlockService.blockUser(widget.otherUserId);
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(
                            isBlocked ? Icons.check_circle_outline_rounded : Icons.block_flipped,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isBlocked ? _t(lang, 'unblock') : _t(lang, 'block'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.more_vert_rounded,
                        size: 22, color: Colors.black.withOpacity(0.4)),
                  ),
                ),
              ],
            ),
          ),
          // Subtle green gradient divider
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

  // ── Reusable avatar widget ────────────────────────────────────────────────
  Widget _buildAvatar(ImageProvider? image,
      {required double radius, required double fontSize}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      backgroundImage: image,
      child: image == null
          ? Text(
        _liveOtherName.isNotEmpty
            ? _liveOtherName[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      )
          : null,
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

  // ── Date Divider ──────────────────────────────────────────────────────────
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
    final Timestamp? sentAt = msg['sent_at'];
    final time              = sentAt != null ? _formatTime(sentAt.toDate()) : '';

    if ((msg['type'] ?? '') == 'group_share') {
      return _buildGroupShareBubble(
          msg, isMe, isLastInGroup, time, lang);
    }
    if ((msg['type'] ?? '') == 'event_share') {
      return _buildEventShareBubble(
          msg, isMe, isLastInGroup, time, lang);
    }

    final text         = msg['text'] ?? '';
    final bubbleRadius = BorderRadius.only(
      topLeft:     Radius.circular(!isMe && !isFirstInGroup ? 5 : 22),
      topRight:    Radius.circular(isMe  && !isFirstInGroup ? 5 : 22),
      bottomLeft:  Radius.circular(!isMe && !isLastInGroup  ? 5 : 22),
      bottomRight: Radius.circular(isMe  && !isLastInGroup  ? 5 : 22),
    );

    final bubbleAvatarImage = _resolveImage(_liveOtherAvatar);

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
                child: _buildAvatar(bubbleAvatarImage,
                    radius: 16, fontSize: 12),
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
                      color: isMe
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
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

  // ── Group Share Bubble ────────────────────────────────────────────────────
  Widget _buildGroupShareBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isLastInGroup,
      String time,
      String lang,
      ) {
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

    final senderAvatarImage = _resolveImage(_liveOtherAvatar);

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
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  backgroundImage: senderAvatarImage,
                  child: senderAvatarImage == null
                      ? Text(
                    _liveOtherName.isNotEmpty
                        ? _liveOtherName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  )
                      : null,
                ),
                const SizedBox(width: 5),
                Text(
                  _liveOtherName,
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

  // ── Event Share Bubble ────────────────────────────────────────────────────
  Widget _buildEventShareBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isLastInGroup,
      String time,
      String lang,
      ) {
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

    final senderAvatarImage = _resolveImage(_liveOtherAvatar);

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
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  backgroundImage: senderAvatarImage,
                  child: senderAvatarImage == null
                      ? Text(
                    _liveOtherName.isNotEmpty
                        ? _liveOtherName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  )
                      : null,
                ),
                const SizedBox(width: 5),
                Text(
                  _liveOtherName,
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

  // ── Input Bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(String lang, bool isBlocked, bool isBlockedBy) {
    final isAnyBlocked = isBlocked || isBlockedBy;
    if (isAnyBlocked) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            border: Border.all(color: Colors.red.withOpacity(0.18)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🚫', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBlocked ? _t(lang, 'blockedBanner') : _t(lang, 'blockedByBanner'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                  parent: _sendBtnController, curve: Curves.easeOutBack),
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

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(String lang) {
    final avatarImage = _resolveImage(_liveOtherAvatar);

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
              child: CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? Text(
                  _liveOtherName.isNotEmpty
                      ? _liveOtherName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _liveOtherName,
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
    final hour   = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}