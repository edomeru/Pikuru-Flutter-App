import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/providers/notification_provider.dart';
import 'package:pikuru/screens/organizer_dashboard_screen.dart';

const _L = {
  kLangEn: {
    'title': 'Notifications',
    'noNotifications': 'No new notifications',
    'dismiss': 'Dismiss',
    'accept': 'Accept',
    'decline': 'Decline',
    'adminDashboard': 'Go to Web Admin',
    'organizerDashboard': 'Go to Dashboard',
    'inviteAccepted': 'You accepted the invite.',
    'inviteDeclined': 'Invite declined.',
    'notificationDismissed': 'Notification dismissed.',
    'adminRedirectInfo': 'Please access the Admin Dashboard on the Pikuru Web application.',
    'errorOccurred': 'An error occurred. Please try again.',
    'error': 'Error',
  },
  kLangJa: {
    'title': '通知',
    'noNotifications': '新しい通知はありません',
    'dismiss': '非表示にする',
    'accept': '承認する',
    'decline': '辞退する',
    'adminDashboard': 'ウェブ管理画面へ',
    'organizerDashboard': 'ダッシュボードへ',
    'inviteAccepted': '招待を承認しました。',
    'inviteDeclined': '招待を辞退しました。',
    'notificationDismissed': '通知を非表示にしました。',
    'adminRedirectInfo': '管理画面機能はウェブ版Pikuruからご利用ください。',
    'errorOccurred': 'エラーが発生しました。もう一度お試しください。',
    'error': 'エラー',
  },
};

