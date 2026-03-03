import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/group_chat_screen.dart';

class JoinGroupModal {
  // ── Resolve group ID consistently ─────────────────────────────────────
  // Priority: Firestore doc ID (_doc_id) > org_id field > name-based slug
  // This must match exactly how user_groups docs are keyed.
  static String _resolveGroupId(Map<String, dynamic> group) {
    // 1. _doc_id is the actual Firestore document ID — most reliable
    final docId = group['_doc_id']?.toString() ?? '';
    if (docId.isNotEmpty) return docId;

    // 2. org_id field stored inside the document
    final orgId = group['org_id']?.toString() ?? '';
    if (orgId.isNotEmpty) return orgId;

    // 3. Other possible field names
    final altId = group['org_org_id']?.toString() ??
        group['id']?.toString() ??
        '';
    if (altId.isNotEmpty) return altId;

    // 4. Last resort: slugify org_name (least reliable)
    final orgName = group['org_name']?.toString() ?? 'unknown';
    return orgName
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  static Future<void> show(
      BuildContext context,
      Map<String, dynamic> group,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ── Check if already joined BEFORE showing dialog ─────────────────
    final groupId = _resolveGroupId(group);
    final docId = '${user.uid}_$groupId';

    final existingDoc = await FirebaseFirestore.instance
        .collection('user_groups')
        .doc(docId)
        .get();

    if (existingDoc.exists && existingDoc.data()?['status'] == 'active') {
      if (context.mounted) {
        _showSnackBar(context, 'You have already joined this group', false);
      }
      return;
    }

    // ── Show join confirmation dialog ──────────────────────────────────
    final shouldJoin = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Join the Group?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You will be able to see group events and communicate with members.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side:
                        BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Join',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldJoin == true && context.mounted) {
      await _joinGroup(context, group, groupId, docId);
    }
  }

  static Future<void> _joinGroup(
      BuildContext context,
      Map<String, dynamic> group,
      String groupId, // ← already resolved, no re-computation
      String docId,   // ← already computed
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(context, 'Please sign in to join groups', true);
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

      debugPrint('🔑 Joining group — groupId: $groupId | docId: $docId');

      await FirebaseFirestore.instance
          .collection('user_groups')
          .doc(docId)
          .set({
        'user_id': user.uid,
        'group_id': groupId,
        'group_name': group['org_name'] ?? 'Unnamed Group',
        'group_image': group['org_image'] ?? '',
        'joined_at': FieldValue.serverTimestamp(),
        'status': 'active',
        'notifications_enabled': true,
      });

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showSuccessModal(context, group);
      }
    } catch (e) {
      debugPrint('❌ Join group error: $e');
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(context, 'Failed to join group. Please try again.', true);
      }
    }
  }

  static Future<void> _showSuccessModal(
      BuildContext context,
      Map<String, dynamic> group,
      ) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Joined the Group\nSuccessfully!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Want to communicate with the members\nof the group?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'No',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupChatScreen(group: group),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Yes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Public helper so GroupDetailScreen can check join status ──────────
  static Future<bool> isAlreadyJoined(
      String userId, Map<String, dynamic> group) async {
    final groupId = _resolveGroupId(group);
    final docId = '${userId}_$groupId';
    final doc = await FirebaseFirestore.instance
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
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}