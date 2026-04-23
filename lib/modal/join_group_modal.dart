import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/group_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localization strings — mirrors web app T object
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'alreadyJoined': 'You have already joined this group',
    'joinTitle':     'Join the Group?',
    'joinBody':      'You will be able to see group events and communicate with members.',
    'cancel':        'Cancel',
    'join':          'Join',
    'pleaseSignIn':  'Please sign in to join groups',
    'failedJoin':    'Failed to join group. Please try again.',
    'successTitle':  'Joined the Group\nSuccessfully!',
    'successBody':   'Want to communicate with the members\nof the group?',
    'no':            'No',
    'yes':           'Yes',
  },
  kLangJa: {
    'alreadyJoined': 'このグループにはすでに参加しています',
    'joinTitle':     'グループに参加しますか？',
    'joinBody':      'グループのイベントの確認やメンバーとの交流ができるようになります。',
    'cancel':        'キャンセル',
    'join':          '参加する',
    'pleaseSignIn':  'グループに参加するにはサインインしてください',
    'failedJoin':    'グループへの参加に失敗しました。もう一度お試しください。',
    'successTitle':  'グループへの参加が\n完了しました！',
    'successBody':   'メンバーとコミュニケーションを\n取りますか？',
    'no':            'いいえ',
    'yes':           'はい',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Modal
// ─────────────────────────────────────────────────────────────────────────────
class JoinGroupModal {
  // ── Resolve group ID ──────────────────────────────────────────────────────
  static String _resolveGroupId(Map<String, dynamic> group) {
    final docId = group['_doc_id']?.toString() ?? '';
    if (docId.isNotEmpty) return docId;

    final orgId = group['org_id']?.toString() ?? '';
    if (orgId.isNotEmpty) return orgId;

    final altId = group['org_org_id']?.toString() ??
        group['id']?.toString() ??
        '';
    if (altId.isNotEmpty) return altId;

    final orgName = group['org_name']?.toString() ?? 'unknown';
    return orgName
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  /// [lang] — reads from appLangProvider at the call-site automatically.
  /// Pass `ref.read(appLangProvider)` or let it default to the saved language.
  static Future<void> show(
      BuildContext context,
      Map<String, dynamic> group, {
        String lang = kLangEn,
      }) async {
    // ── Always read the latest persisted language ─────────────────────────
    final resolvedLang = (await loadSavedLang());
    final effectiveLang = lang != kLangEn ? lang : resolvedLang;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final groupId = _resolveGroupId(group);
    final docId   = '${user.uid}_$groupId';

    final existingDoc = await FirebaseFirestore.instance
        .collection('user_groups')
        .doc(docId)
        .get();

    if (existingDoc.exists &&
        existingDoc.data()?['status'] == 'active') {
      if (context.mounted) {
        _showSnackBar(context, _t(effectiveLang, 'alreadyJoined'), false);
      }
      return;
    }

    final shouldJoin = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.group_add_rounded,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                _t(effectiveLang, 'joinTitle'),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _t(effectiveLang, 'joinBody'),
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _t(effectiveLang, 'cancel'),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      _t(effectiveLang, 'join'),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (shouldJoin == true && context.mounted) {
      await _joinGroup(context, group, groupId, docId,
          lang: effectiveLang);
    }
  }

  static Future<void> _joinGroup(
      BuildContext context,
      Map<String, dynamic> group,
      String groupId,
      String docId, {
        String lang = kLangEn,
      }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(context, _t(lang, 'pleaseSignIn'), true);
      return;
    }

    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      await FirebaseFirestore.instance
          .collection('user_groups')
          .doc(docId)
          .set({
        'user_id':               user.uid,
        'group_id':              groupId,
        'group_name':            group['org_name'] ?? 'Unnamed Group',
        'group_image':           group['org_image'] ?? '',
        'joined_at':             FieldValue.serverTimestamp(),
        'status':                'active',
        'notifications_enabled': true,
      });

      if (context.mounted) {
        Navigator.pop(context);
        _showSuccessModal(context, group, lang: lang);
      }
    } catch (e) {
      debugPrint('❌ Join group error: $e');
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(context, _t(lang, 'failedJoin'), true);
      }
    }
  }

  static Future<void> _showSuccessModal(
      BuildContext context,
      Map<String, dynamic> group, {
        String lang = kLangEn,
      }) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                _t(lang, 'successTitle'),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _t(lang, 'successBody'),
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(
                      _t(lang, 'no'),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600),
                    ),
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                GroupChatScreen(group: group)),
                      );
                    },
                    style: TextButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(
                      _t(lang, 'yes'),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Public helpers ────────────────────────────────────────────────────────
  static Future<bool> isAlreadyJoined(
      String userId, Map<String, dynamic> group) async {
    final groupId = _resolveGroupId(group);
    final docId   = '${userId}_$groupId';
    final doc     = await FirebaseFirestore.instance
        .collection('user_groups')
        .doc(docId)
        .get();
    return doc.exists && doc.data()?['status'] == 'active';
  }

  static void _showSnackBar(
      BuildContext context, String message, bool isError) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_rounded
                : Icons.check_circle_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor:
        isError ? Colors.red.shade400 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}