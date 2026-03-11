import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/theme/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShareGroupModal
//
// individual_chats/{chatId}
//   participants: [uid1, uid2]
//   participant_names: { uid: name }
//   participant_avatars: { uid: url }
//   last_message: String
//   last_message_at: Timestamp
//   last_message_by: String (uid)
//   last_read: { uid: Timestamp }
//   messages/ (subcollection)
//     {msgId}/
//       text: String
//       sender_id: String
//       timestamp: Timestamp
//       type: "text"
// ─────────────────────────────────────────────────────────────────────────────

class ShareGroupModal extends StatefulWidget {
  final Map<String, dynamic> group;

  const ShareGroupModal({super.key, required this.group});

  static Future<void> show(BuildContext context,
      {required Map<String, dynamic> group}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareGroupModal(group: group),
    );
  }

  @override
  State<ShareGroupModal> createState() => _ShareGroupModalState();
}

class _ShareGroupModalState extends State<ShareGroupModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _selectedIds = {};
  bool _sent = false;
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

  String get _groupName =>
      (widget.group['org_name'] ?? widget.group['group_name'] ?? 'a group')
          .toString();

  String get _groupImage =>
      (widget.group['org_image'] ?? widget.group['org_pic'] ?? '').toString();

  String get _groupType =>
      (widget.group['org_type'] ?? '').toString();

  String get _groupId =>
      (widget.group['org_id'] ?? widget.group['org_ID'] ??
          widget.group['_doc_id'] ?? '').toString();

  // Plain text fallback for last_message preview in chat list
  String get _shareText => 'Shared a group: $_groupName 🏓';

  // ── Real Firestore send ────────────────────────────────────────────
  // _selectedIds contains individual_chat doc IDs (from _PeopleTab) or
  // group_chat doc IDs (from _GroupsTab). We handle each type correctly.
  Future<void> _send() async {
    if (_selectedIds.isEmpty || _sending) return;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    setState(() => _sending = true);

    final db = FirebaseFirestore.instance;

    // ── Structured group share message payload ─────────────────────────
    // type: 'group_share' tells the chat screen to render a card, not plain text.
    // group_data: full group map so GroupDetailScreen can be opened directly.
    final sharePayload = {
      'sender_id': me.uid,
      'sender_name': me.displayName ?? 'Anonymous',
      'sender_avatar': me.photoURL ?? '',
      'type': 'group_share',
      'text': _shareText,           // plain text fallback
      'group_id': _groupId,
      'group_name': _groupName,
      'group_image': _groupImage,
      'group_type': _groupType,
      'group_data': widget.group,   // full map → GroupDetailScreen(group: ...)
      'sent_at': FieldValue.serverTimestamp(),
    };

    try {
      await Future.wait(_selectedIds.map((chatId) async {
        // ── Determine if this is individual or group chat ──────────────
        // Individual chat IDs are "uid1_uid2" (two UIDs joined by underscore)
        // Group chat IDs are Firestore auto-IDs (20 char alphanumeric)
        final isIndividual = chatId.contains('_') && chatId.split('_').length == 2;

        if (isIndividual) {
          // ── Individual chat ────────────────────────────────────────────
          final chatRef = db.collection('individual_chats').doc(chatId);

          await chatRef.collection('messages').add(sharePayload);

          await chatRef.update({
            'last_message': _shareText,
            'last_message_at': FieldValue.serverTimestamp(),
            'last_message_by': me.uid,
            'last_read.${me.uid}': FieldValue.serverTimestamp(),
          });
        } else {
          // ── Group chat ─────────────────────────────────────────────────
          final chatRef = db.collection('group_chats').doc(chatId);

          await chatRef.collection('messages').add(sharePayload);

          await chatRef.update({
            'last_message': _shareText,
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
            content: Text('Failed to send: $e'),
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
                const Text('Share Group',
                    style: TextStyle(
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

          // ── Group preview card ────────────────────────────────────────
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
                    child: _OrgThumb(group: widget.group),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_groupName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D0D0D)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if ((widget.group['org_type'] ?? '').toString().isNotEmpty)
                          Text(widget.group['org_type'].toString(),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500)),
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
                tabs: const [Tab(text: 'People'), Tab(text: 'Groups')],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Tab content (fixed height) ────────────────────────────────
          SizedBox(
            height: 140,
            child: TabBarView(
              controller: _tabController,
              children: [
                _PeopleTab(
                  selectedIds: _selectedIds,
                  onToggle: (id) =>
                      setState(() => _selectedIds.contains(id)
                          ? _selectedIds.remove(id)
                          : _selectedIds.add(id)),
                ),
                _GroupsTab(
                  selectedIds: _selectedIds,
                  onToggle: (id) =>
                      setState(() => _selectedIds.contains(id)
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
                Text('Share via',
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
                        label: 'Copy Link',
                        icon: Icons.link_rounded,
                        color: const Color(0xFF1C1C1E),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _shareText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Link copied!'),
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
                        label: 'Instagram',
                        color: const Color(0xFFE1306C),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        icon: Icons.camera_alt_rounded,
                        onTap: () => _launchSocial('instagram://app'),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: 'LINE',
                        color: const Color(0xFF06C755),
                        iconWidget: _LineIcon(),
                        onTap: () => _launchSocial(
                            'https://line.me/R/share?text=${Uri.encodeComponent(_shareText)}'),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: 'Facebook',
                        color: const Color(0xFF1877F2),
                        icon: Icons.facebook_rounded,
                        onTap: () => _launchSocial(
                            'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_shareText)}'),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: 'Messenger',
                        color: const Color(0xFF0084FF),
                        iconWidget: _MessengerIcon(),
                        onTap: () => _launchSocial(
                            'fb-messenger://share?link=${Uri.encodeComponent(_shareText)}'),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: 'X / Twitter',
                        color: const Color(0xFF000000),
                        icon: Icons.alternate_email_rounded,
                        onTap: () => _launchSocial(
                            'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_shareText)}'),
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        icon: Icons.chat_rounded,
                        onTap: () => _launchSocial(
                            'https://wa.me/?text=${Uri.encodeComponent(_shareText)}'),
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
                  child: _sent
                      ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 7),
                      Text('Sent!',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  )
                      : _sending
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
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
                            ? 'Select recipients'
                            : 'Send to ${_selectedIds.length}',
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
// People tab — reads individual_chats, resolves other user from maps
// ─────────────────────────────────────────────────────────────────────────────
class _PeopleTab extends StatelessWidget {
  final Set<String> selectedIds;
  final void Function(String) onToggle;

  const _PeopleTab({required this.selectedIds, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return _empty('Sign in to see contacts');

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
                return _empty('No recent conversations');
              }
              return _buildList(snap2.data!.docs, me.uid);
            },
          );
        }

        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (snapshot.data!.docs.isEmpty) {
          return _empty('No recent conversations');
        }

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
        final data = docs[i].data() as Map<String, dynamic>;
        final chatId = docs[i].id;

        final participants = List<String>.from(data['participants'] ?? []);
        final otherId =
        participants.firstWhere((p) => p != myUid, orElse: () => '');

        final names = Map<String, dynamic>.from(data['participant_names'] ?? {});
        final avatars =
        Map<String, dynamic>.from(data['participant_avatars'] ?? {});

        final name = (names[otherId] ?? 'User').toString();
        final avatar = (avatars[otherId] ?? '').toString();
        final selected = selectedIds.contains(chatId);

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
        style:
        TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.35))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Groups tab — checks participants subcollection, resolves org name/image
// ─────────────────────────────────────────────────────────────────────────────
class _GroupsTab extends StatefulWidget {
  final Set<String> selectedIds;
  final void Function(String) onToggle;

  const _GroupsTab({required this.selectedIds, required this.onToggle});

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
    if (me == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final allChats = await FirebaseFirestore.instance
          .collection('group_chats')
          .orderBy('last_message_at', descending: true)
          .limit(30)
          .get();

      final List<_GroupChatItem> result = [];

      for (final doc in allChats.docs) {
        final participantRef = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(doc.id)
            .collection('participants')
            .doc(me.uid)
            .get();

        if (!participantRef.exists) continue;

        final data = doc.data();
        final orgId = (data['org_id'] ?? '').toString();

        String name = (data['org_name'] ?? 'Group Chat').toString();
        String avatarUrl = (data['org_image'] ?? '').toString();

        if (orgId.isNotEmpty && (name == 'Group Chat' || avatarUrl.isEmpty)) {
          try {
            final orgSnap = await FirebaseFirestore.instance
                .collection('organizations')
                .where('org_id', isEqualTo: orgId)
                .limit(1)
                .get();
            if (orgSnap.docs.isNotEmpty) {
              final org = orgSnap.docs.first.data();
              name = (org['org_name'] ?? name).toString();
              avatarUrl = (org['org_image'] ?? avatarUrl).toString();
            }
          } catch (_) {}
        }

        result.add(_GroupChatItem(
          chatId: doc.id,
          name: name,
          avatarUrl: avatarUrl,
        ));
      }

      if (mounted) setState(() { _items = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _items = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final items = _items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Text('No group chats yet',
            style: TextStyle(
                fontSize: 13, color: Colors.black.withOpacity(0.35))),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
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
                  width: 58,
                  height: 58,
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
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
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
// Org image thumbnail
// ─────────────────────────────────────────────────────────────────────────────
class _OrgThumb extends StatelessWidget {
  final Map<String, dynamic> group;
  const _OrgThumb({required this.group});

  @override
  Widget build(BuildContext context) {
    final url = (group['org_image'] ?? group['org_pic'] ?? '').toString();
    if (url.isNotEmpty) {
      return Image.network(url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _ph());
    }
    return _ph();
  }

  Widget _ph() => Container(
      width: 44,
      height: 44,
      color: AppColors.primary.withOpacity(0.1),
      child: Icon(Icons.group_rounded,
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
  final String? svgAsset;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.gradient,
    this.svgAsset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
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

// ── LINE icon ─────────────────────────────────────────────────────────────────
class _LineIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Text('LINE',
      style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5));
}

// ── Messenger icon ────────────────────────────────────────────────────────────
class _MessengerIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Icon(
    Icons.messenger_outline_rounded,
    color: Colors.white,
    size: 24,
  );
}