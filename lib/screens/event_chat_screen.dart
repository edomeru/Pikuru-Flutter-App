import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/chat_members_screen.dart';
import 'package:pikuru/screens/event_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// i18n
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'announcements':       'Announcements',
    'generalChat':         'General Chat',
    'members':             'members',
    'noMessages':          'No messages yet',
    'firstHello':          'Be the first to say hello! 👋',
    'messagePh':           'Message…',
    'announcePh':          'Post an announcement…',
    'announceHint':        'Only you can post here — participants can read announcements',
    'announceParticipant': 'Read-only — announcements from the organizer',
    'broadcastBadge':      'ANNOUNCEMENT',
    'notifSilenced':       'Notifications silenced',
    'notifEnabled':        'Notifications enabled',
    'unknown':             'Unknown',
  },
  kLangJa: {
    'announcements':       'アナウンス',
    'generalChat':         '一般チャット',
    'members':             'メンバー',
    'noMessages':          'メッセージはまだありません',
    'firstHello':          '最初に挨拶メッセージを送りましょう！ 👋',
    'messagePh':           'メッセージ…',
    'announcePh':          'アナウンスを投稿…',
    'announceHint':        'ここに投稿できるのはあなただけです。参加者は読むことができます',
    'announceParticipant': '読み取り専用 — オーガナイザーからのアナウンス',
    'broadcastBadge':      'アナウンスメント',
    'notifSilenced':       '通知をミュートにしました',
    'notifEnabled':        '通知を有効にしました',
    'unknown':             '不明',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Avatar helpers
// ─────────────────────────────────────────────────────────────────────────────
String _toImgSrc(String raw) {
  if (raw.isEmpty) return '';
  if (raw.startsWith('data:')) return raw;
  if (raw.startsWith('http')) return raw;
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

// ─────────────────────────────────────────────────────────────────────────────
// EventChatScreen
// ─────────────────────────────────────────────────────────────────────────────
/// chatId        — the group_chats document ID (e.g. "event_<eventDocId>")
/// eventData     — the event Firestore data map (for name / image fallback)
class EventChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final Map<String, dynamic> eventData;

  const EventChatScreen({
    super.key,
    required this.chatId,
    required this.eventData,
  });

  @override
  ConsumerState<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends ConsumerState<EventChatScreen> {
  Future<void> _openEventDetail(BuildContext context) async {
    // Resolve the event document id from eventData or fall back to chatId ("event_<id>")
    String eventId = (widget.eventData['event_id'] ??
        widget.eventData['_doc_id'] ??
        widget.eventData['id'] ??
        '')
        .toString()
        .trim();
    if (eventId.isEmpty && widget.chatId.startsWith('event_')) {
      eventId = widget.chatId.substring('event_'.length);
    }
    if (eventId.isEmpty) {
      // Nothing to fetch — push with whatever we have so UI still opens.
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: widget.eventData),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic> merged = {
      ...widget.eventData,
      'event_id': eventId,
      '_doc_id': eventId,
    };
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      if (snap.exists) {
        merged = {
          ...widget.eventData,
          ...?snap.data(),
          'event_id': eventId,
          '_doc_id': eventId,
        };
      }
    } catch (e) {
      debugPrint('[EventChatScreen] failed to load event $eventId: $e');
    }

    if (!context.mounted) return;
    Navigator.pop(context); // close loading
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(event: merged),
      ),
    );
  }

  // ── Tabs: announcements | general ──────────────────────────────────────
  String _activeTab = 'announcements'; // 'announcements' | 'general'

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final _me = FirebaseAuth.instance.currentUser;

  // ── Channel state ──────────────────────────────────────────────────────
  Map<String, dynamic> _chatDoc = {};
  bool _isOrganizer = false;
  bool _isSilenced = false;
  bool _repliesAllowed = true;
  bool _loading = true;
  bool _isTyping = false;

  // ── My live profile ─────────────────────────────────────────────────────
  String _myName = '';
  String _myAvatar = '';
  StreamSubscription? _myProfileSub;

  // ── Sender profile cache ────────────────────────────────────────────────
  final Map<String, Map<String, String>> _senderCache = {};
  final Map<String, StreamSubscription> _senderSubs = {};

  // ── Firestore subscriptions ─────────────────────────────────────────────
  StreamSubscription? _chatDocSub;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() {
      final typing = _msgCtrl.text.trim().isNotEmpty;
      if (typing != _isTyping) setState(() => _isTyping = typing);
    });
    _focusNode.addListener(() => setState(() {}));
    _init();
  }

  @override
  void dispose() {
    _myProfileSub?.cancel();
    _chatDocSub?.cancel();
    for (final s in _senderSubs.values) s.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Init ──────────────────────────────────────────────────────────────
  Future<void> _init() async {
    if (_me == null) return;

    // Subscribe to my own registration profile
    _myProfileSub = FirebaseFirestore.instance
        .collection('registration')
        .doc(_me!.uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;
      final raw = (d['profile_img'] ?? '').toString();
      final nick = (d['nickname'] ?? '').toString().trim();
      final first = (d['firstName'] ?? '').toString().trim();
      final last = (d['lastName'] ?? '').toString().trim();
      final name = nick.isNotEmpty
          ? nick
          : (first.isNotEmpty && last.isNotEmpty)
          ? '$first $last'
          : first.isNotEmpty
          ? first
          : (_me!.displayName ?? '');
      if (mounted) setState(() { _myName = name; _myAvatar = _toImgSrc(raw); });
    });

    // Subscribe to the group_chats doc for repliesAllowed / created_by
    _chatDocSub = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;
      setState(() {
        _chatDoc = d;
        _isOrganizer = (d['created_by'] ?? '') == _me!.uid;
        _repliesAllowed = d['replies_allowed'] != false;
      });
    });

    // Join as participant (mirrors web joinChat)
    final participantRef = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chatId)
        .collection('participants')
        .doc(_me!.uid);

    final pDoc = await participantRef.get();
    if (!pDoc.exists) {
      await participantRef.set({
        'user_id': _me!.uid,
        'display_name': _me!.displayName ?? 'User',
        'avatar_url': _me!.photoURL ?? '',
        'joined_at': FieldValue.serverTimestamp(),
        'last_read_at': FieldValue.serverTimestamp(),
        'is_silenced': false,
      });
      if (mounted) setState(() { _isSilenced = false; _loading = false; });
    } else {
      await participantRef.set(
        {'last_read_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      if (mounted) {
        setState(() {
          _isSilenced = pDoc.data()?['is_silenced'] == true;
          _loading = false;
        });
      }
    }
  }

  // ── Sender subscription ────────────────────────────────────────────────
  void _ensureSender(String uid) {
    if (_senderSubs.containsKey(uid)) return;
    final sub = FirebaseFirestore.instance
        .collection('registration')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;
      final raw = (d['profile_img'] ?? '').toString();
      final nick = (d['nickname'] ?? '').toString().trim();
      final first = (d['firstName'] ?? '').toString().trim();
      final last = (d['lastName'] ?? '').toString().trim();
      final name = nick.isNotEmpty
          ? nick
          : (first.isNotEmpty && last.isNotEmpty)
          ? '$first $last'
          : first;
      setState(() {
        _senderCache[uid] = {'name': name, 'avatar': _toImgSrc(raw)};
      });
    });
    _senderSubs[uid] = sub;
  }

  String _senderName(String uid, String fallback) =>
      (_senderCache[uid]?['name'] ?? '').isNotEmpty
          ? _senderCache[uid]!['name']!
          : fallback;

  String _senderAvatar(String uid, String fallback) =>
      (_senderCache[uid]?['avatar'] ?? '').isNotEmpty
          ? _senderCache[uid]!['avatar']!
          : _toImgSrc(fallback);

  // ── Send message ───────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _me == null) return;
    HapticFeedback.lightImpact();
    _msgCtrl.clear();
    _focusNode.requestFocus();

    final isBroadcast = _activeTab == 'announcements';

    final msgsRef = FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chatId)
        .collection('messages');

    await msgsRef.add({
      'sender_id': _me!.uid,
      'sender_name': _myName.isNotEmpty ? _myName : (_me!.displayName ?? 'User'),
      'sender_avatar': _myAvatar,
      'text': text,
      'sent_at': FieldValue.serverTimestamp(),
      if (isBroadcast) ...{
        'type': 'broadcast',
        'is_broadcast': true,
      } else ...{
        'type': 'text',
      },
    });

    await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chatId)
        .set({
      'last_message': text,
      'last_message_at': FieldValue.serverTimestamp(),
      'last_message_by': _me!.uid,
      'messages_cleared': false,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chatId)
        .collection('participants')
        .doc(_me!.uid)
        .set({'last_read_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true));

    _scrollToBottom();
  }

  // ── Toggle silence ─────────────────────────────────────────────────────
  Future<void> _toggleSilence() async {
    if (_me == null) return;
    final lang = ref.read(appLangProvider);
    final newVal = !_isSilenced;
    HapticFeedback.lightImpact();
    setState(() => _isSilenced = newVal);
    await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.chatId)
        .collection('participants')
        .doc(_me!.uid)
        .set({'is_silenced': newVal}, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newVal ? _t(lang, 'notifSilenced') : _t(lang, 'notifEnabled')),
        backgroundColor: newVal ? const Color(0xFF3A3A3C) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    // Channel name — prefer lang-aware name from the chat doc, fall back to eventData
    String channelName;
    if (lang == kLangJa && (_chatDoc['name_jp'] ?? '').toString().isNotEmpty) {
      channelName = _chatDoc['name_jp'].toString();
    } else if ((_chatDoc['name'] ?? '').toString().isNotEmpty) {
      channelName = _chatDoc['name'].toString();
    } else {
      channelName = lang == kLangJa
          ? (widget.eventData['event_title_jp'] ??
          widget.eventData['event_title'] ??
          'Event')
          : (widget.eventData['event_title'] ?? 'Event');
    }
    channelName = channelName.toString();

    final imgUrl = (_chatDoc['image'] ??
        widget.eventData['event_pic'] ??
        widget.eventData['event_pic_thumbnail'] ??
        '')
        .toString();

    // Can this user post in the announcements tab?
    final canPostAnnouncement = _isOrganizer;
    // Can they post in general tab?
    final canPostGeneral = _repliesAllowed;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildAppBar(channelName, imgUrl, lang),
          _buildTabBar(lang),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: _loading
                  ? Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5))
                  : _buildMessageList(lang),
            ),
          ),
          SafeArea(
            top: false,
            child: _buildInputBar(
                lang, canPostAnnouncement, canPostGeneral),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────
  Widget _buildAppBar(String channelName, String imgUrl, String lang) {
    final image = _resolveImage(imgUrl);
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
              child: Row(children: [
                // Back
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Color(0xFF1C1C1E)),
                  onPressed: () => Navigator.pop(context),
                ),
                // Avatar + title — tap to open event detail
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openEventDetail(context),
                    child: Row(children: [
                      Stack(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF9933).withOpacity(0.15),
                          ),
                          child: image != null
                              ? ClipOval(
                              child: Image(image: image, fit: BoxFit.cover))
                              : const Icon(Icons.campaign_rounded,
                              color: Color(0xFFFF9933), size: 22),
                        ),
                        Positioned(
                          right: 1, bottom: 1,
                          child: Container(
                            width: 11, height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 10),
                      // Name + member count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(channelName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1C1C1E),
                                    letterSpacing: -0.3),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 1),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('group_chats')
                                  .doc(widget.chatId)
                                  .collection('participants')
                                  .snapshots(),
                              builder: (_, snap) {
                                final count = snap.data?.size ?? 0;
                                return Row(children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF34C759),
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$count ${_t(lang, 'members')}',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFFFF9933),
                                          fontWeight: FontWeight.w500)),
                                ]);
                              },
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                // Silence button
                _SilenceBtn(isSilenced: _isSilenced, onTap: _toggleSilence),
                const SizedBox(width: 6),
                // Members button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatMembersScreen(
                        chatId: widget.chatId,
                        groupName: channelName,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9933).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_alt_rounded,
                        size: 18, color: Color(0xFFFF9933)),
                  ),
                ),
              ]),
            ),
            // Divider
            Container(height: 1, color: Colors.black.withOpacity(0.07)),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar (Announcements | General Chat) ────────────────────────────
  Widget _buildTabBar(String lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(children: [
        _TabBtn(
          label: _t(lang, 'announcements'),
          icon: Icons.campaign_rounded,
          active: _activeTab == 'announcements',
          activeColor: const Color(0xFFFF9933),
          onTap: () => setState(() => _activeTab = 'announcements'),
        ),
        const SizedBox(width: 8),
        _TabBtn(
          label: _t(lang, 'generalChat'),
          icon: Icons.chat_bubble_rounded,
          active: _activeTab == 'general',
          activeColor: AppColors.primary,
          onTap: () => setState(() => _activeTab = 'general'),
        ),
      ]),
    );
  }

  // ── Message List ───────────────────────────────────────────────────────
  Widget _buildMessageList(String lang) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('group_chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('sent_at', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5));
        }

        final allMsgs = snap.data!.docs;

        // Filter by active tab — mirrors web displayedMessages
        final msgs = allMsgs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final isBroadcast =
              d['is_broadcast'] == true || d['type'] == 'broadcast';
          if (_activeTab == 'announcements') return isBroadcast;
          return !isBroadcast;
        }).toList();

        // Subscribe to each sender
        for (final doc in allMsgs) {
          final d = doc.data() as Map<String, dynamic>;
          final uid = (d['sender_id'] ?? '').toString();
          if (uid.isNotEmpty) _ensureSender(uid);
        }

        if (msgs.isEmpty) return _buildEmptyState(lang);
        _scrollToBottom();

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          itemCount: msgs.length,
          itemBuilder: (ctx, i) {
            final msg = msgs[i].data() as Map<String, dynamic>;
            final isMe = msg['sender_id'] == _me?.uid;
            final prevSenderId = i > 0
                ? (msgs[i - 1].data() as Map<String, dynamic>)['sender_id']
                : null;
            final nextSenderId = i < msgs.length - 1
                ? (msgs[i + 1].data() as Map<String, dynamic>)['sender_id']
                : null;
            final isFirst = prevSenderId != msg['sender_id'];
            final isLast = nextSenderId != msg['sender_id'];
            final showDate = i == 0 ||
                _isDifferentDay(
                  (msgs[i - 1].data() as Map<String, dynamic>)['sent_at'],
                  msg['sent_at'],
                );
            return Column(children: [
              if (showDate) _buildDateDivider(msg['sent_at'], lang),
              _buildBubble(msg, isMe, isFirst, isLast, lang),
            ]);
          },
        );
      },
    );
  }

  // ── Date Divider ───────────────────────────────────────────────────────
  Widget _buildDateDivider(dynamic ts, String lang) {
    String label = lang == kLangJa ? '今日' : 'Today';
    if (ts is Timestamp) {
      final d = ts.toDate();
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(d.year, d.month, d.day))
          .inDays;
      if (diff == 0)
        label = lang == kLangJa ? '今日' : 'Today';
      else if (diff == 1)
        label = lang == kLangJa ? '昨日' : 'Yesterday';
      else
        label = '${d.day}/${d.month}/${d.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8)
              ],
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500)),
          ),
        ),
        Expanded(child: Divider(color: Colors.black.withOpacity(0.08))),
      ]),
    );
  }

  // ── Message Bubble ─────────────────────────────────────────────────────
  Widget _buildBubble(
      Map<String, dynamic> msg,
      bool isMe,
      bool isFirst,
      bool isLast,
      String lang,
      ) {
    final senderId = (msg['sender_id'] ?? '').toString();
    final msgName = (msg['sender_name'] ?? '').toString();
    final msgAvatar = (msg['sender_avatar'] ?? '').toString();
    final liveName = _senderName(senderId, msgName);
    final liveAvatar = _senderAvatar(senderId, msgAvatar);
    final Timestamp? sentAt = msg['sent_at'];
    final time = sentAt != null ? _fmtTime(sentAt.toDate()) : '';
    final isBroadcast =
        msg['is_broadcast'] == true || msg['type'] == 'broadcast';
    final text = (msg['text'] ?? '').toString();

    final radius = BorderRadius.only(
      topLeft: Radius.circular(!isMe && !isFirst ? 6 : 20),
      topRight: Radius.circular(isMe && !isFirst ? 6 : 20),
      bottomLeft: Radius.circular(!isMe && !isLast ? 6 : 20),
      bottomRight: Radius.circular(isMe && !isLast ? 6 : 20),
    );

    final avatarImg = _resolveImage(liveAvatar);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 10 : 2),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMe) ...[
            SizedBox(
              width: 34,
              child: isLast
                  ? CircleAvatar(
                radius: 17,
                backgroundColor:
                AppColors.primary.withOpacity(0.1),
                backgroundImage: avatarImg,
                child: avatarImg == null
                    ? Text(
                    liveName.isNotEmpty
                        ? liveName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary))
                    : null,
              )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Sender name label (non-me, first in group)
                if (!isMe && isFirst)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 5),
                    child: Text(liveName,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                // Broadcast badge + text
                if (isBroadcast)
                  Container(
                    constraints: BoxConstraints(
                        maxWidth:
                        MediaQuery.of(context).size.width * 0.80),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFFFF9933).withOpacity(0.15)
                          : Colors.white,
                      borderRadius: radius,
                      border: Border.all(
                          color: const Color(0xFFFF9933).withOpacity(0.4),
                          width: 1.2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9933).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.campaign_rounded,
                                  size: 11, color: Color(0xFFFF9933)),
                              const SizedBox(width: 4),
                              Text(_t(lang, 'broadcastBadge'),
                                  style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF9933),
                                      letterSpacing: 0.6)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(text,
                            style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1C1C1E),
                                height: 1.45)),
                      ],
                    ),
                  )
                else
                // Regular text bubble
                  Container(
                    constraints: BoxConstraints(
                        maxWidth:
                        MediaQuery.of(context).size.width * 0.70),
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
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                            color: isMe
                                ? AppColors.primary.withOpacity(0.22)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: isMe ? 14 : 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Text(text,
                        style: TextStyle(
                            fontSize: 15,
                            color: isMe
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
                            height: 1.45)),
                  ),
                if (isLast)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, left: 4, right: 4),
                    child: Text(time,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFFAEAEB2),
                            fontWeight: FontWeight.w400)),
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
  Widget _buildInputBar(
      String lang, bool canPostAnnouncement, bool canPostGeneral) {
    // Announcements tab, participant (not organizer): read-only banner
    if (_activeTab == 'announcements' && !canPostAnnouncement) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.campaign_rounded,
                size: 16, color: Color(0xFFFF9933)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _t(lang, 'announceParticipant'),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9933)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // General tab, replies disabled: read-only banner
    if (_activeTab == 'general' && !canPostGeneral) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded,
                size: 16, color: Colors.black.withOpacity(0.3)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Announcements only — replies are disabled',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.35)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Organizer hint in announcements tab
    final showHint = _activeTab == 'announcements' && canPostAnnouncement;
    final hintColor = const Color(0xFFFF9933);
    final placeholder = _activeTab == 'announcements'
        ? _t(lang, 'announcePh')
        : _t(lang, 'messagePh');
    final borderColor = _activeTab == 'announcements'
        ? hintColor.withOpacity(0.35)
        : AppColors.primary.withOpacity(0.35);
    final sendColor =
    _activeTab == 'announcements' ? hintColor : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHint)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Icon(Icons.campaign_rounded, size: 13, color: hintColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(_t(lang, 'announceHint'),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: hintColor.withOpacity(0.7))),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? borderColor
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _msgCtrl,
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
                        hintText: placeholder,
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
                  onTap: _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: _isTyping
                          ? sendColor
                          : const Color(0xFFD1D1D6),
                      shape: BoxShape.circle,
                      boxShadow: _isTyping
                          ? [
                        BoxShadow(
                            color: sendColor.withOpacity(0.38),
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
          ),
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────
  Widget _buildEmptyState(String lang) {
    final isAnnounce = _activeTab == 'announcements';
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: (isAnnounce
                ? const Color(0xFFFF9933)
                : AppColors.primary)
                .withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAnnounce
                ? Icons.campaign_rounded
                : Icons.chat_bubble_outline_rounded,
            size: 32,
            color: isAnnounce
                ? const Color(0xFFFF9933)
                : AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(_t(lang, 'noMessages'),
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E))),
        const SizedBox(height: 6),
        Text(_t(lang, 'firstHello'),
            style: const TextStyle(
                fontSize: 13, color: Color(0xFFAEAEB2))),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  bool _isDifferentDay(dynamic a, dynamic b) {
    if (a is! Timestamp || b is! Timestamp) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year || da.month != db.month || da.day != db.day;
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TabBtn
// ─────────────────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? activeColor.withOpacity(0.4)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: active
                      ? activeColor
                      : Colors.black.withOpacity(0.35)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? activeColor
                          : Colors.black.withOpacity(0.35))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SilenceBtn
// ─────────────────────────────────────────────────────────────────────────────
class _SilenceBtn extends StatefulWidget {
  final bool isSilenced;
  final VoidCallback onTap;

  const _SilenceBtn({required this.isSilenced, required this.onTap});

  @override
  State<_SilenceBtn> createState() => _SilenceBtnState();
}

class _SilenceBtnState extends State<_SilenceBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: widget.isSilenced
                ? const Color(0xFFFF9933).withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSilenced
                  ? const Color(0xFFFF9933).withOpacity(0.3)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              widget.isSilenced
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_rounded,
              key: ValueKey(widget.isSilenced),
              size: 18,
              color: widget.isSilenced
                  ? const Color(0xFFFF9933)
                  : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }
}