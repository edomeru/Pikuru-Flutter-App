import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';

class MarkInterestedModal {
  // ── Resolve group ID (mirrors JoinGroupModal logic) ───────────────────
  static String _resolveGroupId(Map<String, dynamic> group) {
    final docId = group['_doc_id']?.toString() ?? '';
    if (docId.isNotEmpty) return docId;

    final orgId = group['org_id']?.toString() ?? '';
    if (orgId.isNotEmpty) return orgId;

    // Also check group_id for cases where event data is passed in
    final altId = group['org_org_id']?.toString() ??
        group['group_id']?.toString() ??
        group['id']?.toString() ??
        '';
    if (altId.isNotEmpty) return altId;

    final orgName = group['org_name']?.toString() ??
        group['group_name']?.toString() ??
        'unknown';
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

    final groupId = _resolveGroupId(group);
    final docId = '${user.uid}_$groupId';

    debugPrint('MarkInterestedModal — groupId: $groupId | docId: $docId');

    // ── Only block if already marked as 'interested' ─────────────────
    // If 'active' (joined), still allow marking interested
    final existingDoc = await FirebaseFirestore.instance
        .collection('user_groups')
        .doc(docId)
        .get();

    if (existingDoc.exists &&
        existingDoc.data()?['status']?.toString() == 'interested') {
      if (context.mounted) {
        _showSnackBar(
            context, 'You have already marked this group as interested', false);
      }
      return;
    }

    if (!context.mounted) return;

    final shouldMark = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                child: const Icon(Icons.favorite_rounded,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('Mark as Interested?',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Save this group to your interests and stay updated on their events.',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Mark',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldMark == true && context.mounted) {
      await _markInterested(context, group, groupId, docId);
    }
  }

  static Future<void> _markInterested(
      BuildContext context,
      Map<String, dynamic> group,
      String groupId,
      String docId,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(
          context, 'Please sign in to mark groups as interested', true);
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

      // Support both org_ and group_ field name conventions
      final groupName = (group['org_name'] ??
          group['group_name'] ??
          'Unnamed Group')
          .toString();
      final groupImage =
      (group['org_image'] ?? group['group_image'] ?? '').toString();

      // merge: true so we don't wipe joined_at if they already joined
      await FirebaseFirestore.instance
          .collection('user_groups')
          .doc(docId)
          .set({
        'user_id': user.uid,
        'group_id': groupId,
        'group_name': groupName,
        'group_image': groupImage,
        'marked_at': FieldValue.serverTimestamp(),
        'status': 'interested',
      }, SetOptions(merge: true));

      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(context, 'Group added to your interests!', false);
      }
    } catch (e) {
      debugPrint('Mark interested error: $e');
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(
            context, 'Failed to mark as interested. Please try again.', true);
      }
    }
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
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
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