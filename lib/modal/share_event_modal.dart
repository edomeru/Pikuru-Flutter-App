import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/theme/material.dart';
import 'package:intl/intl.dart';

// ════════════════════════════════════════════════════════════════════════════
// ShareEventModal
// Usage: ShareEventModal.show(context, event: widget.event)
// ════════════════════════════════════════════════════════════════════════════

// ── Static i18n strings ───────────────────────────────────────────────────────
const _kEn = {
  'title'          : 'Share Event',
  'shareVia'       : 'Share via',
  'people'         : 'People',
  'groups'         : 'Groups',
  'copyLink'       : 'Copy Link',
  'instagram'      : 'Instagram',
  'line'           : 'LINE',
  'facebook'       : 'Facebook',
  'messenger'      : 'Messenger',
  'twitter'        : 'X / Twitter',
  'whatsapp'       : 'WhatsApp',
  'linkCopied'     : 'Link copied!',
  'selectRecip'    : 'Select recipients',
  'sendTo'         : 'Send to',
  'sent'           : 'Sent!',
  'failedSend'     : 'Failed to send: ',
  'signIn'         : 'Sign in to see contacts',
  'noConvo'        : 'No recent conversations',
  'noGroups'       : 'No group chats yet',
  'sharedEvent'    : 'Shared an event: ',
};

const _kJa = {
  'title'          : 'イベントをシェア',
  'shareVia'       : 'シェア方法',
  'people'         : 'ユーザー',
  'groups'         : 'グループ',
  'copyLink'       : 'リンクをコピー',
  'instagram'      : 'Instagram',
  'line'           : 'LINE',
  'facebook'       : 'Facebook',
  'messenger'      : 'Messenger',
  'twitter'        : 'X / Twitter',
  'whatsapp'       : 'WhatsApp',
  'linkCopied'     : 'リンクをコピーしました！',
  'selectRecip'    : '送信先を選択',
  'sendTo'         : '送信する（',
  'sent'           : '送信済み！',
  'failedSend'     : '送信に失敗しました: ',
  'signIn'         : 'ログインして連絡先を表示',
  'noConvo'        : '最近の会話はありません',
  'noGroups'       : 'グループチャットはまだありません',
  'sharedEvent'    : 'イベントをシェアしました: ',
};

class ShareEventModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;

  const ShareEventModal({super.key, required this.event});

  static Future<void> show(BuildContext context,
      {required Map<String, dynamic> event}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareEventModal(event: event),
    );
  }

  @override
  ConsumerState<ShareEventModal> createState() => _ShareEventModalState();
}