String _t(String lang, String key) => _L[lang]?[key] ?? _L[kLangEn]![key]!;

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _busy = false;

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _acceptGroupInvite(AppNotification notif, String lang) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    setState(() => _busy = true);
    try {
      final emailName = (me.email != null && me.email!.isNotEmpty) ? me.email!.split('@')[0] : '';
      final joinerName = (me.displayName != null && me.displayName!.trim().isNotEmpty)
          ? me.displayName!.trim()
          : (emailName.isNotEmpty ? emailName : (lang == kLangJa ? '不明なユーザー' : 'Unknown User'));

      final groupId = notif.targetId;
      final groupName = notif.rawData['group_name'] ?? 'Group';
      final groupImage = notif.rawData['group_image'] ?? '';

      final batch = FirebaseFirestore.instance.batch();

      // Write user_groups doc to join the group
      final userGroupDoc = FirebaseFirestore.instance
          .collection('user_groups')
          .doc('${me.uid}_$groupId');
      batch.set(
        userGroupDoc,
        {
          'user_id': me.uid,
          'group_id': groupId,
          'group_name': groupName,
          'group_image': groupImage,
          'status': 'active',
          'joined_at': FieldValue.serverTimestamp(),
          'notifications_enabled': true,
          // Since the user is invited by someone, we store their ID to trigger joined notification back
          'organizer_id': notif.rawData['invited_by'] ?? '',
          'organizer_seen': false,
          'user_name': joinerName,
        },
        SetOptions(merge: true),
      );

      // Update group_invites doc
      final inviteDoc = FirebaseFirestore.instance
          .collection('group_invites')
          .doc(notif.id);
      batch.set(
        inviteDoc,
        {
          'status': 'accepted',
          'responded_at': FieldValue.serverTimestamp(),
          'accepted_by_name': joinerName,
          'organizer_seen': false,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      _showSnackbar(_t(lang, 'inviteAccepted'));
    } catch (e) {
      debugPrint('Error accepting invite: $e');
      _showSnackbar(_t(lang, 'errorOccurred'), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _declineGroupInvite(AppNotification notif, String lang) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    setState(() => _busy = true);
    try {
      final emailName = (me.email != null && me.email!.isNotEmpty) ? me.email!.split('@')[0] : '';
      final declinerName = (me.displayName != null && me.displayName!.trim().isNotEmpty)
          ? me.displayName!.trim()
          : (emailName.isNotEmpty ? emailName : (lang == kLangJa ? '不明なユーザー' : 'Unknown User'));

      await FirebaseFirestore.instance
          .collection('group_invites')
          .doc(notif.id)
          .set({
        'status': 'declined',
        'responded_at': FieldValue.serverTimestamp(),
        'declined_by_name': declinerName,
        'organizer_seen': false,
      }, SetOptions(merge: true));

      _showSnackbar(_t(lang, 'inviteDeclined'));
    } catch (e) {
      debugPrint('Error declining invite: $e');
      _showSnackbar(_t(lang, 'errorOccurred'), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismissNotification(AppNotification notif, String lang) async {
    try {
      if (notif.type == 'invite_response') {
        await FirebaseFirestore.instance
            .collection('group_invites')
            .doc(notif.id)
            .update({'organizer_seen': true});
      } else if (notif.type == 'registration') {
        await FirebaseFirestore.instance
            .collection('event_registrations')
            .doc(notif.id)
            .update({'user_seen': true});
      } else if (notif.type == 'org_reg_request') {
        await FirebaseFirestore.instance
            .collection('event_registrations')
            .doc(notif.id)
            .update({'organizer_seen': true});
      } else if (notif.type == 'org_group_join') {
        await FirebaseFirestore.instance
            .collection('user_groups')
            .doc(notif.id)
            .update({'organizer_seen': true});
      } else if (notif.type.startsWith('admin_')) {
        final colMap = {
          'admin_event': 'events',
          'admin_group': 'organizations',
          'admin_court': 'locations',
          'admin_inquiry': 'contact_us',
          'admin_review': 'reviews',
          'admin_user': 'registration',
        };
        final colName = colMap[notif.type];
        if (colName != null) {
          await FirebaseFirestore.instance
              .collection(colName)
              .doc(notif.id)
              .update({'admin_seen': true});
        }
      }
      _showSnackbar(_t(lang, 'notificationDismissed'));
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
      _showSnackbar(_t(lang, 'errorOccurred'), isError: true);
    }
  }

  void _navigateToOrganizerDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'group_invite':
        return Colors.green.shade600;
      case 'invite_response':
        return AppColors.primary;
      case 'registration':
        return Colors.teal.shade600;
      case 'org_reg_request':
        return Colors.orange.shade700;
      case 'org_group_join':
        return Colors.blue.shade600;
      case 'admin_event':
        return Colors.amber.shade700;
      case 'admin_group':
        return Colors.green.shade700;
      case 'admin_court':
        return Colors.lightBlue.shade700;
      case 'admin_inquiry':
        return Colors.purple.shade600;
      case 'admin_review':
        return Colors.pink.shade600;
      case 'admin_user':
        return Colors.teal.shade400;
      default:
        return AppColors.primary;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'group_invite':
        return Icons.group_add_rounded;
      case 'invite_response':
        return Icons.insert_invitation_rounded;
      case 'registration':
        return Icons.event_available_rounded;
      case 'org_reg_request':
        return Icons.assignment_ind_rounded;
      case 'org_group_join':
        return Icons.person_add_rounded;
      case 'admin_event':
        return Icons.event_note_rounded;
      case 'admin_group':
        return Icons.supervised_user_circle_rounded;
      case 'admin_court':
        return Icons.sports_tennis_rounded;
      case 'admin_inquiry':
        return Icons.question_answer_rounded;
      case 'admin_review':
        return Icons.rate_review_rounded;
      case 'admin_user':
        return Icons.person_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _formatDateTime(DateTime? dt, String lang) {
    if (dt == null) return '';
    if (lang == kLangJa) {
      return DateFormat('M月d日 HH:mm').format(dt);
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);
    final notificationsAsync = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t(lang, 'title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ),
      body: notificationsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t(lang, 'noNotifications'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemBuilder: (context, index) {
                  final notif = list[index];
                  final color = _getNotificationColor(notif.type);
                  final icon = _getNotificationIcon(notif.type);
                  final body = lang == kLangJa ? notif.subtitleJp : notif.subtitle;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon container
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.18)),
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          const SizedBox(width: 14),

                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      lang == kLangJa ? notif.titleJp : notif.title,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (notif.createdAt != null)
                                      Text(
                                        _formatDateTime(notif.createdAt, lang),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade400,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Actions row
                                if (notif.type == 'group_invite')
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: _busy ? null : () => _acceptGroupInvite(notif, lang),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          _t(lang, 'accept'),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: _busy ? null : () => _declineGroupInvite(notif, lang),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade600,
                                          side: BorderSide(color: Colors.grey.shade300),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          _t(lang, 'decline'),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      if (notif.type == 'org_reg_request' || notif.type == 'org_group_join') ...[
                                        ElevatedButton(
                                          onPressed: () {
                                            _dismissNotification(notif, lang);
                                            _navigateToOrganizerDashboard();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: color,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text(
                                            _t(lang, 'organizerDashboard'),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ] else if (notif.type.startsWith('admin_')) ...[
                                        ElevatedButton(
                                          onPressed: () {
                                            _showSnackbar(_t(lang, 'adminRedirectInfo'));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: color,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: Text(
                                            _t(lang, 'adminDashboard'),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      OutlinedButton(
                                        onPressed: () => _dismissNotification(notif, lang),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade600,
                                          side: BorderSide(color: Colors.grey.shade300),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          _t(lang, 'dismiss'),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_busy)
                Container(
                  color: Colors.black.withOpacity(0.15),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            ],
          );
        },
        error: (err, stack) =>
            Center(child: Text('${_t(lang, 'error')}: $err')),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
    );
  }
}
