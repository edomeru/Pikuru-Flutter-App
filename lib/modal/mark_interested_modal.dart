import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';

class MarkInterestedModal {
  static Future<void> show(
      BuildContext context,
      Map<String, dynamic> event,
      ) async {
    final shouldMark = await showDialog<bool>(
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
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),

              const SizedBox(height: 20),

              // Title
              const Text(
                'Mark as Interested?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Message
              Text(
                'Save this event to your favorites and get reminders before it starts.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
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
                        'Mark',
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

    if (shouldMark == true && context.mounted) {
      await _markInterested(context, event);
    }
  }

  static Future<void> _markInterested(
      BuildContext context,
      Map<String, dynamic> event,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar(context, 'Please sign in to mark events as interested', true);
      return;
    }

    try {
      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      // Get event ID - try multiple possible field names
      final eventId = event['event_id']?.toString() ??
          event['id']?.toString() ??
          FirebaseFirestore.instance.collection('events').doc().id;

      // Create composite key
      final docId = '${user.uid}_$eventId';

      // Check if already marked
      final existingDoc = await FirebaseFirestore.instance
          .collection('user_interests')
          .doc(docId)
          .get();

      if (existingDoc.exists) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          _showSnackBar(context, 'You have already marked this event as interested', false);
        }
        return;
      }

      // Get location name for caching
      String locationName = 'Unknown location';
      try {
        final locId = event['event_loc_id']?.toString() ?? '';
        if (locId.isNotEmpty) {
          final locSnap = await FirebaseFirestore.instance
              .collection('locations')
              .where('loc_org_id', isEqualTo: locId)
              .limit(1)
              .get();
          if (locSnap.docs.isNotEmpty) {
            locationName = locSnap.docs.first.data()['loc_name'] ?? locationName;
          }
        }
      } catch (e) {
        debugPrint('Location fetch error: $e');
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('user_interests')
          .doc(docId)
          .set({
        'user_id': user.uid,
        'event_id': eventId,
        'event_title': event['event_title'] ?? 'Untitled Event',
        'event_image': event['event_image'] ?? '',
        'event_date': event['event_start_date'],
        'event_location': locationName,
        'group_id': event['group_id'] ?? '',
        'group_image': event['group_image'] ?? '',
        'group_name': event['group_name'] ?? '',
        'marked_at': FieldValue.serverTimestamp(),
        'reminder_enabled': true,
        'reminder_sent': false,
      });

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showSuccessSnackBar(context);
      }
    } catch (e) {
      debugPrint('Mark interested error: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showSnackBar(context, 'Failed to mark as interested: ${e.toString()}', true);
      }
    }
  }

  static void _showSuccessSnackBar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Event added to your favorites!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showSnackBar(BuildContext context, String message, bool isError) {
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