class _ShareEventModalState extends ConsumerState<ShareEventModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _selectedIds = {};
  bool _sent    = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Lang helpers ──────────────────────────────────────────────────────────
  bool get _isJa => ref.watch(appLangProvider) == kLangJa;
  Map<String, String> get _t => _isJa ? _kJa : _kEn;

  /// Returns the Japanese field value if available and lang is JA,
  /// otherwise falls back to the English field.
  String _f(String enKey, [String? jpKey]) {
    final jp = jpKey ?? '${enKey}_jp';
    final jpVal = (widget.event[jp] ?? '').toString();
    if (_isJa && jpVal.isNotEmpty) return jpVal;
    return (widget.event[enKey] ?? '').toString();
  }

  // ── Derived event fields ──────────────────────────────────────────────────
  String get _eventId {
    final docId = (widget.event['_doc_id'] ?? '').toString().trim();
    if (docId.isNotEmpty) return docId;
    final id = (widget.event['id'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    final underscoreId = (widget.event['_id'] ?? '').toString().trim();
    if (underscoreId.isNotEmpty) return underscoreId;
    return (widget.event['event_id'] ?? '').toString().trim();
  }

  String get _eventUrl {
    final id = _eventId;
    if (id.isEmpty) return 'https://pikuru.com/events';
    return 'https://pikuru.com/events/${Uri.encodeComponent(id)}';
  }

  String get _eventTitle => _f('event_title');

  String get _eventImage =>
      (widget.event['event_pic'] ?? widget.event['event_image'] ?? '').toString();

  String get _eventType  => _f('event_type');

  String get _eventDateLabel {
    final rawDate = widget.event['event_date'];
    if (rawDate is Timestamp) {
      return _isJa
          ? DateFormat('yyyy年M月d日').format(rawDate.toDate())
          : DateFormat('MMM d, yyyy').format(rawDate.toDate());
    } else if (rawDate != null) {
      return rawDate.toString();
    }
    return '';
  }

  String get _shareText =>
      '${_t['sharedEvent']}$_eventTitle 🏓';

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    if (_selectedIds.isEmpty || _sending) return;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    setState(() => _sending = true);

    final db = FirebaseFirestore.instance;

    final sharePayload = {
      'sender_id'    : me.uid,
      'sender_name'  : me.displayName ?? 'Anonymous',
      'sender_avatar': me.photoURL    ?? '',
      'type'         : 'event_share',
      'text'         : _shareText,
      'event_id'     : _eventId,
      'event_title'  : _eventTitle,
      'event_image'  : _eventImage,
      'event_date'   : _eventDateLabel,
      'event_type'   : _eventType,
      'event_data'   : widget.event,
      'sent_at'      : FieldValue.serverTimestamp(),
    };

    try {
      await Future.wait(_selectedIds.map((chatId) async {
        final isIndividual =
            chatId.contains('_') && chatId.split('_').length == 2;

        if (isIndividual) {
          final chatRef = db.collection('individual_chats').doc(chatId);
          await chatRef.collection('messages').add(sharePayload);
          await chatRef.update({
            'last_message'        : _shareText,
            'last_message_at'     : FieldValue.serverTimestamp(),
            'last_message_by'     : me.uid,
            'last_read.${me.uid}' : FieldValue.serverTimestamp(),
          });
        } else {
          final chatRef = db.collection('group_chats').doc(chatId);
          await chatRef.collection('messages').add(sharePayload);
          await chatRef.update({
            'last_message'   : _shareText,
            'last_message_at': FieldValue.serverTimestamp(),
            'last_message_by': me.uid,
          });
          await chatRef
              .collection('participants')
              .doc(me.uid)
              .set({'last_read_at': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
        }
      }));

      if (mounted) {
        setState(() { _sent = true; _sending = false; });
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t['failedSend']}$e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _launchSocial(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch lang so the whole modal rebuilds on any global lang change.
    final isJa = ref.watch(appLangProvider) == kLangJa;
    final t = isJa ? _kJa : _kEn;

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 60, 12, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // ── Title + close ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(t['title']!,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D0D0D),
                        letterSpacing: -0.4)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: Colors.black.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Event preview card ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _EventThumb(event: widget.event),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _eventTitle,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D0D0D)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_eventType.isNotEmpty)
                          Text(
                            _eventType,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500),
                          ),
                        if (_eventDateLabel.isNotEmpty)
                          Text(
                            _eventDateLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.black.withOpacity(0.45),
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.sports_tennis_rounded,
                      color: AppColors.primary.withOpacity(0.35), size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Tab bar (People / Groups) ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFF0D0D0D),
                unselectedLabelColor: Colors.black45,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                tabs: [Tab(text: t['people']), Tab(text: t['groups'])],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Tab content ───────────────────────────────────────────────
          SizedBox(
            height: 140,
            child: TabBarView(
              controller: _tabController,
              children: [
                _PeopleTab(
                  selectedIds: _selectedIds,
                  isJa: isJa,
                  onToggle: (id) => setState(() => _selectedIds.contains(id)
                      ? _selectedIds.remove(id)
                      : _selectedIds.add(id)),
                ),
                _GroupsTab(
                  selectedIds: _selectedIds,
                  isJa: isJa,
                  onToggle: (id) => setState(() => _selectedIds.contains(id)
                      ? _selectedIds.remove(id)
                      : _selectedIds.add(id)),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          const SizedBox(height: 14),

          // ── Social share row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['shareVia']!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.4),
                        letterSpacing: 0.3)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SocialButton(
                        label: t['copyLink']!,
                        icon: Icons.link_rounded,
                        color: const Color(0xFF1C1C1E),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _eventUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t['linkCopied']!),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: t['twitter']!,
                        color: const Color(0xFF000000),
                        iconWidget: const _XIcon(),
                        onTap: () => _launchSocial(
                            'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_shareText)}&url=${Uri.encodeComponent(_eventUrl)}'),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: t['facebook']!,
                        color: const Color(0xFF1877F2),
                        icon: Icons.facebook_rounded,
                        onTap: () => _launchSocial(
                            'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_eventUrl)}'),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: t['line']!,
                        color: const Color(0xFF06C755),
                        iconWidget: _LineIcon(),
                        onTap: () => _launchSocial(
                            'https://line.me/R/msg/text/?${Uri.encodeComponent("$_shareText\n$_eventUrl")}'),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: t['whatsapp']!,
                        color: const Color(0xFF25D366),
                        icon: Icons.chat_bubble_rounded,
                        onTap: () => _launchSocial(
                            'https://api.whatsapp.com/send?text=${Uri.encodeComponent("$_shareText\n$_eventUrl")}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Send button ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 20),
            child: GestureDetector(
              onTap: (_selectedIds.isEmpty || _sending) ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: _sent
                      ? Colors.green.shade500
                      : _selectedIds.isEmpty
                      ? Colors.black.withOpacity(0.07)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (_selectedIds.isNotEmpty && !_sent)
                      ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                      : [],
                ),
                child: Center(
                  child: _sending
                      ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : _sent
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 7),
                      Text(t['sent']!,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  )
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded,
                          size: 16,
                          color: _selectedIds.isEmpty
                              ? Colors.black38
                              : Colors.white),
                      const SizedBox(width: 7),
                      Text(
                        _selectedIds.isEmpty
                            ? t['selectRecip']!
                            : isJa
                            ? '${t['sendTo']}${_selectedIds.length}人）'
                            : '${t['sendTo']} ${_selectedIds.length}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _selectedIds.isEmpty
                              ? Colors.black38
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// People tab
// ─────────────────────────────────────────────────────────────────────────────
class _PeopleTab extends StatelessWidget {
  final Set<String> selectedIds;
  final bool isJa;
  final void Function(String) onToggle;

  const _PeopleTab({
    required this.selectedIds,
    required this.isJa,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final t = isJa ? _kJa : _kEn;
    if (me == null) return _empty(t['signIn']!);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('individual_chats')
          .where('participants', arrayContains: me.uid)
          .orderBy('last_message_at', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('individual_chats')
                .where('participants', arrayContains: me.uid)
                .limit(20)
                .snapshots(),
            builder: (_, snap2) {
              if (!snap2.hasData || snap2.data!.docs.isEmpty) {
                return _empty(t['noConvo']!);
              }
              return _buildList(snap2.data!.docs, me.uid);
            },
          );
        }

        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (snapshot.data!.docs.isEmpty) return _empty(t['noConvo']!);

        return _buildList(snapshot.data!.docs, me.uid);
      },
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs, String myUid) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final data      = docs[i].data() as Map<String, dynamic>;
        final chatId    = docs[i].id;
        final parts     = List<String>.from(data['participants'] ?? []);
        final otherId   = parts.firstWhere((p) => p != myUid, orElse: () => '');
        final names     = Map<String, dynamic>.from(data['participant_names']   ?? {});
        final avatars   = Map<String, dynamic>.from(data['participant_avatars'] ?? {});
        final name      =
            (names[otherId] ?? (isJa ? 'ユーザー' : 'User')).toString();
        final avatar    = (avatars[otherId] ?? '').toString();
        final selected  = selectedIds.contains(chatId);

        return _AvatarTile(
          id: chatId,
          name: name,
          avatarUrl: avatar,
          selected: selected,
          onTap: () => onToggle(chatId),
          isGroup: false,
        );
      },
    );
  }

  Widget _empty(String msg) => Center(
    child: Text(msg,
        style: TextStyle(
            fontSize: 13, color: Colors.black.withOpacity(0.35))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Groups tab
// ─────────────────────────────────────────────────────────────────────────────
class _GroupsTab extends StatefulWidget {
  final Set<String> selectedIds;
  final bool isJa;
  final void Function(String) onToggle;

  const _GroupsTab({
    required this.selectedIds,
    required this.isJa,
    required this.onToggle,
  });

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  List<_GroupChatItem>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) { setState(() => _loading = false); return; }

    try {
      final allChats = await FirebaseFirestore.instance
          .collection('group_chats')
          .orderBy('last_message_at', descending: true)
          .limit(30)
          .get();

      final List<_GroupChatItem> result = [];

      for (final doc in allChats.docs) {
        final partRef = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(doc.id)
            .collection('participants')
            .doc(me.uid)
            .get();
        if (!partRef.exists) continue;

        final data     = doc.data();
        final orgId    = (data['org_id']    ?? '').toString();
        String name    = (data['org_name']  ?? 'Group Chat').toString();
        String avatar  = (data['org_image'] ?? '').toString();

        // Prefer Japanese org name if lang is JA and field exists
        if (widget.isJa) {
          final jpName = (data['org_name_jp'] ?? '').toString();
          if (jpName.isNotEmpty) name = jpName;
        }

        if (orgId.isNotEmpty && (name == 'Group Chat' || avatar.isEmpty)) {
          try {
            final orgSnap = await FirebaseFirestore.instance
                .collection('organizations')
                .where('org_id', isEqualTo: orgId)
                .limit(1)
                .get();
            if (orgSnap.docs.isNotEmpty) {
              final org = orgSnap.docs.first.data();
              if (widget.isJa) {
                final jpOrgName = (org['org_name_jp'] ?? '').toString();
                name = jpOrgName.isNotEmpty
                    ? jpOrgName
                    : (org['org_name'] ?? name).toString();
              } else {
                name = (org['org_name'] ?? name).toString();
              }
              avatar = (org['org_image'] ?? avatar).toString();
            }
          } catch (_) {}
        }

        // Translate the generic fallback name if it was never resolved
        if (widget.isJa && name == 'Group Chat') name = 'グループチャット';

        result.add(_GroupChatItem(chatId: doc.id, name: name, avatarUrl: avatar));
      }

      if (mounted) setState(() { _items = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _items = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.isJa ? _kJa : _kEn;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final items = _items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Text(t['noGroups']!,
            style: TextStyle(
                fontSize: 13, color: Colors.black.withOpacity(0.35))),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item     = items[i];
        final selected = widget.selectedIds.contains(item.chatId);
        return _AvatarTile(
          id: item.chatId,
          name: item.name,
          avatarUrl: item.avatarUrl,
          selected: selected,
          onTap: () => widget.onToggle(item.chatId),
          isGroup: true,
        );
      },
    );
  }
}

class _GroupChatItem {
  final String chatId;
  final String name;
  final String avatarUrl;
  const _GroupChatItem(
      {required this.chatId, required this.name, required this.avatarUrl});
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared avatar tile
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarTile extends StatelessWidget {
  final String id;
  final String name;
  final String avatarUrl;
  final bool selected;
  final VoidCallback onTap;
  final bool isGroup;

  const _AvatarTile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.selected,
    required this.onTap,
    required this.isGroup,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? Image.network(avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                ),
                if (selected)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : const Color(0xFF0D0D0D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(initial,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary.withOpacity(0.7))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event image thumbnail
// ─────────────────────────────────────────────────────────────────────────────
class _EventThumb extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventThumb({required this.event});

  @override
  Widget build(BuildContext context) {
    final url =
    (event['event_pic'] ?? event['event_image'] ?? '').toString();
    if (url.isNotEmpty) {
      return Image.network(url,
          width: 44, height: 44, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _ph());
    }
    return _ph();
  }

  Widget _ph() => Container(
      width: 44, height: 44,
      color: AppColors.primary.withOpacity(0.1),
      child: Icon(Icons.event_rounded,
          size: 22, color: AppColors.primary.withOpacity(0.5)));
}

// ─────────────────────────────────────────────────────────────────────────────
// Social share button
// ─────────────────────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final Widget? iconWidget;
  final Gradient? gradient;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: gradient == null ? color : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: iconWidget ??
                  Icon(icon ?? Icons.share_rounded,
                      color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D0D0D))),
        ],
      ),
    );
  }
}

class _LineIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Text('LINE',
      style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5));
}

class _MessengerIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Icon(
    Icons.messenger_outline_rounded,
    color: Colors.white,
    size: 24,
  );
}

class _XIcon extends StatelessWidget {
  const _XIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _XIconPainter(),
      ),
    );
  }
}

class _XIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw the main diagonal path (filled polygon)
    final path = Path()
      ..moveTo(size.width * 0.166, size.height * 0.166)
      ..lineTo(size.width * 0.655, size.height * 0.833)
      ..lineTo(size.width * 0.833, size.height * 0.833)
      ..lineTo(size.width * 0.344, size.height * 0.166)
      ..close();
    canvas.drawPath(path, paint);

    // Draw the thin crossing diagonal line
    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(size.width * 0.166, size.height * 0.833),
      Offset(size.width * 0.448, size.height * 0.551),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.551, size.height * 0.448),
      Offset(size.width * 0.833, size.height * 0.166),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}